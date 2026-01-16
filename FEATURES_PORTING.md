# GoGoHannah - Implemented Features and Porting Notes

This document describes the implemented features and the core behaviors to port
to another framework. It is based on the current code in `app/` and tests.

## 1) Architecture Overview

UI layer:
- `app/main.py` is the Streamlit entry point and orchestrates all user flows.
- It owns UI state (session state), navigation, and input/output rendering.

Core logic:
- `app/core/exercise.py` provides a deterministic fallback exercise.
- `app/core/scoring.py` evaluates answers and pronunciation similarity.
- `app/core/safety.py` sanitizes vocabulary words.
- `app/core/progress.py` persists and aggregates practice data.

LLM integration:
- `app/llm/client.py` wraps OpenAI API usage.
- `app/llm/prompts.py` defines the system prompt and task prompt.

Vocabulary data:
- `app/vocab/default_vocab.csv` is the built-in vocabulary list.
- `app/vocab/loader.py` loads default or uploaded CSV vocab lists.

## 2) Data Model and Persistence

SQLite database at `progress.db` (relative to repository root).
Initialized on import of `app/core/progress.py`.

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

Key aggregation behaviors:
- Total exercises and accuracy for a child.
- Average score and count grouped by `exercise_type`.
- Weak words: average score under 70.
- Recent exercises ordered by timestamp.

## 3) Feature Breakdown

### 3.1 Child identity gating
Flow:
- User must enter a child name before any practice starts.
- The name is inserted or retrieved from the `children` table.

Porting notes:
- Replace the Streamlit sidebar input with an equivalent UI field.
- Keep the "gate" behavior: block all other flows until a name is provided.

### 3.2 Vocabulary source selection
Sources:
- Default vocabulary list from `default_vocab.csv`.
- Uploaded CSV that must contain a `word` column.
- Recommended words from progress data.

Validation:
- Every word is sanitized by `sanitize_word`:
  - Allowed characters: letters, spaces, hyphen, apostrophe.
  - Length: 1-32 characters.

Porting notes:
- Preserve the same CSV validation and sanitization rules to avoid regressions.

### 3.3 Vocabulary practice (definition + example + quiz)
Flow:
1) User selects a word from the vocabulary list.
2) On "Start Practice", the app requests an LLM exercise.
3) If LLM fails, fall back to `simple_exercise`.
4) Display:
   - Definition
   - Example sentence
   - Multiple-choice quiz (A/B/C)
5) On "Check Answer":
   - `check_answer` is case-insensitive.
   - Save a `quiz` exercise with score 100 or 0.

LLM output requirements:
- JSON keys: `definition`, `example_sentence`, `quiz_question`,
  `quiz_choices` (A/B/C), `quiz_answer` (A/B/C).

Porting notes:
- The fallback behavior is required so the app still runs without the LLM.
- Keep the same scoring and data persistence format.

### 3.4 Pronunciation practice (TTS + recording + scoring)
Flow:
1) Auto-play TTS for the word on first load.
2) Allow manual replay of TTS.
3) Record audio via microphone.
4) Transcribe with Whisper API.
5) Score pronunciation using fuzzy match similarity (0-100).
6) Save a `pronunciation` exercise with the score.

Fallback:
- If transcription fails, user can type their pronunciation.
- Text input is scored the same way and still saved.

Porting notes:
- You can replace `gTTS` with another TTS provider,
  but keep "auto-play once, replay on demand".
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
- Total exercises
- Overall accuracy
- Average quiz score

Recent activity:
- Table of recent exercises (word, type, score, correct, date).

Weak words:
- List of words with low scores (<70).

Practiced words wheel:
- Most recently practiced words with avg score and attempt count.
- UI shows only the first 5 in the wheel display.

Porting notes:
- The "wheel" is purely presentational. Recreate the same data
  and apply your own visualization.

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
- Generate a 3-question quiz from recommended words plus defaults.
- Uses `simple_exercise` for all questions (no LLM).
- Saves each answer as `test` exercise.

Porting notes:
- Keep `simple_exercise` behavior so quick checks are deterministic.

### 3.9 Record management
Flow:
- User can delete all records.
- This deletes both `exercises` and the `children` row.

Porting notes:
- Keep a confirmation step before deletion.
- The delete operation is irreversible in the current app.

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
- Streamlit secrets fallback.

Porting notes:
- Keep the same JSON schema validation to avoid malformed content.
- Provide a stable fallback when the LLM is unavailable.

## 5) Tests and Debug Utilities

Tests:
- `tests/test_loader.py` verifies default vocab loads.
- `tests/test_scoring.py` verifies answer checking logic.

Debug helper:
- `debug_llm.py` exercises `generate_vocab_exercise`.

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
