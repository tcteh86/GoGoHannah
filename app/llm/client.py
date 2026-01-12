"""LLM client wrapper (stub).

This file is intentionally a stub so the MVP runs without any API key.

Later, you can implement a Gemini client here and return structured JSON
that matches the keys required by the app.
"""

from __future__ import annotations


class LLMUnavailable(Exception):
    pass


def generate_vocab_exercise(word: str) -> dict:
    """Generate a vocab exercise for `word` using an LLM.

    Returns:
        dict with keys:
          - definition
          - example_sentence
          - quiz_question
          - quiz_choices (dict: {"A":..., "B":..., "C":...})
          - quiz_answer ("A"/"B"/"C")
    """
    raise LLMUnavailable("LLM integration not configured yet.")
