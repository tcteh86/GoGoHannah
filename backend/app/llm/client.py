"""LLM client wrapper using OpenAI."""

import json
import os
import re
from typing import Any, Dict

from dotenv import load_dotenv
from openai import OpenAI

from .prompts import build_system_prompt, build_story_system_prompt, build_task_prompt

load_dotenv()


def get_api_key() -> str:
    """Get OpenAI API key from environment."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY not found in environment variables.")
    return api_key


_client = None


def get_client() -> OpenAI:
    global _client
    if _client is None:
        api_key = get_api_key()
        _client = OpenAI(api_key=api_key)
    return _client


MODEL_NAME = os.getenv("OPENAI_TEXT_MODEL", "gpt-4o-mini")
IMAGE_MODEL = os.getenv("OPENAI_IMAGE_MODEL", "dall-e-3")
TRANSCRIBE_MODEL = os.getenv("OPENAI_TRANSCRIBE_MODEL", "whisper-1")
EMBEDDING_MODEL = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")


class LLMUnavailable(Exception):
    pass


_TEMPLATE_DEFINITION_PATTERNS = (
    "is a word to learn",
    "word to learn",
    "要学习的词",
    "学习的词",
    "单词",
)

_TEMPLATE_EXAMPLE_PATTERNS = (
    "i can use the word",
    "我今天可以使用",
    "use the word",
)

_TEMPLATE_QUIZ_CHOICE_PATTERNS = (
    "the meaning of",
    "的意思",
    "word to learn",
)


def _is_template_definition(text: str) -> bool:
    normalized = str(text or "").strip().lower()
    if not normalized:
        return True
    return any(pattern in normalized for pattern in _TEMPLATE_DEFINITION_PATTERNS)


def _is_template_example(text: str) -> bool:
    normalized = str(text or "").strip().lower()
    if not normalized:
        return True
    return any(pattern in normalized for pattern in _TEMPLATE_EXAMPLE_PATTERNS)


def _is_low_quality_quiz_choice(text: str, word: str) -> bool:
    normalized = str(text or "").strip().lower()
    if not normalized:
        return True
    if word.strip().lower() in normalized and "meaning" in normalized:
        return True
    return any(pattern in normalized for pattern in _TEMPLATE_QUIZ_CHOICE_PATTERNS)


def _has_low_quality_quiz(result: dict, word: str) -> bool:
    choices = result.get("quiz_choices")
    answer = str(result.get("quiz_answer", "")).strip()
    if not isinstance(choices, dict) or answer not in {"A", "B", "C"}:
        return True
    correct_choice = str(choices.get(answer, ""))
    return _is_low_quality_quiz_choice(correct_choice, word)


def suggest_vocab_corrections(words: list[str]) -> list[str]:
    """Suggest spelling corrections for a list of vocabulary words."""
    if not words:
        return []
    joined = "\n".join(f"- {word}" for word in words)
    prompt = f"""You are helping parents enter vocabulary words for children.
Fix obvious spelling mistakes, but keep the same meaning.
If a word already looks correct, keep it unchanged.
Return JSON with:
{{"suggested": ["word1", "word2", ...]}}
List must be the same length and order as input.
Only return words with letters, spaces, hyphens, or apostrophes.

