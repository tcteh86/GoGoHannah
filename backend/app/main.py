import base64
import os
import urllib.request
from datetime import date

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
from .core.study_time import (
    add_study_time,
    get_study_time,
    get_study_time_range,
    get_total_study_time,
    month_range,
    week_range,
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
    StudyTimeAddRequest,
    StudyTimeResponse,
    StudyTimeSummaryResponse,
    StudyTimeTotalResponse,
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


def _generate_vocab_result(
    word: str,
    payload: VocabExerciseRequest,
    context: list[str] | None,
) -> tuple[dict, str]:
    try:
        result = generate_vocab_exercise(
            word,
            context=context,
            learning_direction=payload.learning_direction,
            output_style=payload.output_style,
        )
        return result, "llm"
    except LLMUnavailable:
        result = simple_exercise(
            word,
            learning_direction=payload.learning_direction,
            output_style=payload.output_style,
        )
        return result, "fallback"


def _strip_language_labels(text: str) -> str:
    if not text:
        return text
    cleaned = []
    for line in str(text).splitlines():
        trimmed = line.strip()
        for prefix in ("English:", "Chinese:", "English：", "Chinese："):
            if trimmed.lower().startswith(prefix.lower()):
                trimmed = trimmed[len(prefix) :].strip()
                break
        cleaned.append(trimmed)
    return "\n".join(cleaned)


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
    result, source = _generate_vocab_result(word, payload, context)

    cleaned_choices = {
        key: _strip_language_labels(value)
        for key, value in result["quiz_choices"].items()
    }
    response = {
        "definition": _strip_language_labels(result["definition"]),
        "example_sentence": _strip_language_labels(result["example_sentence"]),
        "quiz_question": _strip_language_labels(result["quiz_question"]),
        "quiz_choices": cleaned_choices,
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
            learning_direction=payload.learning_direction,
            output_style=payload.output_style,
        )
        source = "llm"
    except LLMUnavailable:
        result = simple_comprehension_exercise(
            level=payload.level,
            learning_direction=payload.learning_direction,
            output_style=payload.output_style,
        )
        source = "fallback"

    image_url = None
    if payload.include_image:
        try:
            image_url = generate_story_image(result["image_description"])
            inline_image = _inline_image_data(image_url)
            if inline_image:
                image_url = inline_image
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


def _inline_image_data(url: str) -> str | None:
    try:
        with urllib.request.urlopen(url) as response:
            content_type = response.headers.get("Content-Type", "image/png")
            data = response.read()
        encoded = base64.b64encode(data).decode("utf-8")
        return f"data:{content_type};base64,{encoded}"
    except Exception:
        return None

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


@app.post("/v1/progress/time", response_model=StudyTimeResponse)
def progress_time_add(payload: StudyTimeAddRequest) -> dict:
    try:
        study_date = date.fromisoformat(payload.date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format.")
    child_id = get_or_create_child(payload.child_name.strip())
    total = add_study_time(child_id, study_date, payload.seconds)
    return {"date": payload.date, "total_seconds": total}


@app.get("/v1/progress/time", response_model=StudyTimeResponse)
def progress_time_get(child_name: str, date_str: str) -> dict:
    try:
        study_date = date.fromisoformat(date_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format.")
    child_id = get_or_create_child(child_name.strip())
    total = get_study_time(child_id, study_date)
    return {"date": date_str, "total_seconds": total}


@app.get("/v1/progress/time/total", response_model=StudyTimeTotalResponse)
def progress_time_total(child_name: str) -> dict:
    child_id = get_or_create_child(child_name.strip())
    total = get_total_study_time(child_id)
    return {"total_seconds": total}


@app.get("/v1/progress/time/summary", response_model=StudyTimeSummaryResponse)
def progress_time_summary(child_name: str, date_str: str | None = None) -> dict:
    if date_str:
        try:
            study_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format.")
    else:
        study_date = date.today()
        date_str = study_date.isoformat()
    child_id = get_or_create_child(child_name.strip())
    week_start, week_end = week_range(study_date)
    month_start, month_end = month_range(study_date)
    week_total = get_study_time_range(child_id, week_start, week_end)
    month_total = get_study_time_range(child_id, month_start, month_end)
    return {
        "date": date_str,
        "week": {
            "start_date": week_start.isoformat(),
            "end_date": week_end.isoformat(),
            "total_seconds": week_total,
        },
        "month": {
            "start_date": month_start.isoformat(),
            "end_date": month_end.isoformat(),
            "total_seconds": month_total,
        },
    }


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
