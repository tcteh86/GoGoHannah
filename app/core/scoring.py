def check_answer(selected: str, correct: str) -> bool:
    """Return True if selected choice matches correct answer."""
    return (selected or "").strip().upper() == (correct or "").strip().upper()