Input words:
{joined}
"""
    try:
        response = get_client().chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {
                    "role": "system",
                    "content": "You are a careful spelling assistant for children vocabulary.",
                },
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.2,
            max_tokens=300,
        )
        result = json.loads(response.choices[0].message.content.strip())
        suggested = result.get("suggested")
        if not isinstance(suggested, list):
            raise ValueError("Invalid suggestion format.")
        cleaned = [str(word).strip() for word in suggested]
        if len(cleaned) != len(words):
            raise ValueError("Suggestion length mismatch.")
        return cleaned
    except Exception as exc:
        raise LLMUnavailable(f"Failed to suggest corrections: {str(exc)}")


def generate_vocab_exercise(
    word: str,
    context: list[str] | None = None,
    learning_direction: str | None = None,
    output_style: str | None = None,
) -> Dict[str, Any]:
    """Generate a vocab exercise for `word` using OpenAI."""
    try:
        for attempt in range(2):
            extra_quality_rule = ""
            if attempt == 1:
                extra_quality_rule = (
                    "\nQuality correction:\n"
                    "- Definition must be concrete and word-specific.\n"
                    "- Example sentence must be natural and word-specific.\n"
                    "- Quiz choices must be meaningful, not templates.\n"
                    "- Never use templates like 'is a word to learn' or '是一个要学习的词'.\n"
                    "- Never use template examples like 'I can use the word ... today'.\n"
                    "- Never use template quiz choices like 'the meaning of ...'.\n"
                    "- If bilingual, Chinese definition must clearly translate the English meaning.\n"
                )
            response = get_client().chat.completions.create(
                model=MODEL_NAME,
                messages=[
                    {
                        "role": "system",
                        "content": build_system_prompt(
                            learning_direction=learning_direction,
                            output_style=output_style,
                        ),
                    },
                    {
                        "role": "user",
                        "content": build_task_prompt(word, context=context)
                        + extra_quality_rule,
                    },
                ],
                response_format={"type": "json_object"},
                temperature=0.7,
                max_tokens=300,
            )

            result = json.loads(response.choices[0].message.content.strip())

            required_keys = [
                "definition",
                "example_sentence",
                "quiz_question",
                "quiz_choices",
                "quiz_answer",
            ]
            if not all(key in result for key in required_keys):
                raise ValueError("Incomplete response from LLM.")

            if not isinstance(result["quiz_choices"], dict) or set(
                result["quiz_choices"].keys()
            ) != {"A", "B", "C"}:
                raise ValueError("Invalid quiz_choices format.")

            if result["quiz_answer"] not in ["A", "B", "C"]:
                raise ValueError("Invalid quiz_answer.")

            definition = str(result.get("definition", ""))
            example_sentence = str(result.get("example_sentence", ""))
            if _is_template_definition(definition):
                if attempt == 0:
                    continue
                raise ValueError("Template definition detected.")
            if _is_template_example(example_sentence):
                if attempt == 0:
                    continue
                raise ValueError("Template example sentence detected.")
            if _has_low_quality_quiz(result, word):
                if attempt == 0:
                    continue
                raise ValueError("Low-quality quiz choice detected.")

            return result
        raise ValueError("Unable to generate non-template definition.")

    except Exception as exc:
        raise LLMUnavailable(f"Failed to generate exercise: {str(exc)}")


def translate_to_chinese(text: str) -> str:
    """Translate a short meaning sentence into natural Chinese."""
    if not text.strip():
        raise LLMUnavailable("Empty text for translation.")
    try:
        prompt = f"""Translate this short vocabulary meaning sentence into natural, child-friendly Chinese.
Return plain Chinese text only.
Do not include labels, notes, or quotes.

Sentence:
{text}
"""
        response = get_client().chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {
                    "role": "system",
                    "content": "You are a precise English-to-Chinese translator for children.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.2,
            max_tokens=120,
        )
        translated = response.choices[0].message.content.strip()
        # Keep only one concise line if the model returns multiple lines.
        translated = re.split(r"\r?\n", translated)[0].strip()
        if not translated:
            raise ValueError("Empty translation result.")
        return translated
    except Exception as exc:
        raise LLMUnavailable(f"Failed to translate definition: {str(exc)}")


def generate_example_sentence(word: str, definition: str) -> str:
    """Generate one natural example sentence for a target word."""
    if not word.strip():
        raise LLMUnavailable("Empty word for example generation.")
    try:
        prompt = f"""Create one short, natural example sentence for children aged 5-9.
Requirements:
- Use the target word exactly as given.
- Keep sentence under 12 words.
- Match this meaning: {definition}
- Return only one plain sentence (no labels).

