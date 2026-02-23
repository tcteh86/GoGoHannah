_FALLBACK_MEANINGS = {
    "happy": ("feeling glad and full of joy.", "感到开心和快乐。"),
    "sad": ("feeling unhappy.", "感到难过。"),
    "brave": ("showing courage when something feels hard.", "在困难时表现出勇气。"),
    "gentle": ("kind, soft, and not rough.", "温和、不粗暴。"),
    "kind": ("being nice and helpful to others.", "对别人友善并愿意帮助。"),
    "strong": ("having a lot of power in body or mind.", "身体或意志有力量。"),
    "clever": ("quick at learning and solving problems.", "聪明，学得快。"),
    "friendly": ("kind and easy to get along with.", "友好，容易相处。"),
    "excited": ("feeling very happy and eager.", "感到兴奋和期待。"),
    "angry": ("feeling mad about something.", "感到生气。"),
    "calm": ("peaceful and not upset.", "平静，不紧张。"),
    "funny": ("making people laugh.", "让人发笑。"),
    "shy": ("nervous around people you do not know well.", "在人前容易害羞。"),
    "loud": ("making a strong sound.", "声音很大。"),
    "quiet": ("making little or no sound.", "声音很小或安静。"),
    "fast": ("moving or happening quickly.", "移动或发生得很快。"),
    "slow": ("moving or happening with little speed.", "移动或发生得很慢。"),
    "big": ("large in size.", "体积大。"),
    "small": ("little in size.", "体积小。"),
    "hot": ("having a high temperature.", "温度高，很热。"),
    "cold": ("having a low temperature.", "温度低，很冷。"),
    "safe": ("free from danger.", "安全，没有危险。"),
    "dangerous": ("able to cause harm.", "危险，可能造成伤害。"),
}


def _fallback_definition(word: str) -> tuple[str, str]:
    meaning = _FALLBACK_MEANINGS.get(word.lower())
    if meaning:
        return meaning
    return (
        f'"{word}" has a specific meaning used in daily life.',
        f'“{word}” 在日常生活中有具体含义。',
    )


def simple_exercise(
    word: str,
    learning_direction: str | None = None,
    output_style: str | None = None,
) -> dict:
    """Deterministic fallback exercise so the app works without an LLM."""
    meaning_en, meaning_zh = _fallback_definition(word)
    if not learning_direction:
        return {
            "definition": meaning_en,
            "example_sentence": f"I can use the word {word} today.",
            "quiz_question": f"What is the meaning of \"{word}\"?",
            "quiz_choices": {
                "A": meaning_en,
                "B": "A kind of fruit.",
                "C": "To move quickly.",
            },
            "quiz_answer": "A",
        }

    target_language = "English"
    native_language = "Chinese"
    if learning_direction == "en_to_zh":
        target_language = "Chinese"
        native_language = "English"
    elif learning_direction == "zh_to_en":
        target_language = "English"
        native_language = "Chinese"

    def target_only(text_en: str, text_zh: str) -> str:
        return text_zh if target_language == "Chinese" else text_en

    def bilingual(text_en: str, text_zh: str) -> str:
        if learning_direction == "en_to_zh":
            return f"{text_en}\n{text_zh}"
        if learning_direction == "zh_to_en":
            return f"{text_zh}\n{text_en}"
        return f"{text_en}\n{text_zh}"

    def both_languages(text_en: str, text_zh: str) -> str:
        return f"{text_en}\n{text_zh}"

    text_definition_en, text_definition_zh = meaning_en, meaning_zh
    text_example_en = f"I can use the word {word} today."
    text_example_zh = f"我今天可以使用 {word}。"
    text_quiz_en = f"What is the meaning of \"{word}\"?"
    text_quiz_zh = f"\"{word}\" 的意思是什么？"

    choices_en = {
        "A": text_definition_en,
        "B": "A kind of fruit.",
        "C": "To move quickly.",
    }
    choices_zh = {
        "A": text_definition_zh,
        "B": "一种水果。",
        "C": "快速移动。",
    }

    style = output_style or "immersion"
    if learning_direction == "both":
        definition = both_languages(text_definition_en, text_definition_zh)
        example = both_languages(text_example_en, text_example_zh)
        quiz_question = both_languages(text_quiz_en, text_quiz_zh)
        quiz_choices = {
            key: both_languages(choices_en[key], choices_zh[key])
            for key in choices_en
        }
    elif style == "bilingual":
        definition = bilingual(text_definition_en, text_definition_zh)
        example = bilingual(text_example_en, text_example_zh)
        quiz_question = bilingual(text_quiz_en, text_quiz_zh)
        quiz_choices = {
            key: bilingual(choices_en[key], choices_zh[key]) for key in choices_en
        }
    else:
        definition = target_only(text_definition_en, text_definition_zh)
        example = target_only(text_example_en, text_example_zh)
        quiz_question = target_only(text_quiz_en, text_quiz_zh)
        quiz_choices = {
            key: target_only(choices_en[key], choices_zh[key]) for key in choices_en
        }

    return {
        "definition": definition,
        "example_sentence": example,
        "quiz_question": quiz_question,
        "quiz_choices": quiz_choices,
        "quiz_answer": "A",
    }


