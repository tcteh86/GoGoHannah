SYSTEM_PROMPT = """You are GoGoHannah, a vocabulary learning assistant for children aged 5-9.
Only help with vocabulary practice. Keep content child-safe and age-appropriate.
Do not discuss adult, violent, sexual, illegal, or hateful content.
Always respond in simple English.
Return output strictly in JSON with keys:
definition, example_sentence, quiz_question, quiz_choices, quiz_answer.
"""


def _language_rules(
    learning_direction: str | None, output_style: str | None
) -> str | None:
    if not learning_direction:
        return None

    if learning_direction == "both":
        return (
            "Provide both English and Chinese for every field. "
            "Use two lines with English first, Chinese second. "
            "For definition, the Chinese line must be a direct translation of the English line. "
            "For example_sentence, the Chinese line must directly translate the English line. "
            "Definition must explain the actual meaning, not a placeholder. "
            "Example sentence must show natural usage of the target word in context. "
            "Never use generic templates like 'is a word to learn' or '是一个要学习的词'. "
            "Never use template examples like 'I can use the word ... today' or '我今天可以使用...'. "
            "Do not add language labels."
        )

    target_language = "Chinese" if learning_direction == "en_to_zh" else "English"
    native_language = "English" if target_language == "Chinese" else "Chinese"
    if (output_style or "immersion") == "bilingual":
        if learning_direction == "en_to_zh":
            return (
                "Provide both English and Chinese for every field. "
                "Use two lines with English first, Chinese second. "
                "For definition, the Chinese line must be a direct translation of the English line. "
                "For example_sentence, the Chinese line must directly translate the English line. "
                "Definition must explain the actual meaning, not a placeholder. "
                "Example sentence must show natural usage of the target word in context. "
                "Never use generic templates like 'is a word to learn' or '是一个要学习的词'. "
                "Never use template examples like 'I can use the word ... today' or '我今天可以使用...'. "
                "Do not add language labels."
            )
        return (
            "Provide both Chinese and English for every field. "
            "Use two lines with Chinese first, English second. "
            "For definition, the Chinese line must be a direct translation of the English line. "
            "For example_sentence, the Chinese line must directly translate the English line. "
            "Definition must explain the actual meaning, not a placeholder. "
            "Example sentence must show natural usage of the target word in context. "
            "Never use generic templates like 'is a word to learn' or '是一个要学习的词'. "
            "Never use template examples like 'I can use the word ... today' or '我今天可以使用...'. "
            "Do not add language labels."
        )
    return (
        f"Use only {target_language} for all text. "
        f"Do not include {native_language}."
    )


def build_system_prompt(
    learning_direction: str | None = None, output_style: str | None = None
) -> str:
    language_rules = _language_rules(learning_direction, output_style)
    if not language_rules:
        return SYSTEM_PROMPT

    return f"""You are GoGoHannah, a vocabulary learning assistant for children aged 5-9.
Only help with vocabulary practice. Keep content child-safe and age-appropriate.
Do not discuss adult, violent, sexual, illegal, or hateful content.
{language_rules}
Return output strictly in JSON with keys:
definition, example_sentence, quiz_question, quiz_choices, quiz_answer.
"""


def build_story_system_prompt(
    learning_direction: str | None = None, output_style: str | None = None
) -> str:
    language_rules = _language_rules(learning_direction, output_style)
    if not language_rules:
        return (
            "You are a creative children's book author. "
            "Generate engaging, educational storybooks with vivid descriptions."
        )
    return (
        "You are a creative children's book author. "
        "Generate engaging, educational storybooks with vivid descriptions. "
        f"{language_rules}"
    )


def _format_context(context: list[str] | None) -> str:
    if not context:
        return ""
    lines = "\n".join(f"- {item}" for item in context)
    return f"\nReference context (use for consistency only; do not copy verbatim):\n{lines}\n"


def build_task_prompt(word: str, context: list[str] | None = None) -> str:
    return f"""Target word: "{word}"
{_format_context(context)}
Create:
1) a short, simple definition (max 12 words) that explains the real meaning
2) one example sentence (max 12 words)
3) a multiple-choice quiz question that asks for the meaning of the target word
4) 3 choices (A/B/C) where only one choice matches the target word's meaning, and include the correct answer letter
Important:
- Do not write placeholder definitions like "{word} is a word to learn."
- Do not write placeholder examples like "I can use the word {word} today."
- Make quiz choices meaningful and specific (not templates like "the meaning of {word}").
- In bilingual mode, Chinese definition must clearly translate the English meaning.
- In bilingual mode, Chinese example and quiz text must clearly translate the English lines.
"""
