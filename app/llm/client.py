"""LLM client wrapper using OpenAI."""

import json
import os
from typing import Dict, Any

from openai import OpenAI
from dotenv import load_dotenv

from .prompts import SYSTEM_PROMPT, build_task_prompt

# Load environment variables
load_dotenv()

# Configure OpenAI - check both .env and Streamlit secrets
API_KEY = os.getenv("OPENAI_API_KEY")
if not API_KEY:
    try:
        import streamlit as st
        API_KEY = st.secrets.get("OPENAI_API_KEY")
    except:
        pass

if not API_KEY:
    raise ValueError("OPENAI_API_KEY not found in environment variables or Streamlit secrets.")

client = OpenAI(api_key=API_KEY)

# Use GPT-4o Mini for cost-effectiveness
MODEL_NAME = "gpt-4o-mini"


class LLMUnavailable(Exception):
    pass


def generate_vocab_exercise(word: str) -> Dict[str, Any]:
    """Generate a vocab exercise for `word` using OpenAI.

    Returns:
        dict with keys:
          - definition
          - example_sentence
          - quiz_question
          - quiz_choices (dict: {"A":..., "B":..., "C":...})
          - quiz_answer ("A"/"B"/"C")
    """
    try:
        prompt = SYSTEM_PROMPT + "\n\n" + build_task_prompt(word)
        response = client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": build_task_prompt(word)}
            ],
            response_format={"type": "json_object"},
            temperature=0.7,
            max_tokens=300,
        )

        # Parse JSON response
        result = json.loads(response.choices[0].message.content.strip())

        # Validate structure
        required_keys = ["definition", "example_sentence", "quiz_question", "quiz_choices", "quiz_answer"]
        if not all(key in result for key in required_keys):
            raise ValueError("Incomplete response from LLM.")

        # Ensure quiz_choices is dict with A,B,C
        if not isinstance(result["quiz_choices"], dict) or set(result["quiz_choices"].keys()) != {"A", "B", "C"}:
            raise ValueError("Invalid quiz_choices format.")

        if result["quiz_answer"] not in ["A", "B", "C"]:
            raise ValueError("Invalid quiz_answer.")

        return result

    except Exception as e:
        raise LLMUnavailable(f"Failed to generate exercise: {str(e)}")


def generate_comprehension_exercise(theme: str = None, level: str = "intermediate") -> Dict[str, Any]:
    """Generate a comprehension exercise with a short story and questions.

    Args:
        theme: Optional theme for the story (e.g., "animals", "family")
        level: Difficulty level - "beginner", "intermediate", "expert"

    Returns:
        dict with keys:
          - story_title
          - story_text
          - image_description
          - questions (list of dicts: [{"question": ..., "choices": {"A":..., "B":..., "C":...}, "answer": "A"}])
    """
    # Adjust parameters based on level
    level_configs = {
        "beginner": {
            "word_count": "100-150",
            "complexity": "very simple words, short sentences, basic concepts",
            "question_complexity": "simple questions testing basic understanding"
        },
        "intermediate": {
            "word_count": "200-250",
            "complexity": "moderate vocabulary, varied sentence structure, some descriptive language",
            "question_complexity": "questions testing comprehension and inference"
        },
        "expert": {
            "word_count": "250-350",
            "complexity": "advanced vocabulary, complex sentences, rich descriptions",
            "question_complexity": "questions requiring analysis and critical thinking"
        }
    }
    
    config = level_configs.get(level, level_configs["intermediate"])
    
    try:
        prompt = f"""Generate a short, engaging children's storybook suitable for ages 5-9, followed by 3 multiple-choice comprehension questions.

Requirements:
- Story should be {config['word_count']} words, {config['complexity']}
- Include vocabulary appropriate for the level
- Questions: {config['question_complexity']}
- Each question has 3 choices (A, B, C)
- Provide a detailed image description for an illustration of the main scene

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

        response = client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": "You are a creative children's book author. Generate engaging, educational storybooks with vivid descriptions."},
                {"role": "user", "content": prompt}
            ],
            response_format={"type": "json_object"},
            temperature=0.8,
            max_tokens=1000,
        )

        result = json.loads(response.choices[0].message.content.strip())

        # Validate
        required_keys = ["story_title", "story_text", "image_description", "questions"]
        if not all(key in result for key in required_keys):
            raise ValueError("Incomplete response from LLM.")

        if not isinstance(result["questions"], list) or len(result["questions"]) != 3:
            raise ValueError("Must have exactly 3 questions.")

        for q in result["questions"]:
            if not all(k in q for k in ["question", "choices", "answer"]):
                raise ValueError("Invalid question format.")
            if set(q["choices"].keys()) != {"A", "B", "C"}:
                raise ValueError("Invalid choices format.")
            if q["answer"] not in ["A", "B", "C"]:
                raise ValueError("Invalid answer.")

        return result

    except Exception as e:
        raise LLMUnavailable(f"Failed to generate comprehension exercise: {str(e)}")


def transcribe_audio(audio_bytes: bytes) -> str:
    """Transcribe audio using OpenAI Whisper."""
    try:
        from io import BytesIO
        audio_file = BytesIO(audio_bytes)
        audio_file.name = "audio.wav"  # Required for OpenAI API

        transcript = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file,
            response_format="text"
        )
        return transcript.strip()
    except Exception as e:
        raise LLMUnavailable(f"Failed to transcribe audio: {str(e)}")


def generate_story_image(description: str) -> str:
    """Generate an image for a story scene using OpenAI DALL-E."""
    try:
        response = client.images.generate(
            model="dall-e-3",
            prompt=f"Create a colorful, child-friendly illustration for a children's story: {description}. Style: cartoon, bright colors, suitable for ages 5-9.",
            size="1024x1024",
            quality="standard",
            n=1,
        )
        return response.data[0].url
    except Exception as e:
        raise LLMUnavailable(f"Failed to generate image: {str(e)}")
