import os

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .core.exercise import simple_comprehension_exercise, simple_exercise
from .core.phonics import phonics_hint
from .core.custom_vocab import (
    get_custom_vocab,
    replace_custom_vocab,
    save_custom_vocab,
)
from .core.progress import (
    get_child_progress,
    get_or_create_child,
    get_recent_exercises,
    get_recommended_words,
    save_exercise,
)
from .core.rag import debug_enabled, rag_enabled, retrieve_context, store_document
from .core.safety import sanitize_word
from .core.scoring import calculate_pronunciation_score
from .llm.client import (
    LLMUnavailable,
    generate_comprehension_exercise,
    generate_story_image,
    generate_vocab_exercise,
    suggest_vocab_corrections,
    transcribe_audio,
)
from .schemas import (
    ComprehensionExerciseRequest,
    ComprehensionExerciseResponse,
    CustomVocabAddRequest,
    CustomVocabResponse,
    CustomVocabSuggestRequest,
    CustomVocabSuggestResponse,
    PronunciationAudioResponse,
    PronunciationScoreRequest,
    PronunciationScoreResponse,
    RecentExercisesResponse,
    SaveExerciseRequest,
    VocabExerciseRequest,
    VocabExerciseResponse,
)
from .vocab.loader import load_default_vocab

app = FastAPI(title="GoGoHannah API", version="0.1.0")


def _cors_origins() -> list[str]:
    raw = os.getenv("GOGOHANNAH_CORS_ORIGINS", "*")
    if raw.strip() == "*":
        return ["*"]
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/v1/vocab/default")
def vocab_default() -> dict:
    return {"words": load_default_vocab()}


@app.get("/v1/vocab/custom", response_model=CustomVocabResponse)
def vocab_custom(child_name: str) -> dict:
    child_id = get_or_create_child(child_name.strip())
    words = get_custom_vocab(child_id)
    return {"words": words, "count": len(words)}


@app.post("/v1/vocab/custom/add", response_model=CustomVocabResponse)
def vocab_custom_add(payload: CustomVocabAddRequest) -> dict:
    child_id = get_or_create_child(payload.child_name.strip())
    sanitized = []
    for word in payload.words:
        try:
            sanitized.append(sanitize_word(word))
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
    mode = (payload.mode or "append").lower()
    if mode == "replace":
        saved = replace_custom_vocab(child_id, sanitized, payload.list_name)
    else:
        saved = save_custom_vocab(child_id, sanitized, payload.list_name)
    return {"words": saved, "count": len(saved)}


@app.post("/v1/vocab/custom/suggest", response_model=CustomVocabSuggestResponse)
def vocab_custom_suggest(payload: CustomVocabSuggestRequest) -> dict:
    words = [word.strip() for word in payload.words if word.strip()]
    if not words:
        return {"original": [], "suggested": [], "changed": False}
    try:
        suggested = suggest_vocab_corrections(words)
    except LLMUnavailable:
        suggested = words
    if len(suggested) != len(words):
        suggested = words
    changed = any(orig != new for orig, new in zip(words, suggested))
    return {
        "original": words,
        "suggested": suggested,
        "changed": changed,
    }


@app.post("/v1/vocab/exercise", response_model=VocabExerciseResponse)
def vocab_exercise(payload: VocabExerciseRequest) -> dict:
    try:
        word = sanitize_word(payload.word)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    context = retrieve_context(f"vocabulary word {word}")
    try:
        result = generate_vocab_exercise(word, context=context)
        source = "llm"
    except LLMUnavailable:
        result = simple_exercise(word)
        source = "fallback"

    response = {
        "definition": result["definition"],
        "example_sentence": result["example_sentence"],
        "quiz_question": result["quiz_question"],
        "quiz_choices": result["quiz_choices"],
        "quiz_answer": result["quiz_answer"],
        "phonics": phonics_hint(word),
        "source": source,
    }

    store_document(
        text=(
            f"Word: {word}\n"
            f"Definition: {response['definition']}\n"
            f"Example: {response['example_sentence']}\n"
            f"Phonics: {response['phonics']}"
        ),
        doc_type="vocab_exercise",
        metadata={"word": word, "source": source},
    )

    return response


