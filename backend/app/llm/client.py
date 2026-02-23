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
            "word_count": "100-150",
            "complexity": "very simple words, short sentences, basic concepts",
            "question_complexity": "simple questions testing basic understanding",
        },
        "intermediate": {
            "word_count": "200-250",
            "complexity": "moderate vocabulary, varied sentence structure, some descriptive language",
            "question_complexity": "questions testing comprehension and inference",
        },
        "expert": {
            "word_count": "250-350",
            "complexity": "advanced vocabulary, complex sentences, rich descriptions",
            "question_complexity": "questions requiring analysis and critical thinking",
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

        prompt = f"""Generate a short, engaging children's storybook suitable for ages 5-9, followed by 3 multiple-choice comprehension questions.

Requirements:
- Story should be {config['word_count']} words, {config['complexity']}
- Include vocabulary appropriate for the level
- Questions: {config['question_complexity']}
- Each question has 3 choices (A, B, C)
- Provide a detailed image description for an illustration of the main scene
{context_block}

{"Focus on theme: " + theme if theme else "Choose an appropriate theme like animals, family, school, adventure, or friendship."}

Return JSON with:
{{
  "story_title": "Story Title",
  "story_text": "Full story text...",
  "image_description": "Detailed description for illustration...",
  "questions": [
    {{
      "question": "Question 1?",
      "choices": {{"A": "Option A", "B": "Option B", "C": "Option C"}},
      "answer": "A"
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

        required_keys = ["story_title", "story_text", "image_description", "questions"]
        if not all(key in result for key in required_keys):
            raise ValueError("Incomplete response from LLM.")

        if not isinstance(result["questions"], list) or len(result["questions"]) != 3:
            raise ValueError("Must have exactly 3 questions.")

        for question in result["questions"]:
            if not all(k in question for k in ["question", "choices", "answer"]):
                raise ValueError("Invalid question format.")
            if set(question["choices"].keys()) != {"A", "B", "C"}:
                raise ValueError("Invalid choices format.")
            if question["answer"] not in ["A", "B", "C"]:
                raise ValueError("Invalid answer.")

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
