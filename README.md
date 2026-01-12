# GoGoHannah 📚✨

A prototype AI-based English vocabulary learning assistant for young learners (5–9).

This repository contains a working **Streamlit MVP** that:
- loads a default vocabulary list (or a parent-provided CSV)
- runs a simple practice flow (definition, example sentence, quiz)
- is structured so you can later add a bounded GenAI provider (e.g., Gemini) safely.

## Features (MVP)
- Default primary-level vocabulary list
- Optional vocabulary via CSV upload (must contain a `word` column)
- Practice output: definition + example + multiple-choice quiz
- Clean project boundaries: UI vs core logic vs LLM wrapper

## Tech Stack
- Python
- Streamlit

## Quickstart (Local)

### 1) Create and activate venv
```bash
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate
```

### 2) Install dependencies
```bash
pip install -r requirements.txt
```

### 3) Run the app
```bash
streamlit run app/main.py
```

## CSV Format
Your CSV must contain a column named `word`.

```csv
word
happy
brave
gentle
```

## Roadmap
- Add Gemini integration for AI-generated definition/example/quiz (JSON-only output)
- Add progress tracking (local file or SQLite)
- Add more guardrails + output validation
- Add tests for parsing/validation

## Notes on GenAI Safety (future)
When you add GenAI:
- enforce strict JSON schema output
- validate output types and length
- sanitize user-provided vocab words (length/character whitelist)
- block disallowed topics for child-safe learning
