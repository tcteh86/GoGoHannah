import os
import sqlite3
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
DEFAULT_DB_PATH = DATA_DIR / "progress.db"
DB_PATH = Path(os.getenv("GOGOHANNAH_DB_PATH", str(DEFAULT_DB_PATH)))


def _ensure_parent(path: Path) -> bool:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        return True
    except OSError:
        return False


def get_connection() -> sqlite3.Connection:
    db_path = DB_PATH
    if not _ensure_parent(db_path):
        db_path = DEFAULT_DB_PATH
        if not _ensure_parent(db_path):
            raise PermissionError("Unable to create database directory.")
    return sqlite3.connect(str(db_path))
