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

_FALLBACK_EXAMPLES = {
    "happy": ("I felt happy when my friend smiled.", "朋友微笑时，我感到很开心。"),
    "sad": ("She looked sad after losing her toy.", "弄丢玩具后，她看起来很难过。"),
    "brave": ("The brave boy spoke on stage.", "这个勇敢的男孩在台上发言。"),
    "gentle": ("Please be gentle with the kitten.", "请温柔地对待小猫。"),
    "kind": ("My teacher is kind to everyone.", "我的老师对每个人都很友善。"),
    "strong": ("The strong girl carried the bag.", "这个强壮的女孩提起了包。"),
    "clever": ("A clever answer solved the puzzle.", "聪明的回答解开了谜题。"),
    "friendly": ("The new student was very friendly.", "新同学非常友好。"),
    "excited": ("We were excited about the school trip.", "我们对学校旅行很兴奋。"),
    "angry": ("He felt angry when the game ended.", "游戏结束时，他感到生气。"),
    "calm": ("Take a deep breath and stay calm.", "深呼吸，保持冷静。"),
    "funny": ("That funny story made us laugh.", "那个有趣的故事让我们大笑。"),
    "shy": ("The shy child spoke softly.", "害羞的孩子轻声说话。"),
    "loud": ("The loud bell rang at noon.", "中午时，响亮的铃声响起。"),
    "quiet": ("The library is quiet after class.", "下课后图书馆很安静。"),
    "fast": ("The rabbit ran very fast.", "兔子跑得很快。"),
    "slow": ("The turtle walked very slow.", "乌龟走得很慢。"),
    "big": ("They built a big sandcastle.", "他们堆了一座大沙堡。"),
    "small": ("I found a small shell on the beach.", "我在海边找到一个小贝壳。"),
    "hot": ("The soup is hot, so blow first.", "汤很烫，要先吹一吹。"),
    "cold": ("The cold water made my hands shake.", "冷水让我的手发抖。"),
    "safe": ("Wear a helmet to stay safe.", "戴上头盔会更安全。"),
    "dangerous": ("Running on wet stairs is dangerous.", "在湿楼梯上跑很危险。"),
}

_DISTRACTOR_POOL = [
    ("about food taste", "和食物味道有关"),
    ("about size, big or small", "和大小有关"),
    ("about sound, loud or quiet", "和声音大小有关"),
    ("about temperature, hot or cold", "和冷热有关"),
    ("about moving speed", "和移动速度有关"),
    ("about a place to play", "和玩耍的地点有关"),
]


def _fallback_definition(word: str) -> tuple[str, str]:
    meaning = _FALLBACK_MEANINGS.get(word.lower())
    if meaning:
        return meaning
    return (
        f'"{word}" has a specific meaning used in daily life.',
        f'“{word}” 在日常生活中有具体含义。',
    )


def _fallback_example(word: str) -> tuple[str, str]:
    example = _FALLBACK_EXAMPLES.get(word.lower())
    if example:
        return example
    return (
        f'The teacher explained "{word}" with a simple sentence.',
        f'老师用一个简单句子解释了“{word}”。',
    )


def _fallback_distractors(word: str) -> tuple[tuple[str, str], tuple[str, str]]:
    seed = sum(ord(ch) for ch in word.lower())
    first = seed % len(_DISTRACTOR_POOL)
    second = (first + 2) % len(_DISTRACTOR_POOL)
    if second == first:
        second = (first + 1) % len(_DISTRACTOR_POOL)
    return _DISTRACTOR_POOL[first], _DISTRACTOR_POOL[second]


