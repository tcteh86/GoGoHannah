# GoGoHannah 📚✨

A prototype AI-based English vocabulary learning assistant for young learners (5–9).

This repository is migrating to a **Flutter (web) + FastAPI** architecture that
prioritizes a child-friendly UI and a clear GenAI backend. The goal is to keep
the learning experience engaging while showcasing GenAI techniques.

## Features (MVP)
- Default primary-level vocabulary list
- Optional vocabulary via custom word list entry
- Practice output: AI-generated definition + example sentence + multiple-choice quiz
- Bilingual vocab + story practice (English ↔ Chinese) with immersion/bilingual output styles
- Pronunciation practice with auto-play TTS, audio recording, transcription, and scoring
- Progress tracking with personalized recommendations and detailed analytics
- Practiced words wheel visualization with performance indicators
- Smart word recommendation system (prioritizes weak words, avoids over-practice)
- Record management with secure deletion
- Clean project boundaries: UI vs core logic vs LLM wrapper

## Tech Stack
- Flutter (web first, Android later)
- FastAPI (Python backend)
- OpenAI API (text, audio, image)

## Quickstart (Local)

### 1) Backend setup (FastAPI)
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
```

Set up `.env`:
```
OPENAI_API_KEY=your_openai_api_key_here
```

Run the API:
```bash
uvicorn backend.app.main:app --reload
```

### Bilingual vocab + story options
<<<<<<< codex/add-bilingual-support-for-english-and-chinese-y6tmvf
The vocab and story exercise endpoints support optional bilingual configuration.
The current UI defaults to English → Chinese with selectable output style.
=======
The vocab and story exercise endpoints support optional bilingual configuration:
>>>>>>> main

```
POST /v1/vocab/exercise
{
  "word": "tree",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "bilingual"       // immersion | bilingual
}

POST /v1/comprehension/exercise
{
  "level": "beginner",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "bilingual"       // immersion | bilingual
}
```

- `learning_direction` sets the target language direction.
- `output_style` controls full immersion (target only) vs bilingual scaffolding.

### 2) Frontend setup (Flutter)
From `frontend/`:
- `flutter create . --platforms=web,android`
- `flutter run -d chrome --dart-define API_BASE_URL=http://localhost:8000`

## Roadmap
- ✅ Backend API scaffold with OpenAI integration (vocab exercises)
- ✅ Progress tracking endpoints
- ✅ Flutter web UI (practice, results, quick check)
- ✅ Pronunciation (audio + transcription)
- ✅ Comprehension stories + illustration
- ⏳ RAG + embeddings + multi-agent workflow

## Notes on GenAI Safety (future)
When you add GenAI:
- enforce strict JSON schema output
- validate output types and length
- sanitize user-provided vocab words (length/character whitelist)
- block disallowed topics for child-safe learning