Target word: {word}
"""
        response = get_client().chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {
                    "role": "system",
                    "content": "You write short, child-friendly English examples.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
            max_tokens=80,
        )
        sentence = response.choices[0].message.content.strip()
        sentence = re.split(r"\r?\n", sentence)[0].strip()
        if not sentence:
            raise ValueError("Empty example sentence result.")
        return sentence
    except Exception as exc:
        raise LLMUnavailable(f"Failed to generate example sentence: {str(exc)}")


def _normalize_story_blocks(raw_blocks: Any) -> list[dict]:
    blocks = []
    if isinstance(raw_blocks, list):
        for item in raw_blocks:
            if not isinstance(item, dict):
                continue
            english = str(item.get("english", "")).strip()
            chinese = str(item.get("chinese", "")).strip()
            if english or chinese:
                blocks.append({"english": english, "chinese": chinese})
    return blocks


def _normalize_key_vocabulary(raw_vocab: Any) -> list[dict]:
    entries = []
    if isinstance(raw_vocab, list):
        for item in raw_vocab:
            if not isinstance(item, dict):
                continue
            word = str(item.get("word", "")).strip()
            meaning_en = str(item.get("meaning_en", "")).strip()
            meaning_zh = str(item.get("meaning_zh", "")).strip()
            if word and (meaning_en or meaning_zh):
                entries.append(
                    {"word": word, "meaning_en": meaning_en, "meaning_zh": meaning_zh}
                )
    return entries[:5]


def _compose_story_text_from_blocks(
    blocks: list[dict],
    learning_direction: str | None,
    output_style: str | None,
) -> str:
    lines = []
    bilingual = (output_style or "immersion") == "bilingual" or learning_direction == "both"
    for block in blocks:
        english = str(block.get("english", "")).strip()
        chinese = str(block.get("chinese", "")).strip()
        if bilingual:
            if learning_direction == "zh_to_en":
                if chinese:
                    lines.append(chinese)
                if english:
                    lines.append(english)
            else:
                if english:
                    lines.append(english)
                if chinese:
                    lines.append(chinese)
        else:
            if learning_direction == "en_to_zh":
                if chinese:
                    lines.append(chinese)
            elif learning_direction == "zh_to_en":
                if english:
                    lines.append(english)
            else:
                if english:
                    lines.append(english)
    return "\n".join(lines).strip()


def _normalize_comprehension_questions(raw_questions: Any, block_count: int) -> list[dict]:
    if not isinstance(raw_questions, list):
        raise ValueError("questions must be a list.")
    if len(raw_questions) != 3:
        raise ValueError("Must have exactly 3 questions.")

    normalized = []
    default_types = ["literal", "vocabulary", "inference"]
    for index, question in enumerate(raw_questions):
        if not isinstance(question, dict):
            raise ValueError("Invalid question format.")
        if not all(k in question for k in ["question", "choices", "answer"]):
            raise ValueError("Invalid question format.")
        choices = question.get("choices")
        if not isinstance(choices, dict) or set(choices.keys()) != {"A", "B", "C"}:
            raise ValueError("Invalid choices format.")
        answer = str(question.get("answer", "")).strip()
        if answer not in {"A", "B", "C"}:
            raise ValueError("Invalid answer.")
        q_type = str(question.get("question_type", default_types[index])).strip().lower()
        if q_type not in {"literal", "vocabulary", "inference"}:
            q_type = default_types[index]
        evidence_index = question.get("evidence_block_index")
        if isinstance(evidence_index, int):
            if block_count > 0:
                evidence_index = max(0, min(evidence_index, block_count - 1))
            else:
                evidence_index = 0
        else:
            evidence_index = min(index, max(0, block_count - 1))

        normalized.append(
            {
                "question": str(question.get("question", "")).strip(),
                "choices": {key: str(value).strip() for key, value in choices.items()},
                "answer": answer,
                "question_type": q_type,
                "explanation_en": str(question.get("explanation_en", "")).strip(),
                "explanation_zh": str(question.get("explanation_zh", "")).strip(),
                "evidence_block_index": evidence_index,
            }
        )
    return normalized


def generate_comprehension_exercise(
    theme: str = None,
    level: str = "intermediate",
    context: list[str] | None = None,
    learning_direction: str | None = None,
    output_style: str | None = None,
) -> Dict[str, Any]:
    """Generate a comprehension exercise with a short story and questions."""
    level_configs = {
        "beginner": {
            "word_count": "50-90",
            "complexity": "very simple words, short sentences, clear events",
            "question_complexity": "Q1 literal, Q2 vocabulary-in-context, Q3 simple inference",
        },
        "intermediate": {
            "word_count": "140-200",
            "complexity": "moderate vocabulary, varied sentence structure, some descriptive language",
            "question_complexity": "Q1 literal, Q2 vocabulary-in-context, Q3 inference",
        },
        "expert": {
            "word_count": "220-300",
            "complexity": "advanced vocabulary, complex sentences, rich descriptions",
            "question_complexity": "Q1 literal, Q2 vocabulary-in-context, Q3 deeper inference",
        },
    }

    config = level_configs.get(level, level_configs["intermediate"])

    try:
        context_block = ""
        if context:
            context_lines = "\n".join(f"- {item}" for item in context)
            context_block = (
                "\nReference context (use for consistency only; do not copy verbatim):\n"
                f"{context_lines}\n"
            )

        prompt = f"""Generate a short, engaging children's story for ages 5-9, followed by 3 multiple-choice comprehension questions.

Requirements:
- Story should be {config['word_count']} words, {config['complexity']}
- Story should be split into 4-6 short blocks for early readers
- Each story block must have:
  - "english": one short English line
  - "chinese": one direct Chinese translation line
