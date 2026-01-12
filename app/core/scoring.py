from rapidfuzz import fuzz


def check_answer(selected: str, correct: str) -> bool:
    """Return True if selected choice matches correct answer."""
    return (selected or "").strip().upper() == (correct or "").strip().upper()


def calculate_pronunciation_score(user_input: str, correct_word: str) -> int:
    """Calculate pronunciation score based on text similarity (0-100)."""
    if not user_input.strip():
        return 0
    # Use fuzzy string matching
    score = fuzz.ratio(user_input.strip().lower(), correct_word.lower())
    return int(score)
