from backend.app.core.scoring import check_answer


def test_check_answer():
    assert check_answer("a", "A") is True
    assert check_answer("B", "A") is False