def simple_exercise(
    word: str,
    learning_direction: str | None = None,
    output_style: str | None = None,
) -> dict:
    """Deterministic fallback exercise so the app works without an LLM."""
    meaning_en, meaning_zh = _fallback_definition(word)
    example_en, example_zh = _fallback_example(word)
    distractor_one, distractor_two = _fallback_distractors(word)
    if not learning_direction:
        return {
            "definition": meaning_en,
            "example_sentence": example_en,
            "quiz_question": f'Which meaning best matches "{word}"?',
            "quiz_choices": {
                "A": meaning_en,
                "B": distractor_one[0],
                "C": distractor_two[0],
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
    text_example_en, text_example_zh = example_en, example_zh
    text_quiz_en = f'Which meaning best matches "{word}"?'
    text_quiz_zh = f'下面哪一个最符合“{word}”的意思？'

    choices_en = {
        "A": text_definition_en,
        "B": distractor_one[0],
        "C": distractor_two[0],
    }
    choices_zh = {
        "A": text_definition_zh,
        "B": distractor_one[1],
        "C": distractor_two[1],
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
    story_blocks = [
        {"english": line_en, "chinese": line_zh} for (line_en, line_zh) in story_lines
    ]
    key_vocabulary = [
        {
            "word": "brave",
            "meaning_en": "showing courage when something feels hard",
            "meaning_zh": "在困难时表现出勇气",
        },
        {
            "word": "slowly",
            "meaning_en": "moving at a low speed",
            "meaning_zh": "慢慢地移动",
        },
        {
            "word": "proud",
            "meaning_en": "feeling happy about doing something well",
            "meaning_zh": "因做得好而感到自豪",
        },
    ]
    questions_en = [
        {
            "question": "Who is the story about?",
            "choices": {"A": "Tina the turtle", "B": "A big lion", "C": "A fast car"},
            "answer": "A",
            "question_type": "literal",
            "explanation_en": "The first line says Tina the turtle is the main character.",
            "explanation_zh": "第一句写到主角是小乌龟蒂娜。",
            "evidence_block_index": 0,
        },
        {
            "question": "Which word best describes how Tina moved?",
            "choices": {"A": "Slowly", "B": "Loudly", "C": "Angrily"},
            "answer": "A",
            "question_type": "vocabulary",
            "explanation_en": "The story says she moved slowly and safely.",
            "explanation_zh": "故事写到她慢慢又安全地移动。",
            "evidence_block_index": 1,
        },
        {
            "question": "Why did Tina feel proud at the end?",
            "choices": {
                "A": "She reached the pond after trying hard",
                "B": "She found a new toy",
                "C": "She slept all day",
            },
            "answer": "A",
            "question_type": "inference",
            "explanation_en": "Tina kept going and reached her goal, so she felt proud.",
            "explanation_zh": "蒂娜坚持到达目标，所以她感到自豪。",
            "evidence_block_index": 3,
        },
    ]
    questions_zh = [
        {
            "question": "故事讲的是谁？",
            "choices": {"A": "小乌龟蒂娜", "B": "大狮子", "C": "快车"},
            "answer": "A",
            "question_type": "literal",
            "explanation_en": "The first line says Tina the turtle is the main character.",
            "explanation_zh": "第一句写到主角是小乌龟蒂娜。",
            "evidence_block_index": 0,
        },
        {
            "question": "哪个词最能描述蒂娜如何移动？",
            "choices": {"A": "慢慢地", "B": "大声地", "C": "生气地"},
            "answer": "A",
            "question_type": "vocabulary",
            "explanation_en": "The story says she moved slowly and safely.",
            "explanation_zh": "故事写到她慢慢又安全地移动。",
            "evidence_block_index": 1,
        },
        {
            "question": "为什么蒂娜最后感到自豪？",
            "choices": {"A": "她努力后到达池塘", "B": "她找到新玩具", "C": "她睡了一整天"},
            "answer": "A",
            "question_type": "inference",
            "explanation_en": "Tina kept going and reached her goal, so she felt proud.",
            "explanation_zh": "蒂娜坚持到达目标，所以她感到自豪。",
            "evidence_block_index": 3,
        },
    ]

    if not learning_direction:
        return {
            "story_title": story_title_en,
            "story_text": story_text_en,
            "image_description": "A small turtle walking through a sunny garden.",
            "questions": questions_en,
            "story_blocks": story_blocks,
            "key_vocabulary": key_vocabulary,
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
                    "question_type": pair[0]["question_type"],
                    "explanation_en": pair[0]["explanation_en"],
                    "explanation_zh": pair[0]["explanation_zh"],
                    "evidence_block_index": pair[0]["evidence_block_index"],
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
                    "question_type": pair[0]["question_type"],
                    "explanation_en": pair[0]["explanation_en"],
                    "explanation_zh": pair[0]["explanation_zh"],
                    "evidence_block_index": pair[0]["evidence_block_index"],
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

    story_text_lines = []
    for block in story_blocks:
        if style == "bilingual" or learning_direction == "both":
            if learning_direction == "zh_to_en":
                story_text_lines.extend([block["chinese"], block["english"]])
            else:
                story_text_lines.extend([block["english"], block["chinese"]])
        elif target_language == "Chinese":
            story_text_lines.append(block["chinese"])
        else:
            story_text_lines.append(block["english"])

    return {
        "story_title": story_title,
        "story_text": "\n".join(line for line in story_text_lines if line.strip()),
        "image_description": "A small turtle walking through a sunny garden.",
        "questions": choose_questions(),
        "story_blocks": story_blocks,
        "key_vocabulary": key_vocabulary,
        "level": level,
    }
