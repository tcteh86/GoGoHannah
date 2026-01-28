import re

_PHONICS_PATTERNS = [
    "eigh",
    "igh",
    "tion",
    "sion",
    "tch",
    "ch",
    "sh",
    "th",
    "ph",
    "wh",
    "ck",
    "ng",
    "qu",
    "ee",
    "oo",
    "ai",
    "ay",
    "ea",
    "ie",
    "oa",
    "ou",
    "ow",
    "ar",
    "er",
    "ir",
    "or",
    "ur",
    "oi",
    "oy",
    "au",
    "aw",
]


def phonics_hint(word: str) -> str:
    """Generate a simple phonics hint for a word."""
    if not word:
        return ""
    cleaned = re.sub(r"[-']", " ", word.lower())
    tokens = cleaned.split()
    if not tokens:
        return ""
    return " / ".join("-".join(_split_token(token)) for token in tokens)


def _split_token(token: str) -> list[str]:
    parts: list[str] = []
    i = 0
    while i < len(token):
        matched = None
        for pattern in _PHONICS_PATTERNS:
            if token.startswith(pattern, i):
                matched = pattern
                break
        if matched:
            parts.append(matched)
            i += len(matched)
        else:
            parts.append(token[i])
            i += 1
    return parts
