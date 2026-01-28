from pathlib import Path

import pandas as pd

from ..core.safety import sanitize_word

DEFAULT_VOCAB_PATH = Path(__file__).parent / "default_vocab.csv"


def load_default_vocab() -> list[str]:
    """Load the built-in vocabulary list."""
    df = pd.read_csv(DEFAULT_VOCAB_PATH)
    words = df["word"].dropna().astype(str).str.strip().tolist()
    return [sanitize_word(word) for word in words]


def load_vocab_from_csv(uploaded_file) -> list[str]:
    """Load vocabulary list from an uploaded CSV.

    Accepts either a 'word' header column or a single-column headerless CSV.
    """
    df = pd.read_csv(uploaded_file)
    if "word" in df.columns:
        words = df["word"].dropna().astype(str).str.strip().tolist()
    elif len(df.columns) >= 1:
        words = df.iloc[:, 0].dropna().astype(str).str.strip().tolist()
    else:
        raise ValueError("CSV must include at least one column of words.")
    return [sanitize_word(word) for word in words]
