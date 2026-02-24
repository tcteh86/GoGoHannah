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
1) UI shows a mission-style 3-step flow card:
   - Step 1 choose list
   - Step 2 pick word
   - Step 3 generate + finish quiz
   with a live progress indicator.
2) User chooses a word source using horizontal carousel buttons
   (Default/Custom/Weak) and selects a word from horizontal scrollable chips.
3) On "Generate Exercise", the app requests a vocab exercise from the backend.
4) If LLM fails, fall back to `simple_exercise`.
5) Display learning content:
   - Definition (English shown first)
   - Example sentence (English shown first)
   - Chinese lines are revealed on demand (progressive reveal)
6) Display one focused quiz:
   - Meaning-match multiple choice from backend (`quiz_question`, `quiz_choices`).
7) On quiz submit:
   - Show instructional feedback (correct EN/ZH meaning + wrong-choice explanation).
8) Optional image hint:
   - "Generate Image Hint" button is enabled only for visualizable words.
   - Abstract words are flagged and keep the button disabled.
   - On click, backend generates and returns an image hint URL.
9) After quiz is completed:
   - Save one `quiz` exercise.
   - Trigger a short reward banner/animation to reinforce completion.

LLM output requirements:
- JSON keys: `definition`, `example_sentence`, `quiz_question`,
  `quiz_choices` (A/B/C), `quiz_answer` (A/B/C).

Porting notes:
- The fallback behavior is required so the app still runs without the LLM.
- Keep the same scoring and data persistence format.
- Keep child-friendly source/word selectors (carousel + chips) rather than dropdowns.
- Keep the mission-style step cards and progress indicator in the vocab flow.
- Keep mission-step labels responsive on narrow/mobile screens (wrap layout + 2-line labels, no truncation).
- Preserve progressive reveal for Chinese content to encourage active recall.
- Keep the vocabulary-session quiz focused on one meaning-match question.
- Enforce definition quality rules: avoid generic placeholder definitions and repair
  missing/templated Chinese definition lines from LLM output.
- Enforce example/quiz quality rules: avoid template example sentences and generic
  quiz-choice placeholders; repair missing/template Chinese lines when needed.

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

### 3.5 Comprehension practice (story + questions)
Flow:
1) User selects a difficulty level:
   - beginner (50-90 words, very simple)
   - intermediate (140-200 words)
   - expert (220-300 words, advanced)
2) On "Generate New Story":
   - LLM returns JSON with:
     - title
     - story blocks (`english`, `chinese`) for chunked reading
     - optional combined `story_text`
     - key vocabulary list (`word`, `meaning_en`, `meaning_zh`) as optional support metadata
     - image description (metadata only; no story image generation in current UI)
     - 3 questions with `question_type`, `explanation_en`, `explanation_zh`,
       and `evidence_block_index`
   - TTS audio prepared from story text for read-aloud.
3) User can click "Read Story Aloud" to play TTS.
4) Story UI uses English-first chunked blocks with optional Chinese reveal
   (per-block and reveal-all controls).
5) The user answers 3 scaffolded questions:
   - Q1 literal
   - Q2 vocabulary-in-context
   - Q3 inference
   If incorrect, the UI can highlight a clue block using `evidence_block_index`.
6) Explanatory feedback is shown after each check in EN + ZH.
7) Each answer is saved as a `comprehension` exercise.

Porting notes:
- Preserve the 3-question requirement and answer key format.
- Keep story blocks as paired EN/ZH lines to support chunked progressive reveal.
- Keep evidence-linked feedback fields (`explanation_*`, `evidence_block_index`) for guided remediation.

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
- Used for "Smart Suggestions" and "Quiz" candidate selection.

Porting notes:
- Keep the same prioritization order to match current behavior.

### 3.8 Quiz (recommended words)
Flow:
- Fetch up to 3 recommended words.
- Generate each question through the same vocab exercise API path
  (`/v1/vocab/exercise`), which is LLM-first with fallback.
- Request bilingual exercise output (`en_to_zh` + `bilingual`) and render EN first
  with optional Chinese support in the UI.
- Saves each answer as `quiz` exercise.

Porting notes:
- Keep the recommended-word-first flow and bilingual quiz rendering.

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
  - Quiz
- Preserve data model and persistence, or migrate to an equivalent store.
- Keep word sanitization rules to avoid invalid input.
- Keep quiz and pronunciation scoring behavior.
- Preserve LLM prompt formats and JSON validation requirements.
- Implement both the LLM path and the deterministic fallback path.
