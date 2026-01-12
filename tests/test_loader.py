from app.vocab.loader import load_default_vocab


def test_load_default_vocab():
    words = load_default_vocab()
    assert isinstance(words, list)
    assert len(words) > 0
