# GoGoHannah Backend (FastAPI)

This backend powers the Flutter web app. It exposes vocab practice APIs first,
with pronunciation scoring as a follow-up step.

## Setup
1) Create and activate a virtual environment.
2) Install dependencies:
   - `pip install -r backend/requirements.txt`
3) Ensure `.env` includes:
   - `OPENAI_API_KEY=...`

Optional:
- `GOGOHANNAH_CORS_ORIGINS=http://localhost:5173`
- `GOGOHANNAH_DB_PATH=/absolute/path/to/progress.db`

## Run (local)
`uvicorn backend.app.main:app --reload`

## API (current milestone scope)
- `GET /healthz`
- `GET /v1/vocab/default`
- `POST /v1/vocab/exercise`
- `POST /v1/progress/exercise`
- `GET /v1/progress/summary`
- `GET /v1/progress/recommended`
- `POST /v1/pronunciation/score`
