# Milestone Report (Draft) - GoGoHannah

## Project
GoGoHannah: AI-based English vocabulary and comprehension practice for ages 5-9.

## Reporting Period
Start: 16 Jan 2026  
Milestone Due: 29 Jan 2026

---

## 1) Motivation
Young learners (5-9) need engaging, independent English practice that supports
busy parents. The prototype focuses on vocabulary, pronunciation, and
comprehension using GenAI, but must remain child-safe and fun.

---

## 2) Application Development

### 2.1 AI Services / Models (chosen)
OpenAI is selected for early integration speed and unified coverage:
- Text generation: `gpt-4o-mini` for definitions, examples, quizzes.
- Audio transcription: `whisper-1` for pronunciation analysis.
- Image generation: `dall-e-3` for story illustrations.
- Embeddings (planned) for RAG and personalized recommendations.

Justification:
- Single API family simplifies integration and deployment.
- Stable JSON response format for safety and validation.
- Cost-aware model choice for student project constraints.

### 2.2 Technical Architecture (current + planned)
Current:
- FastAPI backend in `backend/` with OpenAI integration.
- SQLite persistence for progress tracking.
- Flutter web UI for practice, results, and quick check.

Planned:
- Flutter web frontend hosted on Firebase.
- Backend hosted on Render.
- Secure API-key usage on server only.

### 2.3 Integration Approach (progress)
Completed:
- Backend API scaffold with vocab exercise generation.
- Progress storage with child identity and exercise records.
- Pronunciation scoring endpoint (text similarity) for early validation.
- Streamlit MVP removed to avoid framework collision.
- Deployment guides added for Render (backend) and Firebase (frontend).
- Live deployment on Render:
  - Frontend: https://gogohannah-ui.onrender.com/
  - Backend: https://gogohannah.onrender.com/
- Smoke tests passed:
  - Backend health and vocab endpoints.
  - UI flow: generate exercise, check answer, refresh results.
- Phase A (Engagement) implementation in Flutter:
  - Mascot header with animated reactions.
  - Daily goal tracker with progress bar.
  - Badge unlock for goal completion.
  - Streak counter (session-based).
- Phase B (GenAI depth) shipped:
  - Comprehension story mode with level selection.
  - Optional illustration generation hook.
  - Per-question saving for comprehension practice.
  - Phonics hints added to vocab exercises.
  - Pronunciation recording with immediate playback and scoring.
  - Backend file upload dependency added for audio assessment.
  - Web audio recorder build fix for MediaRecorder events.
  - Recording timeout guard and UX hint for stopping recording.
- Custom vocabulary support:
  - Manual word entry for quick additions.
  - Custom vocab storage per child.
  - LLM typo correction suggestions with confirm/keep-original choices.
- Bilingual vocab exercise options:
  - Learning direction (English ↔ Chinese) and immersion/bilingual output style.
- Bilingual vocab configuration for English ↔ Chinese practice.
- Bilingual vocab exercise options:
  - Learning direction (English ↔ Chinese) and immersion/bilingual output style.
- Progress insights:
  - Recent practice history endpoint + UI list.
  - Weak-word suggestions highlighted for review.
- Study time tracking:
  - Daily, total, weekly/monthly summaries shown in results.
- Read-aloud improvements:
  - Word highlighting on web and mobile (TTS boundary + fallback timing).
  - Adjustable reading speed control (0.25x - 1.5x).
- Results polish:
  - Compact date ranges for week/month on small screens.
- Story visuals:
  - Inline illustration handling (data URIs + network fallback).

In progress:
- RAG + embeddings enablement and QA (approved plan).

Planned:
- RAG + embeddings for smarter explanations.
- Multi-agent workflow for safety + content generation.
- LLM-based weak-word analysis.

### 2.4 Feature Status
Done:
- Vocab exercise API with LLM fallback.
- Bilingual vocab configuration for English ↔ Chinese practice.
- Progress save + summary endpoints.
- Study time tracking endpoints + results summaries.
- Flutter web UI for practice, results, and quick check.
- Pronunciation analysis flow (audio + transcription).
- Comprehension story flow (story + questions + illustration).
- Custom vocab upload + manual entry flow.
- Custom vocab typo correction suggestions.
- Recent practice history view + weak-word highlighting.

Next:
- RAG + embeddings for smarter explanations.
- Multi-agent workflow for safety + content generation.
- LLM-based weak-word analysis and recommendations.

---

## 3) Risks & Mitigation
- Time constraints: focus on web-first MVP, then expand.
- Cost control: use smaller text model (`gpt-4o-mini`).
- Safety: validate JSON schemas and sanitize vocab input.

---


## 8) Update Log (Jan 31, 2026)
- Added bilingual vocab configuration (learning direction + immersion/bilingual output style).
## 4) Next Steps (before 29 Jan)
1) QA the engagement + GenAI flows end-to-end.
2) Capture demo screenshots for milestone report.
3) Draft a RAG + embeddings prototype plan.
4) Outline the multi-agent safety workflow.
5) Explore weak-word analysis improvements and UX.

---

## 5) Update Log (Jan 22, 2026)
- Marked Phase A engagement loop and Phase B GenAI depth as completed.
- Added QA checklist for baseline verification (Requirement/QA_CHECKLIST.md).
- Hardened web audio recording (timeouts, empty capture handling).
- Added live audio level indicator and waveform preview for recordings.
- RAG + embeddings implementation plan approved.
- Added custom vocab upload + manual entry.
- Added recent practice history and weak-word suggestions in UI.

## 6) Update Log (Jan 29, 2026)
- Added read-aloud word highlighting support on web and mobile, with a timing
  fallback for browsers missing boundary events.
- Expanded story read-aloud speed range to 0.25x - 1.5x and synced highlight
  timing to reading speed.
- Improved story illustration delivery by supporting inline data-URI images.
- Shortened results date ranges for better mobile readability.

## 7) Update Log (Jan 30, 2026)
- Refreshed documentation to align roadmap and milestone status with the current branch state.

## 8) Update Log (Jan 31, 2026)
- Added bilingual vocab configuration (learning direction + immersion/bilingual output style).