- Include 3 key vocabulary words from the story with EN/ZH meaning
- Questions: {config['question_complexity']}
- Each question has 3 choices (A, B, C)
- Each question must include:
  - "question_type": literal | vocabulary | inference
  - "explanation_en": one short reason for the answer
  - "explanation_zh": Chinese translation of the reason
  - "evidence_block_index": integer index pointing to supporting story block
- Provide a detailed image description for an illustration of the main scene
{context_block}

{"Focus on theme: " + theme if theme else "Choose an appropriate theme like animals, family, school, adventure, or friendship."}

Return JSON with:
{{
  "story_title": "Story Title",
  "story_text": "Optional full story text...",
  "story_blocks": [
    {{"english": "Line 1", "chinese": "第1句翻译"}},
    {{"english": "Line 2", "chinese": "第2句翻译"}}
  ],
  "key_vocabulary": [
    {{"word": "brave", "meaning_en": "showing courage", "meaning_zh": "有勇气的"}},
    {{"word": "pond", "meaning_en": "a small body of water", "meaning_zh": "池塘"}},
    {{"word": "proud", "meaning_en": "happy about doing well", "meaning_zh": "自豪的"}}
  ],
  "image_description": "Detailed description for illustration...",
  "questions": [
    {{
      "question": "Question 1?",
      "choices": {{"A": "Option A", "B": "Option B", "C": "Option C"}},
      "answer": "A",
      "question_type": "literal",
      "explanation_en": "Short reason",
      "explanation_zh": "中文原因",
      "evidence_block_index": 0
    }},
    ...
  ]
}}"""

        response = get_client().chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {
                    "role": "system",
                    "content": build_story_system_prompt(
                        learning_direction=learning_direction,
                        output_style=output_style,
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.8,
            max_tokens=1000,
        )

        result = json.loads(response.choices[0].message.content.strip())

        required_keys = ["story_title", "image_description", "questions"]
        if not all(key in result for key in required_keys):
            raise ValueError("Incomplete response from LLM.")

        story_blocks = _normalize_story_blocks(result.get("story_blocks"))
        story_text = str(result.get("story_text", "")).strip()
        if not story_blocks and story_text:
            # Fallback for older prompts: treat each line as an English block.
            lines = [line.strip() for line in story_text.splitlines() if line.strip()]
            story_blocks = [
                {"english": line, "chinese": ""}
                for line in lines
            ]
        if not story_blocks:
            raise ValueError("Missing story blocks.")
        key_vocabulary = _normalize_key_vocabulary(result.get("key_vocabulary"))
        questions = _normalize_comprehension_questions(
            result.get("questions"), block_count=len(story_blocks)
        )
        if not story_text:
            story_text = _compose_story_text_from_blocks(
                story_blocks,
                learning_direction=learning_direction,
                output_style=output_style,
            )

        result["story_blocks"] = story_blocks
        result["key_vocabulary"] = key_vocabulary
        result["questions"] = questions
        result["story_text"] = story_text

        return result

    except Exception as exc:
        raise LLMUnavailable(f"Failed to generate comprehension exercise: {str(exc)}")


def transcribe_audio(audio_bytes: bytes, filename: str | None = None) -> str:
    """Transcribe audio using OpenAI Whisper."""
    try:
        from io import BytesIO

        audio_file = BytesIO(audio_bytes)
        audio_file.name = filename or "audio.wav"

        transcript = get_client().audio.transcriptions.create(
            model=TRANSCRIBE_MODEL,
            file=audio_file,
            response_format="text",
        )
        return transcript.strip()
    except Exception as exc:
        raise LLMUnavailable(f"Failed to transcribe audio: {str(exc)}")


def embed_text(text: str) -> list[float]:
    """Create embeddings for a text snippet."""
    try:
        response = get_client().embeddings.create(
            model=EMBEDDING_MODEL,
            input=text,
        )
        return response.data[0].embedding
    except Exception as exc:
        raise LLMUnavailable(f"Failed to embed text: {str(exc)}")


def generate_story_image(description: str) -> str:
    """Generate an image for a story scene using OpenAI DALL-E."""
    try:
        response = get_client().images.generate(
            model=IMAGE_MODEL,
            prompt=(
                "Create a colorful, child-friendly illustration for a children's story: "
                f"{description}. Style: cartoon, bright colors, suitable for ages 5-9."
            ),
            size="1024x1024",
            quality="standard",
            n=1,
        )
        return response.data[0].url
    except Exception as exc:
        raise LLMUnavailable(f"Failed to generate image: {str(exc)}")
