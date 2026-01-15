# GoGoHannah FastAPI Backend

Endpoints are defined in `backend/app.py` and reuse core logic from `app/core` and `app/llm`.

## Quick start (local)
```
pip install -r requirements.txt
uvicorn backend.app:app --reload --port 8000
```

## Endpoints
- `GET /health`
- `GET /vocab/default`
- `POST /exercise/generate`
- `POST /exercise/check`
- `POST /pronunciation/score`
- `POST /comprehension/generate`
- `GET /progress/{child_name}`

Planned: vocab upload, pronunciation transcription (Whisper), auth/CORS configuration.
