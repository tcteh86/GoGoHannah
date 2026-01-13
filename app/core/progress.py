import os
import sqlite3
from typing import Dict, List

DB_PATH = os.path.join(os.path.dirname(__file__), '..', '..', 'progress.db')


def _get_connection() -> sqlite3.Connection:
    return sqlite3.connect(DB_PATH)

def init_db():
    """Initialize the database with required tables."""
    with _get_connection() as conn:
        cursor = conn.cursor()
        # Children table
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS children (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

        # Exercises table
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER,
            word TEXT NOT NULL,
            exercise_type TEXT NOT NULL,  -- 'quiz' or 'pronunciation'
            score INTEGER NOT NULL,
            correct BOOLEAN NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (child_id) REFERENCES children (id)
        )
    ''')

def get_or_create_child(name: str) -> int:
    """Get child ID or create new child."""
    with _get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT id FROM children WHERE name = ?', (name,))
        result = cursor.fetchone()

        if result:
            child_id = result[0]
        else:
            cursor.execute('INSERT INTO children (name) VALUES (?)', (name,))
            child_id = cursor.lastrowid
            conn.commit()

        return child_id

def save_exercise(child_id: int, word: str, exercise_type: str, score: int, correct: bool):
    """Save an exercise result."""
    with _get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO exercises (child_id, word, exercise_type, score, correct)
            VALUES (?, ?, ?, ?, ?)
        ''', (child_id, word, exercise_type, score, correct))
        conn.commit()

def get_child_progress(child_id: int) -> Dict:
    """Get progress summary for a child."""
    with _get_connection() as conn:
        cursor = conn.cursor()

        # Total exercises
        cursor.execute('SELECT COUNT(*) FROM exercises WHERE child_id = ?', (child_id,))
        total_exercises = cursor.fetchone()[0]

        # Correct answers
        cursor.execute('SELECT COUNT(*) FROM exercises WHERE child_id = ? AND correct = 1', (child_id,))
        correct_count = cursor.fetchone()[0]

        # Average scores by type
        cursor.execute('''
            SELECT exercise_type, AVG(score), COUNT(*)
            FROM exercises
            WHERE child_id = ?
            GROUP BY exercise_type
        ''', (child_id,))
        scores_by_type = {row[0]: {'avg_score': row[1], 'count': row[2]} for row in cursor.fetchall()}

        # Words with low scores (<70)
        cursor.execute('''
            SELECT word, AVG(score), COUNT(*)
            FROM exercises
            WHERE child_id = ? AND score < 70
            GROUP BY word
            ORDER BY AVG(score) ASC
        ''', (child_id,))
        weak_words = [{'word': row[0], 'avg_score': row[1], 'attempts': row[2]} for row in cursor.fetchall()}

    return {
        'total_exercises': total_exercises,
        'correct_count': correct_count,
        'accuracy': correct_count / total_exercises if total_exercises > 0 else 0,
        'scores_by_type': scores_by_type,
        'weak_words': weak_words
    }

def get_recommended_words(child_id: int, all_words: List[str], limit: int = 10) -> List[str]:
    """Get recommended words with smart prioritization:
    1. Weak words (score <70) practiced <3 times
    2. New words never practiced
    3. Avoid over-practiced words (>5 attempts)
    """
    with _get_connection() as conn:
        cursor = conn.cursor()

        # Get word statistics
        cursor.execute('''
            SELECT word, AVG(score), COUNT(*), MIN(score)
            FROM exercises
            WHERE child_id = ?
            GROUP BY word
        ''', (child_id,))
        
        word_stats = {}
        for row in cursor.fetchall():
            word_stats[row[0]] = {
                'avg_score': row[1],
                'attempts': row[2],
                'min_score': row[3]
            }

    # Categorize words
    weak_words = []  # score <70, attempts <3
    over_practiced = []  # attempts >=5
    practiced_words = set(word_stats.keys())
    
    for word, stats in word_stats.items():
        if stats['attempts'] >= 5:
            over_practiced.append(word)
        elif stats['avg_score'] < 70 and stats['attempts'] < 3:
            weak_words.append((word, stats['avg_score']))  # Include score for sorting
    
    # Sort weak words by score (worst first)
    weak_words.sort(key=lambda x: x[1])
    weak_words = [word for word, _ in weak_words]
    
    # New words (not practiced at all)
    new_words = [word for word in all_words if word not in practiced_words]
    
    # Combine: weak words first, then new words, exclude over-practiced
    recommended = []
    recommended.extend(weak_words)
    recommended.extend(new_words)
    
    # Remove over-practiced words
    recommended = [word for word in recommended if word not in over_practiced]
    
    return recommended[:limit]

def get_practiced_words_wheel(child_id: int) -> List[Dict]:
    """Get practiced words with stats for wheel visualization."""
    with _get_connection() as conn:
        cursor = conn.cursor()

        cursor.execute('''
            SELECT word, AVG(score), COUNT(*), MAX(created_at)
            FROM exercises
            WHERE child_id = ?
            GROUP BY word
            ORDER BY MAX(created_at) DESC
        ''', (child_id,))
        
        practiced_words = []
        for row in cursor.fetchall():
            practiced_words.append({
                'word': row[0],
                'avg_score': row[1],
                'attempts': row[2],
                'last_practiced': row[3]
            })
        
        return practiced_words

def clear_child_records(child_id: int):
    """Clear all exercise records for a child."""
    with _get_connection() as conn:
        cursor = conn.cursor()
        
        # Delete all exercises for this child
        cursor.execute('DELETE FROM exercises WHERE child_id = ?', (child_id,))
        # Delete the child record
        cursor.execute('DELETE FROM children WHERE id = ?', (child_id,))
        
        conn.commit()

# Initialize DB on import
init_db()
