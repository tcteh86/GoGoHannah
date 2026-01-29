# Implementation Status (Living Document)

Last updated: 30 Jan 2026

This document captures what is implemented, what is pending, and known
issues so a new agent can continue work if the session ends.

---

## 1) Implemented (Backend)
- FastAPI service with health and vocab endpoints.
- Vocab exercise generation (LLM + fallback) with phonics hints.
- Progress save + summary + recommended words.
- Recent practice endpoint (recent exercises history).
- Comprehension story generation with level selection.
- Optional illustration generation hook.
- Pronunciation scoring:
  - Text similarity scoring endpoint.
  - Audio upload endpoint (Whisper transcription + scoring).
- SQLite persistence for children + exercises.
- Custom vocab storage + manual list endpoints.
- RAG scaffolding (documents + embeddings tables, retrieval utilities, prompt
  context injection) gated by `GOGOHANNAH_RAG_ENABLED`.

## 2) Implemented (Frontend)
- Flutter web UI:
  - Practice screen with vocab + comprehension modes.
  - Results screen with summary + weak words list + recent practice.
  - Quick Check screen with recommended-word quiz.
- Engagement loop:
  - Mascot header with animated reactions.
  - Daily goal progress bar.
  - Badge unlock when goal reached.
  - Streak counter (session-based).
- Pronunciation practice:
  - Record/stop with timeout guard.
  - Live audio level indicator during recording.
  - Waveform preview (pure Flutter) after recording.
  - Playback button for recorded audio.
- Comprehension:
  - Per-question save to backend.
  - Optional image display when provided (supports inline data URIs).
  - Read-aloud word highlighting for web and mobile.
  - Adjustable reading speed (0.25x - 1.5x).
- Custom vocab:
  - Manual word entry (comma/newline separated).
  - Word list selector (Default/Custom/Weak words).

## 3) QA Artifacts
- QA checklist: Requirement/QA_CHECKLIST.md
- API smoke checks (manual):
  - /healthz, /v1/vocab/default, /v1/vocab/exercise
  - /v1/progress/exercise + /v1/progress/summary
  - /v1/comprehension/exercise
  - /v1/pronunciation/score + /v1/pronunciation/assess

## 4) Pending / Planned
- RAG enablement + QA (set env flag, validate results).
- Multi-agent safety workflow (review + rewrite + fallback).
- Weak-word analysis improvements (recency + mastery).
- Manual UI QA pass + screenshots for report.

## 5) Known Issues / Notes
- Some mobile browsers do not emit web speech boundary events; a timing-based
  fallback drives highlighting to stay in sync with read-aloud audio.
- Render builds require web-safe imports only:
  - Use dart:web_audio for AudioContext/Analyser.
  - Avoid HtmlElementView unless ui_web registry is supported.
- Audio recording:
  - If no audio captured, show friendly error and retry.

## 6) Recent Commits (for reference)
- Latest: Refresh documentation, remove architecture diagram doc, align roadmap.
- 2ed6012: Expand story read speed range and sync highlight timing.
- 85fbbcc: Improve TTS rate mapping and web highlight fallback.
- 6c6dae5: Add web fallback for story highlight.
- d593491: Add mobile story read highlight support.
- d1e924e: Fix results date format and story visuals.
- 7034f5c: Update milestone report progress.
- b22fb35: Add QA checklist and harden audio recording.
- d8cf3db: Fix recording timeout and remove typed pronunciation.
- 5251ff4: Add recording level indicator and audio preview.
- 9c61759: Fix web audio imports for build.
- 1900e59: Simplify recorded audio playback for web build.
- 9f51d15: Add waveform preview and fix fftSize null.
