import base64
import os
import urllib.request
from datetime import date

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .core.exercise import (
    simple_comprehension_exercise,
    simple_exercise,
    vocab_image_hint_status,
)
from .core.phonics import phonics_hint
from .core.custom_vocab import (
    get_custom_vocab,
    replace_custom_vocab,
    save_custom_vocab,
)
from .core.progress import (
    get_daily_progress,
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
    generate_example_sentence,
    generate_vocab_image,
    generate_vocab_exercise,
    suggest_vocab_corrections,
    translate_to_chinese,
    translate_to_english,
    transcribe_audio,
)
from .schemas import (
    ComprehensionExerciseRequest,
    ComprehensionExerciseResponse,
    CustomVocabAddRequest,
    CustomVocabResponse,
    CustomVocabSuggestRequest,
    CustomVocabSuggestResponse,
    DailyProgressResponse,
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
    VocabImageHintRequest,
    VocabImageHintResponse,
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


def _split_bilingual_lines(text: str) -> tuple[str | None, str | None]:
    lines = [line.strip() for line in str(text).splitlines() if line.strip()]
    if not lines:
        return None, None
    english = None
    chinese = None
    for line in lines:
        if any("\u4e00" <= ch <= "\u9fff" for ch in line):
            chinese = chinese or line
        else:
            english = english or line
    return english, chinese


def _ensure_bilingual_text(
    text: str,
    fallback_text: str,
    learning_direction: str | None,
) -> str:
    english, chinese = _split_bilingual_lines(_strip_language_labels(text))
    fallback_english, fallback_chinese = _split_bilingual_lines(
        _strip_language_labels(fallback_text)
    )
    english = english or fallback_english
    chinese = chinese or fallback_chinese
    if not english and not chinese:
        return _strip_language_labels(text)
    if not english:
        english = chinese
    if not chinese:
        chinese = english

    if learning_direction == "zh_to_en":
        return f"{chinese}\n{english}"
    return f"{english}\n{chinese}"


def _looks_template_definition(text: str) -> bool:
    normalized = str(text or "").strip().lower()
    if not normalized:
        return True
    template_patterns = (
        "is a word to learn",
        "word to learn",
        "要学习的词",
        "学习的词",
    )
    return any(pattern in normalized for pattern in template_patterns)


def _repair_definition_text(
    definition_text: str,
    quiz_choices: dict,
    quiz_answer: str,
    source: str,
    learning_direction: str | None,
) -> str:
    cleaned = _strip_language_labels(definition_text)
    english, chinese = _split_bilingual_lines(cleaned)
    english = english.strip() if english else ""
    chinese = chinese.strip() if chinese else ""

    if source != "llm":
        return cleaned

    # Prefer the correct quiz choice as backup meaning when definition looks generic.
    if _looks_template_definition(english):
        choice = str(quiz_choices.get(quiz_answer, ""))
        choice_en, _ = _split_bilingual_lines(_strip_language_labels(choice))
        if choice_en and not _looks_template_definition(choice_en):
            english = choice_en.strip()

    needs_chinese_repair = (not chinese) or _looks_template_definition(chinese)
    needs_english_repair = (not english) or _looks_template_definition(english)
    if not needs_chinese_repair and not needs_english_repair:
        return cleaned

    if not english:
        return cleaned

    try:
        translated = translate_to_chinese(english)
    except LLMUnavailable:
        translated = chinese or english

    if learning_direction == "zh_to_en":
        return f"{translated}\n{english}"
    return f"{english}\n{translated}"


def _looks_template_example(text: str) -> bool:
    normalized = str(text or "").strip().lower()
    if not normalized:
        return True
    template_patterns = (
        "i can use the word",
        "use the word",
        "我今天可以使用",
    )
    return any(pattern in normalized for pattern in template_patterns)


def _looks_template_quiz_choice(text: str, word: str) -> bool:
    normalized = str(text or "").strip().lower()
    if not normalized:
        return True
    template_patterns = (
        "the meaning of",
        "的意思",
        "word to learn",
    )
    if word.strip().lower() in normalized and "meaning" in normalized:
        return True
    return any(pattern in normalized for pattern in template_patterns)


def _format_bilingual_output(
    english: str,
    chinese: str,
    learning_direction: str | None,
) -> str:
    if learning_direction == "zh_to_en":
        return f"{chinese}\n{english}"
    return f"{english}\n{chinese}"


def _repair_example_text(
    example_text: str,
    definition_text: str,
    word: str,
    source: str,
    learning_direction: str | None,
) -> str:
    cleaned = _strip_language_labels(example_text)
    english, chinese = _split_bilingual_lines(cleaned)
    english = english.strip() if english else ""
    chinese = chinese.strip() if chinese else ""
    if source != "llm":
        return cleaned

    needs_english_repair = (not english) or _looks_template_example(english)
    needs_chinese_repair = (not chinese) or _looks_template_example(chinese)
    if not needs_english_repair and not needs_chinese_repair:
        return cleaned

    if needs_english_repair:
        definition_en, _ = _split_bilingual_lines(definition_text)
        seed_definition = (
            definition_en.strip()
            if definition_en and definition_en.strip()
            else f'"{word}" has a specific meaning.'
        )
        try:
            english = generate_example_sentence(word=word, definition=seed_definition)
        except LLMUnavailable:
            english = f'The teacher explained "{word}" in class today.'

    if needs_chinese_repair and english:
        try:
            chinese = translate_to_chinese(english)
        except LLMUnavailable:
            chinese = chinese or english

    if not english and not chinese:
        return cleaned
    if not english:
        english = chinese
    if not chinese:
        chinese = english
    return _format_bilingual_output(english, chinese, learning_direction)


def _repair_quiz_text(
    word: str,
    quiz_question: str,
    quiz_choices: dict,
    quiz_answer: str,
    definition_text: str,
    source: str,
    learning_direction: str | None,
) -> tuple[str, dict]:
    cleaned_question = _strip_language_labels(quiz_question)
    cleaned_choices = {
        key: _strip_language_labels(value) for key, value in quiz_choices.items()
    }
    if source != "llm":
        return cleaned_question, cleaned_choices

    definition_en, definition_zh = _split_bilingual_lines(definition_text)
    definition_en = definition_en.strip() if definition_en else ""
    definition_zh = definition_zh.strip() if definition_zh else ""

    question_en, question_zh = _split_bilingual_lines(cleaned_question)
    question_en = question_en.strip() if question_en else ""
    question_zh = question_zh.strip() if question_zh else ""
    if not question_en:
        question_en = f'Which meaning best matches "{word}"?'
    if not question_zh:
        try:
            question_zh = translate_to_chinese(question_en)
        except LLMUnavailable:
            question_zh = question_en
    repaired_question = _format_bilingual_output(
        question_en, question_zh, learning_direction
    )

    repaired_choices = {}
    for key, raw_value in cleaned_choices.items():
        choice_en, choice_zh = _split_bilingual_lines(raw_value)
        choice_en = choice_en.strip() if choice_en else str(raw_value).strip()
        choice_zh = choice_zh.strip() if choice_zh else ""

        if key == quiz_answer and (
            _looks_template_quiz_choice(choice_en, word) or not choice_en
        ):
            if definition_en:
                choice_en = definition_en

        if (not choice_zh) or _looks_template_quiz_choice(choice_zh, word):
            if key == quiz_answer and definition_zh:
                choice_zh = definition_zh
            else:
                try:
                    choice_zh = translate_to_chinese(choice_en)
                except LLMUnavailable:
                    choice_zh = choice_zh or choice_en

        repaired_choices[key] = _format_bilingual_output(
            choice_en, choice_zh, learning_direction
        )
    return repaired_question, repaired_choices


def _split_story_text_to_blocks(text: str) -> list[dict]:
    lines = [line.strip() for line in str(text or "").splitlines() if line.strip()]
    blocks = []
    pending_english = None
    for line in lines:
        is_chinese = any("\u4e00" <= ch <= "\u9fff" for ch in line)
        if is_chinese:
            english = pending_english or line
            blocks.append({"english": english, "chinese": line})
            pending_english = None
        else:
            if pending_english is None:
                pending_english = line
            else:
                blocks.append({"english": pending_english, "chinese": pending_english})
                pending_english = line
    if pending_english:
        blocks.append({"english": pending_english, "chinese": pending_english})
    return blocks


def _normalize_bilingual_line(
    text: str,
    learning_direction: str | None,
    fallback_text: str = "",
) -> str:
    cleaned = _strip_language_labels(text)
    english, chinese = _split_bilingual_lines(cleaned)
    english = (english or "").strip()
    chinese = (chinese or "").strip()

    if not english and not chinese and fallback_text:
        fallback_cleaned = _strip_language_labels(fallback_text)
        fallback_en, fallback_zh = _split_bilingual_lines(fallback_cleaned)
        english = (fallback_en or "").strip()
        chinese = (fallback_zh or "").strip()

    if not english and chinese:
        try:
            english = translate_to_english(chinese)
        except LLMUnavailable:
            english = chinese
    if english and not chinese:
        try:
            chinese = translate_to_chinese(english)
        except LLMUnavailable:
            chinese = english

    if not english and not chinese:
        return cleaned

    if not english:
        english = chinese
    if not chinese:
        chinese = english
    return _format_bilingual_output(english, chinese, learning_direction)


def _normalize_story_blocks(
    raw_blocks: list | None,
    story_text: str,
    fallback_blocks: list,
    learning_direction: str | None,
) -> tuple[list[dict], str]:
    source_blocks = []
    if isinstance(raw_blocks, list):
        source_blocks = raw_blocks
    if not source_blocks:
        source_blocks = _split_story_text_to_blocks(story_text)
    if not source_blocks:
        source_blocks = fallback_blocks

    normalized = []
    for index, raw in enumerate(source_blocks):
        fallback_item = (
            fallback_blocks[index]
            if index < len(fallback_blocks)
            else {"english": "", "chinese": ""}
        )
        if isinstance(raw, dict):
            english = str(raw.get("english", "")).strip()
            chinese = str(raw.get("chinese", "")).strip()
        else:
            english, chinese = _split_bilingual_lines(str(raw))
            english = english or ""
            chinese = chinese or ""
        raw_text = f"{english}\n{chinese}".strip()
        fallback_text = (
            f"{fallback_item.get('english', '')}\n{fallback_item.get('chinese', '')}".strip()
            if not raw_text
            else ""
        )
        merged = _normalize_bilingual_line(
            raw_text,
            learning_direction=learning_direction,
            fallback_text=fallback_text,
        )
        merged_en, merged_zh = _split_bilingual_lines(merged)
        merged_en = (merged_en or "").strip()
        merged_zh = (merged_zh or "").strip()
        if not merged_en and not merged_zh:
            continue
        if not merged_en:
            merged_en = merged_zh
        if not merged_zh:
            merged_zh = merged_en
        normalized.append({"english": merged_en, "chinese": merged_zh})

    text_lines = []
    for block in normalized:
        if learning_direction == "zh_to_en":
            text_lines.extend([block["chinese"], block["english"]])
        else:
            text_lines.extend([block["english"], block["chinese"]])
    return normalized, "\n".join(line for line in text_lines if line.strip())


def _default_question_explanation(question_type: str) -> str:
    if question_type == "vocabulary":
        return "Look at how the key word is used in the story sentence."
    if question_type == "inference":
        return "Use clues from the story to think about the best answer."
    return "Find the exact clue sentence in the story."


def _normalize_comprehension_questions(
    raw_questions: list | None,
    fallback_questions: list,
    learning_direction: str | None,
    block_count: int,
) -> list[dict]:
    default_types = ["literal", "vocabulary", "inference"]
    questions = raw_questions if isinstance(raw_questions, list) else []
    normalized = []
    for index in range(3):
        fallback = fallback_questions[index] if index < len(fallback_questions) else {}
        raw = (
            questions[index]
            if index < len(questions) and isinstance(questions[index], dict)
            else {}
        )
        use_fallback_question = not raw
        source = fallback if use_fallback_question else raw

        q_type = str(
            source.get(
                "question_type",
                fallback.get("question_type", default_types[min(index, len(default_types) - 1)]),
            )
        ).strip().lower()
        if q_type not in {"literal", "vocabulary", "inference"}:
            q_type = default_types[min(index, len(default_types) - 1)]

        question_text = _normalize_bilingual_line(
            str(source.get("question", "")),
            learning_direction=learning_direction,
            fallback_text=str(fallback.get("question", "")) if use_fallback_question else "",
        )
        raw_choices = source.get("choices", {})
        fallback_choices = fallback.get("choices", {})
        choices = {}
        for key in ["A", "B", "C"]:
            choices[key] = _normalize_bilingual_line(
                str(raw_choices.get(key, "")),
                learning_direction=learning_direction,
                fallback_text=(
                    str(fallback_choices.get(key, "")) if use_fallback_question else ""
                ),
            )
            if not choices[key].strip():
                seed_text = str(fallback_choices.get(key, "")).strip() or f"Option {key}"
                choices[key] = _normalize_bilingual_line(
                    seed_text,
                    learning_direction=learning_direction,
                )

        answer = str(source.get("answer", fallback.get("answer", "A"))).strip().upper()
        if answer not in {"A", "B", "C"}:
            answer = "A"
        explanation_en = str(source.get("explanation_en", "")).strip()
        if not explanation_en:
            if use_fallback_question:
                fallback_explanation = str(fallback.get("explanation_en", "")).strip()
                explanation_en = fallback_explanation or _default_question_explanation(q_type)
            else:
                explanation_en = _default_question_explanation(q_type)
        explanation_zh = str(source.get("explanation_zh", "")).strip()
        if not explanation_zh:
            fallback_zh = (
                str(fallback.get("explanation_zh", "")).strip()
                if use_fallback_question
                else ""
            )
            if fallback_zh and use_fallback_question:
                explanation_zh = fallback_zh
            else:
                try:
                    explanation_zh = translate_to_chinese(explanation_en)
                except LLMUnavailable:
                    explanation_zh = explanation_en

        evidence = source.get(
            "evidence_block_index",
            fallback.get("evidence_block_index", index),
        )
        if isinstance(evidence, int):
            if block_count > 0:
                evidence = max(0, min(evidence, block_count - 1))
            else:
                evidence = 0
        else:
            evidence = min(index, max(0, block_count - 1))

        normalized.append(
            {
                "question": question_text,
                "choices": choices,
                "answer": answer,
                "question_type": q_type,
                "explanation_en": explanation_en,
                "explanation_zh": explanation_zh,
                "evidence_block_index": evidence,
            }
        )
    return normalized


def _normalize_key_vocabulary(
    raw_vocab: list | None,
    fallback_vocab: list,
) -> list[dict]:
    source = raw_vocab if isinstance(raw_vocab, list) and raw_vocab else fallback_vocab
    normalized = []
    for item in source:
        if not isinstance(item, dict):
            continue
        word = str(item.get("word", "")).strip()
        meaning_en = str(item.get("meaning_en", "")).strip()
        meaning_zh = str(item.get("meaning_zh", "")).strip()
        if not word or not meaning_en:
            continue
        if not meaning_zh:
            try:
                meaning_zh = translate_to_chinese(meaning_en)
            except LLMUnavailable:
                meaning_zh = meaning_en
        normalized.append(
            {
                "word": word,
                "meaning_en": meaning_en,
                "meaning_zh": meaning_zh,
            }
        )
        if len(normalized) >= 5:
            break
    return normalized


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
    fallback_for_bilingual = simple_exercise(
        word,
        learning_direction=payload.learning_direction,
        output_style=payload.output_style,
    )

    cleaned_choices = {
        key: _strip_language_labels(value)
        for key, value in result["quiz_choices"].items()
    }
    cleaned_question = _strip_language_labels(result["quiz_question"])
    cleaned_definition = _strip_language_labels(result["definition"])
    cleaned_example = _strip_language_labels(result["example_sentence"])
    if payload.output_style == "bilingual":
        definition_fallback = (
            str(fallback_for_bilingual.get("definition", ""))
            if source != "llm"
            else ""
        )
        example_fallback = (
            str(fallback_for_bilingual.get("example_sentence", ""))
            if source != "llm"
            else ""
        )
        cleaned_definition = _ensure_bilingual_text(
            cleaned_definition,
            definition_fallback,
            payload.learning_direction,
        )
        cleaned_definition = _repair_definition_text(
            cleaned_definition,
            cleaned_choices,
            str(result.get("quiz_answer", "")),
            source,
            payload.learning_direction,
        )
        cleaned_example = _ensure_bilingual_text(
            cleaned_example,
            example_fallback,
            payload.learning_direction,
        )
        cleaned_example = _repair_example_text(
            cleaned_example,
            cleaned_definition,
            word,
            source,
            payload.learning_direction,
        )
        cleaned_question, cleaned_choices = _repair_quiz_text(
            word=word,
            quiz_question=cleaned_question,
            quiz_choices=cleaned_choices,
            quiz_answer=str(result.get("quiz_answer", "")),
            definition_text=cleaned_definition,
            source=source,
            learning_direction=payload.learning_direction,
        )
    definition_for_image, _ = _split_bilingual_lines(cleaned_definition)
    definition_seed = (
        definition_for_image.strip()
        if definition_for_image and definition_for_image.strip()
        else cleaned_definition.strip()
    )
    image_hint_enabled, image_hint_reason = vocab_image_hint_status(
        word=word,
        definition=definition_seed,
    )
    response = {
        "definition": cleaned_definition,
        "example_sentence": cleaned_example,
        "quiz_question": cleaned_question,
        "quiz_choices": cleaned_choices,
        "quiz_answer": result["quiz_answer"],
        "image_hint_enabled": image_hint_enabled,
        "image_hint_reason": image_hint_reason,
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


@app.post("/v1/vocab/image-hint", response_model=VocabImageHintResponse)
def vocab_image_hint(payload: VocabImageHintRequest) -> dict:
    try:
        word = sanitize_word(payload.word)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    cleaned_definition = _strip_language_labels(payload.definition or "")
    definition_en, _ = _split_bilingual_lines(cleaned_definition)
    definition_seed = (
        definition_en.strip()
        if definition_en and definition_en.strip()
        else cleaned_definition.strip()
    )

    image_hint_enabled, image_hint_reason = vocab_image_hint_status(
        word=word,
        definition=definition_seed,
    )
    if not image_hint_enabled:
        return {
            "image_hint_enabled": False,
            "image_hint_reason": image_hint_reason,
            "image_url": None,
        }

    try:
        image_url = generate_vocab_image(
            word=word,
            definition=definition_seed or f'the meaning of "{word}"',
        )
        inline_image = _inline_image_data(image_url)
        if inline_image:
            image_url = inline_image
        return {
            "image_hint_enabled": True,
            "image_hint_reason": None,
            "image_url": image_url,
        }
    except LLMUnavailable:
        return {
            "image_hint_enabled": True,
            "image_hint_reason": "generation_unavailable",
            "image_url": None,
        }


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

    fallback_story = simple_comprehension_exercise(
        level=payload.level,
        learning_direction=payload.learning_direction,
        output_style=payload.output_style,
    )

    cleaned_story_text = _strip_language_labels(result.get("story_text", ""))
    story_blocks, composed_story_text = _normalize_story_blocks(
        raw_blocks=result.get("story_blocks"),
        story_text=cleaned_story_text,
        fallback_blocks=fallback_story.get("story_blocks", []),
        learning_direction=payload.learning_direction,
    )
    questions = _normalize_comprehension_questions(
        raw_questions=result.get("questions"),
        fallback_questions=fallback_story.get("questions", []),
        learning_direction=payload.learning_direction,
        block_count=len(story_blocks),
    )
    key_vocabulary = _normalize_key_vocabulary(
        raw_vocab=result.get("key_vocabulary"),
        fallback_vocab=fallback_story.get("key_vocabulary", []),
    )

    response = {
        "story_title": result["story_title"],
        "story_text": composed_story_text or cleaned_story_text,
        "story_blocks": story_blocks,
        "key_vocabulary": key_vocabulary,
        "image_description": result["image_description"],
        "image_url": None,
        "questions": questions,
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


@app.get("/v1/progress/daily", response_model=DailyProgressResponse)
def progress_daily(child_name: str, days: int = 30, daily_goal: int = 3) -> dict:
    if days < 1 or days > 365:
        raise HTTPException(status_code=400, detail="days must be between 1 and 365.")
    if daily_goal < 1 or daily_goal > 50:
        raise HTTPException(
            status_code=400, detail="daily_goal must be between 1 and 50."
        )
    child_id = get_or_create_child(child_name.strip())
    return get_daily_progress(child_id=child_id, daily_goal=daily_goal, days=days)


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
