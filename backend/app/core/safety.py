import re

# Conservative whitelist: letters, spaces, hyphen, apostrophe, basic CJK
_ALLOWED = re.compile(r"^[A-Za-z\u4e00-\u9fff\s\-']{1,32}$")


def sanitize_word(word: str) -> str:
    """Sanitize a vocabulary word.

    Raises:
        ValueError if the word contains unsafe characters or is too long.
    """
    w = (word or "").strip()
    if not _ALLOWED.match(w):
        raise ValueError(
            "Invalid word. Use only letters, Chinese characters, spaces, - or '. "
            "Max 32 chars."
        )
            "Invalid word. Use only letters, Chinese characters, spaces, - or '. "
            "Max 32 chars."
        )
    return w
