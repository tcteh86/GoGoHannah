# GoGoHannah 📚✨

A prototype AI-based English vocabulary learning assistant for young learners (5–9).

This repository is migrating to a **Flutter (web) + FastAPI** architecture that
prioritizes a child-friendly UI and a clear GenAI backend. The goal is to keep
the learning experience engaging while showcasing GenAI techniques.

## Features (MVP)
- Default primary-level vocabulary list
- Optional vocabulary via custom word list entry
- Practice output with progressive bilingual reveal (English first, Chinese on demand)
- Instructional feedback that shows correct EN/ZH meaning and explains wrong choices
- Rotating vocabulary checks (meaning match, context choice, fill-in-the-blank) plus EN↔ZH meaning checks
- Definition quality guardrails to avoid template Chinese meanings in generated exercises
- Bilingual vocab + story practice (English ↔ Chinese) with bilingual output
- Pronunciation practice with auto-play TTS, audio recording, transcription, and scoring
- Progress tracking with personalized recommendations, weak-word insights, and recent practice history
- Study time tracking (daily, weekly/monthly, and total summaries)
- Persistent streak tracking based on daily-goal completion, with daily history
- Smart word recommendation system (prioritizes weak words, avoids over-practice)
- Custom vocabulary management with typo suggestions (manual entry)
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
The vocab and story exercise endpoints support bilingual configuration.
The current UI defaults to bilingual English → Chinese output.

```
POST /v1/vocab/exercise
{
  "word": "tree",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "bilingual"
}

POST /v1/comprehension/exercise
{
  "level": "beginner",
  "learning_direction": "en_to_zh", // en_to_zh | zh_to_en | both
  "output_style": "bilingual"
}
```

- `learning_direction` sets the target language direction.
- `output_style` is currently set to bilingual output in the UI.

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
