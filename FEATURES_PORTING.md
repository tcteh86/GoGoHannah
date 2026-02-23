# GoGoHannah - Implemented Features and Porting Notes

This document describes the implemented features and the core behaviors to port
to another framework. It reflects the current **Flutter + FastAPI** migration
and the existing backend modules.

## 1) Architecture Overview

UI layer:
- Flutter app (under `frontend/`) provides navigation and kid-friendly UI.

Core logic:
- `backend/app/core/exercise.py` provides a deterministic fallback exercise.
- `backend/app/core/scoring.py` evaluates answers and pronunciation similarity.
- `backend/app/core/safety.py` sanitizes vocabulary words.
- `backend/app/core/progress.py` persists and aggregates practice data.

LLM integration:
- `backend/app/llm/client.py` wraps OpenAI API usage.
- `backend/app/llm/prompts.py` defines the system prompt and task prompt.

Vocabulary data:
- `backend/app/vocab/default_vocab.csv` is the built-in vocabulary list.
- `backend/app/vocab/loader.py` loads default vocab and provides CSV parsing utilities.

## 2) Data Model and Persistence

SQLite database at `backend/data/progress.db` by default.
Initialized on import of `backend/app/core/progress.py`.

Tables:
- `children`
  - `id` (primary key)
  - `name` (unique)
  - `created_at`
- `exercises`
  - `id` (primary key)
  - `child_id` (foreign key to `children`)
  - `word`
  - `exercise_type` (examples: "quiz", "pronunciation", "comprehension", "test")
  - `score` (integer 0-100)
  - `correct` (boolean)
  - `created_at`
- `custom_vocab`
  - `id` (primary key)
  - `child_id` (foreign key to `children`)
  - `word`
  - `list_name` (optional)
  - `created_at`
  - unique key on (`child_id`, `word`)
- `study_time`
  - `id` (primary key)
  - `child_id` (foreign key to `children`)
  - `date` (ISO date)
  - `total_seconds`
  - `updated_at`
  - unique key on (`child_id`, `date`)

Key aggregation behaviors:
- Total exercises and accuracy for a child.
- Average score and count grouped by `exercise_type`.
- Weak words: average score under 70.
- Recent exercises ordered by timestamp.
- Daily completion history and streak metrics from `/v1/progress/daily`.

## 3) Feature Breakdown

### 3.1 Child identity gating
Flow:
- User must enter a child name before any practice starts.
- The name is inserted or retrieved from the `children` table.

Porting notes:
- Keep the "gate" behavior: block all other flows until a name is provided.

### 3.2 Vocabulary source selection
Sources:
- Default vocabulary list from `default_vocab.csv`.
- Custom vocabulary list saved per child via manual word entry.
- Recommended words from progress data.

Validation:
- Every word is sanitized by `sanitize_word`:
  - Allowed characters: letters, spaces, hyphen, apostrophe.
  - Length: 1-32 characters.

Porting notes:
- Preserve the same sanitization and dedupe behavior when saving custom words.
- CSV parsing utilities exist in backend helpers, but CSV upload is not wired into
  the current Flutter UI flow.

### 3.3 Vocabulary practice (definition + example + quiz)
Flow:
1) User selects a word from the vocabulary list.
2) On "Generate Exercise", the app requests a vocab exercise from the backend.
3) If LLM fails, fall back to `simple_exercise`.
4) Display learning content:
   - Definition (English shown first)
   - Example sentence (English shown first)
   - Chinese lines are revealed on demand (progressive reveal)
5) Display quick checks:
   - One rotating primary check type per generated exercise:
     - Meaning match
     - Context choice
     - Fill-in-the-blank
   - Plus two bidirectional checks:
     - EN → ZH meaning
     - ZH → EN meaning
6) On each check:
   - Show instructional feedback (correct EN/ZH meaning + wrong-choice explanation).
7) After all checks are completed:
   - Save one `quiz` exercise using aggregated score across checks.

LLM output requirements:
- JSON keys: `definition`, `example_sentence`, `quiz_question`,
  `quiz_choices` (A/B/C), `quiz_answer` (A/B/C).

Porting notes:
- The fallback behavior is required so the app still runs without the LLM.
- Keep the same scoring and data persistence format.
- Preserve progressive reveal for Chinese content to encourage active recall.
- Keep bidirectional EN/ZH checks in the same exercise flow for bilingual reinforcement.

