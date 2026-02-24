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

Vocabulary:
- `GET /v1/vocab/default`
- `GET /v1/vocab/custom`
- `POST /v1/vocab/custom/add`
- `POST /v1/vocab/custom/suggest`
- `POST /v1/vocab/exercise`
- `POST /v1/vocab/image-hint`

Comprehension:
- `POST /v1/comprehension/exercise`

Progress:
- `POST /v1/progress/exercise`
- `GET /v1/progress/summary`
- `GET /v1/progress/daily`
- `GET /v1/progress/recent`
- `GET /v1/progress/recommended`
- `POST /v1/progress/time`
- `GET /v1/progress/time`
- `GET /v1/progress/time/total`
- `GET /v1/progress/time/summary`

Pronunciation:
- `POST /v1/pronunciation/score`
- `POST /v1/pronunciation/assess`

Debug:
- `GET /v1/debug/rag` (enabled only when debug flag is on)

### Vocab + story exercise request options
`POST /v1/vocab/exercise` and `POST /v1/comprehension/exercise` accept bilingual configuration. The current UI targets English → Chinese with bilingual output enabled.

```
{
  "word": "tree",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "bilingual"
}

{
  "level": "beginner",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "bilingual"
}
```

- `learning_direction` controls the target language.
- `output_style` is currently set to bilingual output in the UI.

### Comprehension response highlights
`POST /v1/comprehension/exercise` now returns richer story guidance fields:
- `story_blocks`: list of `{english, chinese}` chunked lines for early readers.
- `key_vocabulary`: list of `{word, meaning_en, meaning_zh}` support metadata.
- `questions[*].question_type`: `literal | vocabulary | inference`.
- `questions[*].explanation_en` / `questions[*].explanation_zh`: short feedback rationale.
- `questions[*].evidence_block_index`: clue link to a supporting story block.
- Story image generation is currently disabled in this branch; `image_url` is `null`.

### Vocabulary image hint endpoint
`POST /v1/vocab/image-hint` supports image hints for concrete words.

Response behavior:
- `image_hint_enabled=true` + `image_url` when image can be generated.
- `image_hint_enabled=false` + `image_hint_reason=abstract_word` for abstract words.

## Deploy (Render)
1) Create a new Web Service connected to the repo.
2) Build command:
   - `pip install -r backend/requirements.txt`
3) Start command:
   - `uvicorn backend.app.main:app --host 0.0.0.0 --port $PORT`
4) Environment variables:
   - `OPENAI_API_KEY=...`
   - `GOGOHANNAH_CORS_ORIGINS=https://YOUR-FIREBASE-URL`