def simple_comprehension_exercise(
    level: str = "beginner",
    learning_direction: str | None = None,
    output_style: str | None = None,
) -> dict:
    """Deterministic fallback comprehension exercise."""
    story_title_en = "The Brave Turtle"
    story_title_zh = "勇敢的小乌龟"
    story_lines = [
        (
            "Tina the turtle wanted to cross the garden.",
            "小乌龟蒂娜想穿过花园。",
        ),
        (
            "She moved slowly and safely.",
            "她慢慢又安全地移动。",
        ),
        (
            "A friendly bird cheered her on.",
            "一只友善的鸟为她加油。",
        ),
        (
            "Tina reached the pond and felt proud.",
            "蒂娜到了池塘，感到很自豪。",
        ),
    ]
    story_text_en = " ".join(line[0] for line in story_lines)
    story_text_zh = "".join(line[1] for line in story_lines)
    questions_en = [
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
    ]
    questions_zh = [
        {
            "question": "故事讲的是谁？",
            "choices": {"A": "小乌龟蒂娜", "B": "大狮子", "C": "快车"},
            "answer": "A",
        },
        {
            "question": "蒂娜想去哪里？",
            "choices": {"A": "池塘", "B": "月亮", "C": "城市"},
            "answer": "A",
        },
        {
            "question": "最后蒂娜感觉如何？",
            "choices": {"A": "自豪", "B": "生气", "C": "困了"},
            "answer": "A",
        },
    ]

    if not learning_direction:
        return {
            "story_title": story_title_en,
            "story_text": story_text_en,
            "image_description": "A small turtle walking through a sunny garden.",
            "questions": questions_en,
            "level": level,
        }

    target_language = "English"
    native_language = "Chinese"
    if learning_direction == "en_to_zh":
        target_language = "Chinese"
        native_language = "English"
    elif learning_direction == "zh_to_en":
        target_language = "English"
        native_language = "Chinese"

    def target_only(text_en: str, text_zh: str) -> str:
        return text_zh if target_language == "Chinese" else text_en

    def bilingual(text_en: str, text_zh: str) -> str:
        if learning_direction == "en_to_zh":
            return f"{text_en}\n{text_zh}"
        if learning_direction == "zh_to_en":
            return f"{text_zh}\n{text_en}"
        return f"{text_en}\n{text_zh}"

    def both_languages(text_en: str, text_zh: str) -> str:
        return f"{text_en}\n{text_zh}"

    def choose_questions() -> list[dict]:
        if learning_direction == "both":
            source_pairs = zip(questions_en, questions_zh)
            return [
                {
                    "question": both_languages(pair[0]["question"], pair[1]["question"]),
                    "choices": {
                        key: both_languages(pair[0]["choices"][key], pair[1]["choices"][key])
                        for key in pair[0]["choices"]
                    },
                    "answer": pair[0]["answer"],
                }
                for pair in source_pairs
            ]

        if (output_style or "immersion") == "bilingual":
            source_pairs = zip(questions_en, questions_zh)
            return [
                {
                    "question": bilingual(pair[0]["question"], pair[1]["question"]),
                    "choices": {
                        key: bilingual(pair[0]["choices"][key], pair[1]["choices"][key])
                        for key in pair[0]["choices"]
                    },
                    "answer": pair[0]["answer"],
                }
                for pair in source_pairs
            ]

        if target_language == "Chinese":
            return questions_zh
        return questions_en

    style = output_style or "immersion"
    if learning_direction == "both":
        story_title = both_languages(story_title_en, story_title_zh)
        story_text = both_languages(story_text_en, story_text_zh)
    elif style == "bilingual":
        story_title = bilingual(story_title_en, story_title_zh)
        story_text = bilingual(story_text_en, story_text_zh)
    else:
        story_title = target_only(story_title_en, story_title_zh)
        if level == "beginner":
            if target_language == "Chinese":
                story_text = "\n".join(line[1] for line in story_lines)
            else:
                story_text = "\n".join(line[0] for line in story_lines)
        else:
            story_text = target_only(story_text_en, story_text_zh)

    return {
        "story_title": story_title,
        "story_text": story_text,
        "image_description": "A small turtle walking through a sunny garden.",
        "questions": choose_questions(),
        "level": level,
    }
