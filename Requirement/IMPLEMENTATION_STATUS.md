# Implementation Status (Living Document)

Last updated: 24 Feb 2026

This document captures what is implemented, what is pending, and known
issues so a new agent can continue work if the session ends.

---

## 1) Implemented (Backend)
- FastAPI service with health and vocab endpoints.
- Vocab exercise generation (LLM + fallback) with phonics hints.
- Vocab definition quality guard:
  - Reject/retry template definitions in LLM generation.
  - Repair missing/template Chinese definition lines using translation fallback.
- Vocab example and quiz quality guard:
  - Reject/retry template examples and low-quality quiz choices in LLM generation.
  - Repair template/missing Chinese example and quiz lines using translation fallback.
- Bilingual vocab options for English ↔ Chinese (learning direction + output style).
- Progress save + summary + recommended words.
- Daily progress endpoint with persistent streak and goal-based history (`/v1/progress/daily`).
- Study time tracking endpoints (daily, total, weekly/monthly summaries).
- Recent practice endpoint (recent exercises history).
- Comprehension story generation with level selection, chunked EN/ZH story blocks,
  and scaffolded question metadata (type/explanations/evidence block).
- Vocab image hint endpoint with abstract-word gating (`/v1/vocab/image-hint`).
- Pronunciation scoring:
  - Text similarity scoring endpoint.
  - Audio upload endpoint (Whisper transcription + scoring).
- SQLite persistence for children + exercises.
- Custom vocab storage + manual list endpoints.
- Custom vocab typo suggestions endpoint (LLM spelling corrections).
- Progress data portability endpoints:
  - `GET /v1/progress/db-export` (SQLite backup download).
  - `POST /v1/progress/db-import` (SQLite backup restore with atomic file replace).
  - Optional shared-token guard via `GOGOHANNAH_DB_EXPORT_TOKEN` + `X-DB-Export-Token`.
- Human-readable progress report export endpoint:
  - `GET /v1/progress/report.csv` (summary metrics + recent exercise rows).
- Custom vocabulary CSV portability endpoints:
  - `GET /v1/vocab/custom/export`
  - `POST /v1/vocab/custom/import` (`append`/`replace`).
- RAG scaffolding (documents + embeddings tables, retrieval utilities, prompt
  context injection) gated by `GOGOHANNAH_RAG_ENABLED`.

## 2) Implemented (Frontend)
- Flutter web UI:
  - Practice screen with vocab + comprehension modes.
  - Vocab + story bilingual output (English → Chinese).
  - Generate Exercise vocabulary UX:
    - Mission-style 3-step cards (choose list, pick word, generate/complete).
    - Live mission progress tracker across the 3 steps.
    - Responsive mobile mission chips (wrap layout + multi-line labels).
    - Progressive reveal for Chinese meaning/example lines in dedicated Definition/Example bilingual cards.
    - Single meaning-match quiz per generated exercise.
    - Quiz prompt label updated from "Check {n}" to "Type {n}" in vocab mission checks.
    - Instructional feedback with correct meaning and wrong-choice explanation.
    - Mini completion celebration banner after finishing quiz.
- Results screen with summary + weak words list + recent practice.
- Results screen with study time summaries (daily, total, weekly/monthly).
- Results screen with persistent streak metrics (current/best) and daily history list.
- Quiz screen with recommended-word bilingual quiz (uses vocab exercise API path, LLM + fallback).
  - English-first question/choice display with Chinese shown by default (toggle still available).
  - Bilingual answer feedback and correct-answer explanation.
- Engagement loop:
  - Mascot header with animated reactions.
  - Daily goal progress bar.
  - Badge unlock when goal reached.
  - Streak counter synced from backend daily-goal progress.
- Pronunciation practice:
  - Record/stop with timeout guard.
  - Live audio level indicator during recording.
  - Waveform preview (pure Flutter) after recording.
  - Playback button for recorded audio.
- Comprehension:
  - Per-question save to backend.
  - Read-aloud word highlighting for web and mobile (rendered directly inside story blocks).
  - Chinese read-aloud highlight sync improved with hybrid fallback pacing + native anchor timing on web.
  - Adjustable reading speed (0.1x - 1.0x).
  - English-first story blocks with progressive Chinese reveal (per block + reveal all).
  - Guided question feedback with EN/ZH explanation and clue block highlighting.
- Vocabulary image hint:
  - Generate-on-demand image hint button in vocab exercise card.
  - Disabled button and message for abstract words (no image generation).
- Custom vocab:
  - Manual word entry (comma/newline separated).
  - Horizontal carousel list selector (Default/Custom/Weak words).
  - Scrollable word chips for tap-to-select vocabulary.
  - Typo suggestions with confirm/accept flow for corrections.
- Optional vocab generation parameters to request bilingual exercises.
- App tab order aligned to learning loop: Practice → Quiz → Results.
- Data Tools UX (Home shell):
  - Export/import progress backup (`.db`).
  - Export progress report (`.csv`).
  - Export/import custom vocabulary CSV (`append` / `replace`).
  - Action feedback via success/error snackbars and app-bar shortcut entry point.

## 3) QA Artifacts
- QA checklist: Requirement/QA_CHECKLIST.md
- API smoke checks (manual):
  - /healthz, /v1/vocab/default, /v1/vocab/exercise, /v1/vocab/image-hint
  - /v1/progress/exercise + /v1/progress/summary
  - /v1/progress/daily
  - /v1/comprehension/exercise
  - /v1/pronunciation/score + /v1/pronunciation/assess
- Data portability smoke checks (manual/API):
  - `/v1/progress/db-export`
  - `/v1/progress/db-import`
  - `/v1/progress/report.csv`
  - `/v1/vocab/custom/export`
  - `/v1/vocab/custom/import`

## 4) Pending / Planned
- RAG enablement + QA (set env flag, validate results).
- Multi-agent safety workflow (review + rewrite + fallback).
- Weak-word analysis improvements (recency + mastery).
- Manual UI QA pass + screenshots for report.

## 5) Known Issues / Notes
- Some mobile browsers do not emit web speech boundary events; a timing-based
  fallback drives highlighting to stay in sync with read-aloud audio.
- Record deletion is not exposed in the current API/UI flow (helper exists only in backend core).
- Render builds require web-safe imports only:
  - Use dart:web_audio for AudioContext/Analyser.
  - Avoid HtmlElementView unless ui_web registry is supported.
- Audio recording:
  - If no audio captured, show friendly error and retry.

## 6) Recent Commits (for reference)
- 8827e28: add UI data tools and progress report csv export.
- 6043833: add progress db import and custom vocab csv import/export.
- 29cff20: add progress database export endpoint for freeze backup.
- 7c5ce55: Enforce two-line story text and definition translation rule.
- e608aac: Restore two-line bilingual story output format.
- 3d27d4e: Focus vocab quiz on meaning comprehension.
- 0cf5a8e: Fix story state reset compile error.
- f4de35b: Refine story highlight behavior and bilingual vocab display.
- 08e027c: Make story language buttons mobile-friendly.
