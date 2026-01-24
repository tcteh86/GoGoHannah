"""LLM client wrapper using OpenAI."""

import json
import os
from typing import Any, Dict

from dotenv import load_dotenv
from openai import OpenAI

from .prompts import SYSTEM_PROMPT, build_task_prompt

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


def generate_vocab_exercise(word: str, context: list[str] | None = None) -> Dict[str, Any]:
    """Generate a vocab exercise for `word` using OpenAI."""
    try:
        response = get_client().chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": build_task_prompt(word, context=context)},
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

        return result

    except Exception as exc:
        raise LLMUnavailable(f"Failed to generate exercise: {str(exc)}")


def generate_comprehension_exercise(
    theme: str = None,
    level: str = "intermediate",
    context: list[str] | None = None,
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
                    "content": "You are a creative children's book author. Generate engaging, educational storybooks with vivid descriptions.",
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
