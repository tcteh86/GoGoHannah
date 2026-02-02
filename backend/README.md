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
- `POST /v1/comprehension/exercise`
- `POST /v1/progress/exercise`
- `GET /v1/progress/summary`
- `GET /v1/progress/recommended`
- `POST /v1/pronunciation/score`
- `POST /v1/pronunciation/assess`

### Vocab + story exercise request options
`POST /v1/vocab/exercise` and `POST /v1/comprehension/exercise` accept optional bilingual configuration. The current UI targets English → Chinese and lets users pick immersion vs bilingual output.

```
{
  "word": "tree",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "immersion"       // immersion | bilingual
}

{
  "level": "beginner",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "immersion"       // immersion | bilingual
}
```

- `learning_direction` controls the target language.
- `output_style` toggles full immersion vs bilingual scaffolding.

## Deploy (Render)
1) Create a new Web Service connected to the repo.
2) Build command:
   - `pip install -r backend/requirements.txt`
3) Start command:
   - `uvicorn backend.app.main:app --host 0.0.0.0 --port $PORT`
4) Environment variables:
   - `OPENAI_API_KEY=...`
   - `GOGOHANNAH_CORS_ORIGINS=https://YOUR-FIREBASE-URL`
