from typing import Dict, List

from .db import get_connection


def init_db() -> None:
    """Initialize the database with required tables."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
        CREATE TABLE IF NOT EXISTS children (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """
        )
        cursor.execute(
            """
        CREATE TABLE IF NOT EXISTS exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER,
            word TEXT NOT NULL,
            exercise_type TEXT NOT NULL,
            score INTEGER NOT NULL,
            correct BOOLEAN NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (child_id) REFERENCES children (id)
        )
    """
        )


def get_or_create_child(name: str) -> int:
    """Get child ID or create new child."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM children WHERE name = ?", (name,))
        result = cursor.fetchone()

        if result:
            child_id = result[0]
        else:
            cursor.execute("INSERT INTO children (name) VALUES (?)", (name,))
            child_id = cursor.lastrowid
            conn.commit()

        return child_id


def save_exercise(child_id: int, word: str, exercise_type: str, score: int, correct: bool) -> None:
    """Save an exercise result."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO exercises (child_id, word, exercise_type, score, correct)
            VALUES (?, ?, ?, ?, ?)
        """,
            (child_id, word, exercise_type, score, correct),
        )
        conn.commit()


def get_child_progress(child_id: int) -> Dict:
    """Get progress summary for a child."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM exercises WHERE child_id = ?", (child_id,))
        total_exercises = cursor.fetchone()[0]

        cursor.execute(
            "SELECT COUNT(*) FROM exercises WHERE child_id = ? AND correct = 1",
            (child_id,),
        )
        correct_count = cursor.fetchone()[0]

        cursor.execute(
            """
            SELECT exercise_type, AVG(score), COUNT(*)
            FROM exercises
            WHERE child_id = ?
            GROUP BY exercise_type
        """,
            (child_id,),
        )
        scores_by_type = {
            row[0]: {"avg_score": row[1], "count": row[2]} for row in cursor.fetchall()
        }

        cursor.execute(
            """
            SELECT word, AVG(score), COUNT(*)
            FROM exercises
            WHERE child_id = ? AND score < 70
            GROUP BY word
            ORDER BY AVG(score) ASC
        """,
            (child_id,),
        )
        weak_words = [
            {"word": row[0], "avg_score": row[1], "attempts": row[2]}
            for row in cursor.fetchall()
        ]

    return {
        "total_exercises": total_exercises,
        "correct_count": correct_count,
        "accuracy": correct_count / total_exercises if total_exercises > 0 else 0,
        "scores_by_type": scores_by_type,
        "weak_words": weak_words,
    }


def get_recommended_words(child_id: int, all_words: List[str], limit: int = 10) -> List[str]:
    """Get recommended words with smart prioritization."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT word, AVG(score), COUNT(*), MIN(score)
            FROM exercises
            WHERE child_id = ?
            GROUP BY word
        """,
            (child_id,),
        )

        word_stats = {}
        for row in cursor.fetchall():
            word_stats[row[0]] = {
                "avg_score": row[1],
                "attempts": row[2],
                "min_score": row[3],
            }

    weak_words = []
    over_practiced = []
    practiced_words = set(word_stats.keys())

    for word, stats in word_stats.items():
        if stats["attempts"] >= 5:
            over_practiced.append(word)
        elif stats["avg_score"] < 70 and stats["attempts"] < 3:
            weak_words.append((word, stats["avg_score"]))

    weak_words.sort(key=lambda x: x[1])
    weak_words = [word for word, _ in weak_words]

    new_words = [word for word in all_words if word not in practiced_words]

    recommended = []
    recommended.extend(weak_words)
    recommended.extend(new_words)

    recommended = [word for word in recommended if word not in over_practiced]

    return recommended[:limit]


def get_recent_exercises(child_id: int, limit: int = 20) -> List[Dict]:
    """Get recent exercise history for a child."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT word, exercise_type, score, correct, created_at
            FROM exercises
            WHERE child_id = ?
            ORDER BY created_at DESC
            LIMIT ?
        """,
            (child_id, limit),
        )

        return [
            {
                "word": row[0],
                "exercise_type": row[1],
                "score": row[2],
                "correct": bool(row[3]),
                "created_at": row[4],
            }
            for row in cursor.fetchall()
        ]


def clear_child_records(child_id: int) -> None:
    """Clear all exercise records for a child."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM exercises WHERE child_id = ?", (child_id,))
        cursor.execute("DELETE FROM children WHERE id = ?", (child_id,))
        conn.commit()


init_db()
