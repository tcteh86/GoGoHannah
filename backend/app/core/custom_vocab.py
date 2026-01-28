from typing import Iterable, Optional

from .db import get_connection


def init_custom_vocab() -> None:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS custom_vocab (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                child_id INTEGER NOT NULL,
                word TEXT NOT NULL,
                list_name TEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(child_id, word)
            )
        """
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_custom_vocab_child ON custom_vocab(child_id)"
        )


def save_custom_vocab(
    child_id: int,
    words: Iterable[str],
    list_name: Optional[str] = None,
) -> list[str]:
    cleaned = [word for word in words if word]
    if not cleaned:
        return []
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.executemany(
            """
            INSERT OR IGNORE INTO custom_vocab (child_id, word, list_name)
            VALUES (?, ?, ?)
        """,
            [(child_id, word, list_name) for word in cleaned],
        )
        conn.commit()
    return cleaned


def replace_custom_vocab(
    child_id: int,
    words: Iterable[str],
    list_name: Optional[str] = None,
) -> list[str]:
    cleaned = [word for word in words if word]
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM custom_vocab WHERE child_id = ?", (child_id,))
        if cleaned:
            cursor.executemany(
                """
                INSERT OR IGNORE INTO custom_vocab (child_id, word, list_name)
                VALUES (?, ?, ?)
            """,
                [(child_id, word, list_name) for word in cleaned],
            )
        conn.commit()
    return cleaned


def get_custom_vocab(child_id: int) -> list[str]:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT word FROM custom_vocab WHERE child_id = ? ORDER BY word",
            (child_id,),
        )
        return [row[0] for row in cursor.fetchall()]


init_custom_vocab()