@app.post("/v1/comprehension/exercise", response_model=ComprehensionExerciseResponse)
def comprehension_exercise(payload: ComprehensionExerciseRequest) -> dict:
    context_query = payload.theme or f"children story level {payload.level}"
    context = retrieve_context(context_query)
    try:
        result = generate_comprehension_exercise(
            theme=payload.theme,
            level=payload.level,
            context=context,
        )
        source = "llm"
    except LLMUnavailable:
        result = simple_comprehension_exercise(level=payload.level)
        source = "fallback"

    image_url = None
    if payload.include_image:
        try:
            image_url = generate_story_image(result["image_description"])
        except LLMUnavailable:
            image_url = None

    response = {
        "story_title": result["story_title"],
        "story_text": result["story_text"],
        "image_description": result["image_description"],
        "image_url": image_url,
        "questions": result["questions"],
        "source": source,
    }

    store_document(
        text=(
            f"Title: {response['story_title']}\n"
            f"Story: {response['story_text']}\n"
            "Questions:\n"
            + "\n".join(q["question"] for q in response["questions"])
        ),
        doc_type="comprehension_story",
        metadata={"level": payload.level, "theme": payload.theme, "source": source},
    )

    return response

@app.get("/v1/debug/rag")
def rag_debug(query: str, child_name: str | None = None, limit: int = 5) -> dict:
    if not debug_enabled():
        raise HTTPException(status_code=404, detail="Debug endpoint disabled.")
    child_id = None
    if child_name:
        child_id = get_or_create_child(child_name.strip())
    results = retrieve_context(query, child_id=child_id, top_k=limit)
    return {
        "enabled": rag_enabled(),
        "query": query,
        "child_name": child_name,
        "results": results,
        "message": None if rag_enabled() else "RAG disabled.",
    }

@app.post("/v1/progress/exercise")
def progress_save(payload: SaveExerciseRequest) -> dict:
    try:
        child_name = payload.child_name.strip()
        word = sanitize_word(payload.word)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    child_id = get_or_create_child(child_name)
    save_exercise(
        child_id,
        word,
        payload.exercise_type,
        payload.score,
        payload.correct,
    )
    return {"status": "saved"}


@app.get("/v1/progress/summary")
def progress_summary(child_name: str) -> dict:
    child_id = get_or_create_child(child_name.strip())
    return get_child_progress(child_id)


@app.get("/v1/progress/recent", response_model=RecentExercisesResponse)
def progress_recent(child_name: str, limit: int = 20) -> dict:
    child_id = get_or_create_child(child_name.strip())
    return {"exercises": get_recent_exercises(child_id, limit)}


@app.get("/v1/progress/recommended")
def progress_recommended(child_name: str, limit: int = 10) -> dict:
    child_id = get_or_create_child(child_name.strip())
    words = load_default_vocab()
    return {"words": get_recommended_words(child_id, words, limit)}


@app.post("/v1/pronunciation/score", response_model=PronunciationScoreResponse)
def pronunciation_score(payload: PronunciationScoreRequest) -> dict:
    try:
        target_word = sanitize_word(payload.target_word)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    score = calculate_pronunciation_score(payload.user_text, target_word)
    return {"score": score}


@app.post("/v1/pronunciation/assess", response_model=PronunciationAudioResponse)
async def pronunciation_assess(
    target_word: str = Form(...),
    audio: UploadFile = File(...),
) -> dict:
    try:
        word = sanitize_word(target_word)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio file is empty.")

    try:
        transcription = transcribe_audio(audio_bytes, filename=audio.filename)
    except LLMUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc))

    score = calculate_pronunciation_score(transcription, word)

    return {"transcription": transcription, "score": score}
