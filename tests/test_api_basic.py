from fastapi.testclient import TestClient

from backend.app import app


client = TestClient(app)


def test_health_ok():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json().get("status") == "ok"


def test_vocab_default_returns_words():
    resp = client.get("/vocab/default")
    assert resp.status_code == 200
    data = resp.json()
    assert "words" in data
    assert isinstance(data["words"], list)
    assert len(data["words"]) > 0


def test_quick_check():
    resp = client.get("/quick-check?count=2")
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert len(data["items"]) == 2
    for item in data["items"]:
        assert "word" in item and "exercise" in item
