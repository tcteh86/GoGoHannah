from datetime import date as date_type
from datetime import timedelta

from .db import get_connection


def init_study_time() -> None:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS study_time (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                child_id INTEGER NOT NULL,
                date TEXT NOT NULL,
                total_seconds INTEGER NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(child_id, date)
            )
        """
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_study_time_child_date ON study_time(child_id, date)"
        )


def add_study_time(child_id: int, date: date_type, seconds: int) -> int:
    if seconds <= 0:
        return get_study_time(child_id, date)
    date_str = date.isoformat()
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO study_time (child_id, date, total_seconds)
            VALUES (?, ?, ?)
            ON CONFLICT(child_id, date)
            DO UPDATE SET total_seconds = total_seconds + excluded.total_seconds,
                         updated_at = CURRENT_TIMESTAMP
        """,
            (child_id, date_str, seconds),
        )
        conn.commit()
    return get_study_time(child_id, date)


def get_study_time(child_id: int, date: date_type) -> int:
    date_str = date.isoformat()
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT total_seconds FROM study_time WHERE child_id = ? AND date = ?",
            (child_id, date_str),
        )
        row = cursor.fetchone()
        return int(row[0]) if row else 0


def get_total_study_time(child_id: int) -> int:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT COALESCE(SUM(total_seconds), 0) FROM study_time WHERE child_id = ?",
            (child_id,),
        )
        row = cursor.fetchone()
        return int(row[0]) if row else 0


def get_study_time_range(
    child_id: int,
    start_date: date_type,
    end_date: date_type,
) -> int:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT COALESCE(SUM(total_seconds), 0)
            FROM study_time
            WHERE child_id = ? AND date >= ? AND date <= ?
        """,
            (child_id, start_date.isoformat(), end_date.isoformat()),
        )
        row = cursor.fetchone()
        return int(row[0]) if row else 0


def week_range(target: date_type) -> tuple[date_type, date_type]:
    start = target - timedelta(days=target.weekday())
    end = start + timedelta(days=6)
    return start, end


def month_range(target: date_type) -> tuple[date_type, date_type]:
    start = target.replace(day=1)
    if start.month == 12:
        next_month = start.replace(year=start.year + 1, month=1, day=1)
    else:
        next_month = start.replace(month=start.month + 1, day=1)
    end = next_month - timedelta(days=1)
    return start, end


init_study_time()
