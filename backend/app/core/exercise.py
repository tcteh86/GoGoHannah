def simple_exercise(word: str) -> dict:
    """Deterministic fallback exercise so the app works without an LLM."""
    return {
        "definition": f"\"{word}\" is a word to learn.",
        "example_sentence": f"I can use the word {word} today.",
        "quiz_question": "Which word are we learning now?",
        "quiz_choices": {"A": word, "B": "apple", "C": "run"},
        "quiz_answer": "A",
    }


def simple_comprehension_exercise(level: str = "beginner") -> dict:
    """Deterministic fallback comprehension exercise."""
    story_title = "The Brave Turtle"
    story_text = (
        "Tina the turtle wanted to cross the garden. "
        "She moved slowly and safely. "
        "A friendly bird cheered her on. "
        "Tina reached the pond and felt proud."
    )
    return {
        "story_title": story_title,
        "story_text": story_text,
        "image_description": "A small turtle walking through a sunny garden.",
        "questions": [
            {
                "question": "Who is the story about?",
                "choices": {"A": "Tina the turtle", "B": "A big lion", "C": "A fast car"},
                "answer": "A",
            },
            {
                "question": "Where did Tina want to go?",
                "choices": {"A": "The pond", "B": "The moon", "C": "The city"},
                "answer": "A",
            },
            {
                "question": "How did Tina feel at the end?",
                "choices": {"A": "Proud", "B": "Angry", "C": "Sleepy"},
                "answer": "A",
            },
        ],
        "level": level,
    }
