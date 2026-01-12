def simple_exercise(word: str) -> dict:
    """Deterministic fallback exercise so the app works without an LLM."""
    return {
        "definition": f'\"{word}\" is a word to learn.',
        "example_sentence": f"I can use the word {word} today.",
        "quiz_question": "Which word are we learning now?",
        "quiz_choices": {"A": word, "B": "apple", "C": "run"},
        "quiz_answer": "A",
    }
