import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .core.exercise import simple_comprehension_exercise, simple_exercise
from .core.progress import (
    get_child_progress,
    get_or_create_child,
    get_recommended_words,
    save_exercise,
)
from .core.safety import sanitize_word
from .core.scoring import calculate_pronunciation_score
from .llm.client import (
    LLMUnavailable,
    generate_comprehension_exercise,
    generate_story_image,
    generate_vocab_exercise,
)
from .schemas import (
    ComprehensionExerciseRequest,
    ComprehensionExerciseResponse,
    PronunciationScoreRequest,
    PronunciationScoreResponse,
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


@app.post("/v1/vocab/exercise", response_model=VocabExerciseResponse)
def vocab_exercise(payload: VocabExerciseRequest) -> dict:
    try:
        word = sanitize_word(payload.word)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    try:
        result = generate_vocab_exercise(word)
        source = "llm"
    except LLMUnavailable:
        result = simple_exercise(word)
        source = "fallback"

    return {
        "definition": result["definition"],
        "example_sentence": result["example_sentence"],
        "quiz_question": result["quiz_question"],
        "quiz_choices": result["quiz_choices"],
        "quiz_answer": result["quiz_answer"],
        "source": source,
    }


@app.post("/v1/comprehension/exercise", response_model=ComprehensionExerciseResponse)
def comprehension_exercise(payload: ComprehensionExerciseRequest) -> dict:
    try:
        result = generate_comprehension_exercise(
            theme=payload.theme,
            level=payload.level,
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

    return {
        "story_title": result["story_title"],
        "story_text": result["story_text"],
        "image_description": result["image_description"],
        "image_url": image_url,
        "questions": result["questions"],
        "source": source,
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
