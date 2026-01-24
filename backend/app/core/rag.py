import json
import math
import os
from typing import Any, Iterable, Optional

from .db import get_connection
from ..llm.client import LLMUnavailable, embed_text


def rag_enabled() -> bool:
    return os.getenv("GOGOHANNAH_RAG_ENABLED", "false").lower() in {
        "1",
        "true",
        "yes",
    }


def init_rag_tables() -> None:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                child_id INTEGER NULL,
                doc_type TEXT NOT NULL,
                text TEXT NOT NULL,
                metadata_json TEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS embeddings (
                doc_id INTEGER NOT NULL,
                vector_json TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (doc_id) REFERENCES documents (id)
            )
        """
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_documents_child ON documents(child_id)"
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(doc_type)"
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_embeddings_doc ON embeddings(doc_id)"
        )


def _truncate_text(text: str, max_chars: int = 1200) -> str:
    cleaned = text.strip()
    if len(cleaned) <= max_chars:
        return cleaned
    return cleaned[:max_chars].rstrip()


def store_document(
    text: str,
    doc_type: str,
    child_id: Optional[int] = None,
    metadata: Optional[dict[str, Any]] = None,
) -> None:
    if not rag_enabled():
        return
    if not text or not doc_type:
        return
    trimmed = _truncate_text(text)
    if not trimmed:
        return
    try:
        vector = embed_text(trimmed)
    except LLMUnavailable:
        return
    metadata_json = json.dumps(metadata) if metadata else None
    vector_json = json.dumps(vector)
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO documents (child_id, doc_type, text, metadata_json)
            VALUES (?, ?, ?, ?)
        """,
            (child_id, doc_type, trimmed, metadata_json),
        )
        doc_id = cursor.lastrowid
        cursor.execute(
            "INSERT INTO embeddings (doc_id, vector_json) VALUES (?, ?)",
            (doc_id, vector_json),
        )
        conn.commit()


def retrieve_context(
    query: str,
    child_id: Optional[int] = None,
    top_k: int = 3,
    max_docs: int = 200,
) -> list[str]:
    if not rag_enabled():
        return []
    cleaned = (query or "").strip()
    if not cleaned:
        return []
    try:
        query_vector = embed_text(cleaned)
    except LLMUnavailable:
        return []
    rows = _fetch_documents(child_id=child_id, limit=max_docs)
    scored = []
    for text, vector in rows:
        score = _cosine_similarity(query_vector, vector)
        if score > 0:
            scored.append((score, text))
    scored.sort(key=lambda item: item[0], reverse=True)
    return [text for _, text in scored[:top_k]]


def _fetch_documents(
    child_id: Optional[int] = None,
    limit: int = 200,
) -> Iterable[tuple[str, list[float]]]:
    with get_connection() as conn:
        cursor = conn.cursor()
        if child_id is None:
            cursor.execute(
                """
                SELECT documents.text, embeddings.vector_json
                FROM documents
                JOIN embeddings ON documents.id = embeddings.doc_id
                WHERE documents.child_id IS NULL
                ORDER BY documents.created_at DESC
                LIMIT ?
            """,
                (limit,),
            )
        else:
            cursor.execute(
                """
                SELECT documents.text, embeddings.vector_json
                FROM documents
                JOIN embeddings ON documents.id = embeddings.doc_id
                WHERE documents.child_id IS NULL OR documents.child_id = ?
                ORDER BY documents.created_at DESC
                LIMIT ?
            """,
                (child_id, limit),
            )
        for text, vector_json in cursor.fetchall():
            try:
                vector = json.loads(vector_json)
            except json.JSONDecodeError:
                continue
            if isinstance(vector, list):
                yield text, [float(v) for v in vector]


def _cosine_similarity(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


init_rag_tables()
