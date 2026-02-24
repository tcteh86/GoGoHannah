from pathlib import Path

from fastapi.testclient import TestClient

from backend.app import main


client = TestClient(main.app)


def test_db_export_downloads_file_without_token(monkeypatch, tmp_path):
    db_file = tmp_path / "progress.db"
    db_file.write_bytes(b"sqlite-data")

    monkeypatch.setattr(main, "DB_PATH", Path(db_file))
    monkeypatch.setattr(main, "DEFAULT_DB_PATH", Path(db_file))
    monkeypatch.delenv("GOGOHANNAH_DB_EXPORT_TOKEN", raising=False)

    response = client.get("/v1/progress/db-export")

    assert response.status_code == 200
    assert response.content == b"sqlite-data"
    assert "attachment; filename=\"progress-" in response.headers.get(
        "content-disposition", ""
    )


def test_db_export_rejects_invalid_token(monkeypatch, tmp_path):
    db_file = tmp_path / "progress.db"
    db_file.write_bytes(b"sqlite-data")

    monkeypatch.setattr(main, "DB_PATH", Path(db_file))
    monkeypatch.setattr(main, "DEFAULT_DB_PATH", Path(db_file))
    monkeypatch.setenv("GOGOHANNAH_DB_EXPORT_TOKEN", "secret")

    response = client.get("/v1/progress/db-export")

    assert response.status_code == 401


def test_db_import_replaces_database_file(monkeypatch, tmp_path):
    db_file = tmp_path / "progress.db"
    db_file.write_bytes(b"old")

    monkeypatch.setattr(main, "DB_PATH", Path(db_file))
    monkeypatch.setenv("GOGOHANNAH_DB_EXPORT_TOKEN", "secret")

    response = client.post(
        "/v1/progress/db-import",
        headers={"X-DB-Export-Token": "secret"},
        files={"file": ("progress.db", b"new-db-content", "application/x-sqlite3")},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "imported"
    assert db_file.read_bytes() == b"new-db-content"


def test_vocab_custom_csv_import_and_export_roundtrip():
    child_name = "csv_roundtrip_child"
    csv_payload = b"word\napple\nbanana\n"

    import_response = client.post(
        "/v1/vocab/custom/import",
        data={"child_name": child_name, "mode": "replace"},
        files={"file": ("vocabulary.csv", csv_payload, "text/csv")},
    )
    assert import_response.status_code == 200
    assert import_response.json()["count"] == 2

    export_response = client.get(
        "/v1/vocab/custom/export",
        params={"child_name": child_name},
    )
    assert export_response.status_code == 200
    assert "word" in export_response.text
    assert "apple" in export_response.text
    assert "banana" in export_response.text
    assert "text/csv" in export_response.headers.get("content-type", "")