### 3.4 Pronunciation practice (TTS + recording + scoring)
Flow:
1) Auto-play TTS for the word on first load.
2) Allow manual replay of TTS.
3) Record audio via microphone.
4) Transcribe with Whisper API.
5) Score pronunciation using fuzzy match similarity (0-100).
6) Save a `pronunciation` exercise with the score.

Fallback:
- If recording or transcription fails, the UI shows an error and prompts retry.
- `POST /v1/pronunciation/score` still exists, but the current web UI flow
  uses `POST /v1/pronunciation/assess` for audio assessment.

Porting notes:
- Keep "auto-play once, replay on demand" for pronunciation practice.
- Keep the same scoring threshold for "correct" (score >= 80).

### 3.5 Comprehension practice (story + questions + illustration)
Flow:
1) User selects a difficulty level:
   - beginner (100-150 words, very simple)
   - intermediate (200-250 words)
   - expert (250-350 words, advanced)
2) On "Generate New Story":
   - LLM returns JSON: title, story text, image description, 3 questions.
   - Optional image generation using DALL-E (URL stored in session).
   - TTS audio prepared for the story text.
3) User can click "Read Story Aloud" to play TTS.
4) The user answers 3 multiple-choice questions.
5) Each answer is saved as a `comprehension` exercise.

Porting notes:
- Preserve the 3-question requirement and answer key format.
- Story illustration is optional and should not block the story flow.

### 3.6 Progress summary and analytics
Displayed metrics:
- Study time (daily, total, weekly, monthly)
- Total exercises
- Overall accuracy
- Average quiz score
- Current streak and best streak (goal-based)

Recent activity:
- Table of recent exercises (word, type, score, correct, date).

Weak words:
- List of words with low scores (<70).

Daily history:
- Date-by-date completion against daily goal (recent window).

Porting notes:
- Current UI renders list-based analytics (metrics, weak words, recent practice);
  there is no practiced-words wheel visualization in this codebase.
- Streak is based on days where the daily goal is reached, not just any activity.

### 3.7 Smart recommendations
Algorithm:
1) Weak words: avg score <70 and attempts <3.
2) New words: words never practiced.
3) Exclude over-practiced words: attempts >= 5.
4) Return up to `limit` words.

Usage:
- Used in "Recommended for You" vocabulary mode.
- Used for "Smart Suggestions" and "Test & Check" candidate selection.

Porting notes:
- Keep the same prioritization order to match current behavior.

### 3.8 Test and Check (quick quiz)
Flow:
- Fetch up to 3 recommended words.
- Generate each question through the same vocab exercise API path
  (`/v1/vocab/exercise`), which is LLM-first with fallback.
- Saves each answer as `test` exercise.

Porting notes:
- Keep the recommended-word-first flow and `test` persistence behavior.

### 3.9 Record management status
Flow:
- Backend helper `clear_child_records` exists in `core/progress.py`.
- No user-facing delete endpoint is currently exposed in `main.py`.
- The current Flutter UI does not provide a delete-records action.

Porting notes:
- If deletion is added later, keep confirmation before irreversible actions.

## 4) LLM Integration Details

OpenAI usage:
- Model: `gpt-4o-mini` for vocab and comprehension.
- `response_format` set to JSON object.
- Strict validation is applied after parsing.
- Exceptions are wrapped in `LLMUnavailable`.

Audio and image:
- Transcription: Whisper (`whisper-1`) with a WAV byte stream.
- Image generation: DALL-E 3 with a child-friendly prompt.

API key loading:
- Environment variable `OPENAI_API_KEY`.

Porting notes:
- Keep the same JSON schema validation to avoid malformed content.
- Provide a stable fallback when the LLM is unavailable.

## 5) Tests and Debug Utilities

Tests:
- `tests/test_loader.py` verifies default vocab loads.
- `tests/test_scoring.py` verifies answer checking logic.

## 6) Porting Checklist (Implementation Parity)

- Recreate the three main screens:
  - Practice
  - Past Results
  - Test and Check
- Preserve data model and persistence, or migrate to an equivalent store.
- Keep word sanitization rules to avoid invalid input.
- Keep quiz and pronunciation scoring behavior.
- Preserve LLM prompt formats and JSON validation requirements.
- Implement both the LLM path and the deterministic fallback path.
