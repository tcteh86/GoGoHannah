def simple_exercise(
    word: str,
    learning_direction: str | None = None,
    output_style: str | None = None,
) -> dict:
    """Deterministic fallback exercise so the app works without an LLM."""
    if not learning_direction:
        return {
            "definition": f"\"{word}\" is a word to learn.",
            "example_sentence": f"I can use the word {word} today.",
            "quiz_question": "Which word are we learning now?",
            "quiz_choices": {"A": word, "B": "apple", "C": "run"},
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
        target_text = text_zh if target_language == "Chinese" else text_en
        native_text = text_en if native_language == "English" else text_zh
        return f"{target_language}: {target_text}\n{native_language}: {native_text}"

    def both_languages(text_en: str, text_zh: str) -> str:
        return f"English: {text_en}\nChinese: {text_zh}"

    text_definition_en = f"\"{word}\" is a word to learn."
    text_definition_zh = f"“{word}” 是一个要学习的词。"
    text_example_en = f"I can use the word {word} today."
    text_example_zh = f"我今天可以使用 {word}。"
    text_quiz_en = "Which word are we learning now?"
    text_quiz_zh = "我们现在在学习哪个词？"

    choices_en = {"A": word, "B": "apple", "C": "run"}
    choices_zh = {"A": word, "B": "苹果", "C": "跑"}

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
    story_text_en = (
        "Tina the turtle wanted to cross the garden. "
        "She moved slowly and safely. "
        "A friendly bird cheered her on. "
        "Tina reached the pond and felt proud."
    )
    story_text_zh = (
        "小乌龟蒂娜想穿过花园。"
        "她慢慢又安全地移动。"
        "一只友善的鸟为她加油。"
        "蒂娜到了池塘，感到很自豪。"
    )
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
        target_text = text_zh if target_language == "Chinese" else text_en
        native_text = text_en if native_language == "English" else text_zh
        return f"{target_language}: {target_text}\n{native_language}: {native_text}"

    def both_languages(text_en: str, text_zh: str) -> str:
        return f"English: {text_en}\nChinese: {text_zh}"

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
        story_text = target_only(story_text_en, story_text_zh)

    return {
        "story_title": story_title,
        "story_text": story_text,
        "image_description": "A small turtle walking through a sunny garden.",
        "questions": choose_questions(),
        "level": level,
    }
