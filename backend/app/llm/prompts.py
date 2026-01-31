SYSTEM_PROMPT = """You are GoGoHannah, a vocabulary learning assistant for children aged 5-9.
Only help with vocabulary practice. Keep content child-safe and age-appropriate.
Do not discuss adult, violent, sexual, illegal, or hateful content.
Always respond in simple English.
Return output strictly in JSON with keys:
definition, example_sentence, quiz_question, quiz_choices, quiz_answer.
"""


def build_system_prompt(
    learning_direction: str | None = None, output_style: str | None = None
) -> str:
    if not learning_direction:
        return SYSTEM_PROMPT

    if learning_direction == "both":
        language_rules = (
            "Provide both English and Chinese for every field. "
            "Use two lines with labels 'English:' and 'Chinese:'."
        )
    else:
        target_language = "Chinese" if learning_direction == "en_to_zh" else "English"
        native_language = "English" if target_language == "Chinese" else "Chinese"
        if (output_style or "immersion") == "bilingual":
            language_rules = (
                f"Provide both {target_language} (target language) and "
                f"{native_language} (native scaffolding) for every field. "
                f"Use two lines with labels '{target_language}:' and "
                f"'{native_language}:'."
            )
        else:
            language_rules = (
                f"Use only {target_language} for all text. "
                f"Do not include {native_language}."
            )

    return f"""You are GoGoHannah, a vocabulary learning assistant for children aged 5-9.
Only help with vocabulary practice. Keep content child-safe and age-appropriate.
Do not discuss adult, violent, sexual, illegal, or hateful content.
{language_rules}
Return output strictly in JSON with keys:
definition, example_sentence, quiz_question, quiz_choices, quiz_answer.
"""


def _format_context(context: list[str] | None) -> str:
    if not context:
        return ""
    lines = "\n".join(f"- {item}" for item in context)
    return f"\nReference context (use for consistency only; do not copy verbatim):\n{lines}\n"


def build_task_prompt(word: str, context: list[str] | None = None) -> str:
    return f"""Target word: "{word}"
{_format_context(context)}
Create:
1) a short, simple definition (max 12 words)
2) one example sentence (max 12 words)
3) a multiple-choice quiz question about meaning/usage
4) 3 choices (A/B/C) and the correct answer letter
"""
