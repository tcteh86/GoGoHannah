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
- Audio transcription: `whisper-1` for pronunciation analysis (next phase).
- Image generation: `dall-e-3` for story illustrations (next phase).
- Embeddings (planned) for RAG and personalized recommendations.

Justification:
- Single API family simplifies integration and deployment.
- Stable JSON response format for safety and validation.
- Cost-aware model choice for student project constraints.

### 2.2 Technical Architecture (current + planned)
Current:
- FastAPI backend in `backend/` with OpenAI integration.
- SQLite persistence for progress tracking.

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

In progress:
- Phase A (Engagement) implementation in Flutter:
  - Mascot header with animated reactions.
  - Daily goal tracker with progress bar.
  - Badge unlock for goal completion.
  - Streak counter (session-based).
- Phase B (GenAI depth) started:
  - Comprehension story mode with level selection.
  - Optional illustration generation hook.
  - Per-question saving for comprehension practice.
  - Phonics hints added to vocab exercises.
  - Pronunciation recording with immediate playback and scoring.
  - Backend file upload dependency added for audio assessment.
  - Web audio recorder build fix for MediaRecorder events.

Planned:
- Audio transcription pipeline for pronunciation.
- Story comprehension generation + image support.
- RAG + embeddings for smarter explanations.
- Multi-agent workflow for safety + content generation.
- LLM-based weak-word analysis.

### 2.4 Feature Status
Done:
- Vocab exercise API with LLM fallback.
- Progress save + summary endpoints.

Next:
- Flutter UI for vocab practice (web).
- Pronunciation analysis flow (audio + transcription).
- Comprehension story flow (story + questions + illustration).

---

## 3) Risks & Mitigation
- Time constraints: focus on web-first MVP, then expand.
- Cost control: use smaller text model (`gpt-4o-mini`).
- Safety: validate JSON schemas and sanitize vocab input.

---

## 4) Next Steps (before 29 Jan)
1) Build Flutter web UI with three screens:
   - Practice
   - Past Results
   - Test & Check
2) Connect Flutter to backend endpoints.
3) Deploy backend on Render, frontend on Firebase.
4) Capture demo screenshots for milestone report.
5) Complete Phase A engagement loop polishing.
