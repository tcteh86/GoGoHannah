# GoGoHannah (React + FastAPI backend)

A prototype AI-based English vocabulary and comprehension assistant for young learners (5-9). Core logic lives in Python; a React/Next.js frontend will consume the FastAPI API.

## Current stack
- Backend: FastAPI (`backend/app.py`) reusing `app/core` (safety, scoring, progress) and `app/llm` (OpenAI).
- Data: Default vocab CSV (`app/vocab/default_vocab.csv`), optional CSV upload, SQLite (`progress.db`).
- LLM: OpenAI (gpt-4o-mini for vocab/comprehension, DALL-E 3 for images, Whisper-1 for transcription).

## Run the backend
```bash
python -m venv .venv
.venv\Scripts\activate  # or source .venv/bin/activate
pip install -r requirements.txt
uvicorn backend.app:app --reload --port 8000
```

## Key endpoints
- `GET /health`
- `GET /vocab/default`
- `POST /vocab/upload` (CSV)
- `POST /exercise/generate`
- `POST /exercise/check`
- `POST /pronunciation/score`
- `POST /pronunciation/transcribe` (audio -> text)
- `POST /comprehension/generate`
- `GET /progress/{child_name}`
- `GET /quick-check`
- `GET /ui` (temporary HTML UI for vocab/comprehension/quick-check)

## Frontend (planned)
- React/Next.js client (TypeScript) to consume the API for vocab practice, comprehension, pronunciation, and progress dashboards.
- Configure API base (e.g., `NEXT_PUBLIC_API_BASE=http://localhost:8000`).

## Tests
```bash
pytest
```
