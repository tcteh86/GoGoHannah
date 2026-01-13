from pathlib import Path

import pandas as pd

from app.core.safety import sanitize_word

DEFAULT_VOCAB_PATH = Path(__file__).parent / "default_vocab.csv"


def load_default_vocab() -> list[str]:
    """Load the built-in vocabulary list."""
    df = pd.read_csv(DEFAULT_VOCAB_PATH)
    words = df["word"].dropna().astype(str).str.strip().tolist()
    return [sanitize_word(word) for word in words]


def load_vocab_from_csv(uploaded_file) -> list[str]:
    """Load vocabulary list from an uploaded CSV with a required 'word' column."""
    df = pd.read_csv(uploaded_file)
    if "word" not in df.columns:
        raise ValueError("CSV must have a 'word' column.")
    words = df["word"].dropna().astype(str).str.strip().tolist()
    return [sanitize_word(word) for word in words]
