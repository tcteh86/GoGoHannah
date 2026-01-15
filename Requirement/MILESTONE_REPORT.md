# ITI123 Milestone Report (Stage 2)

## 1. Motivation & Problem Update
- Target: 5-9 year-olds practicing English vocabulary independently with light parent/teacher oversight.
- Pain points: Limited time/confidence from parents, costly tuition, static tools; need engaging, safe, and low-cost practice.
- Scope (Phase 1): Vocabulary and comprehension practice with child-safe outputs; light personalization via recommendations; no heavy learner modeling yet.

## 2. Implementation 1 (Streamlit) - retired
- The prior Streamlit single-page app (`app/main.py`) has been removed due to maintainability and UX limits. Logic was migrated to shared core modules and the FastAPI backend.

## 3. Implementation 2 (React + FastAPI) - current
- Frontend: React/Next.js client (to be scaffolded) for richer UI (audio/chat components, charts, routing, state).
- Backend: FastAPI (`backend/app.py`) reusing `app/core` and `app/llm`; secrets stay server-side.
- Endpoints: vocab generation, comprehension generation, pronunciation scoring, quiz saving, progress retrieval, default vocab, CSV upload, transcription; CORS enabled for frontend development. Auth to be added.
- Data: SQLite initially (configurable path); can migrate to managed DB later.

## 4. Features Implemented (Stage 2 to date)
- Core logic: Vocab practice (default/CSV), sanitization, quiz checking, deterministic fallback; recommendations; progress tracking; comprehension stories + MCQs; pronunciation scoring (text similarity) and persistence.
- OpenAI integration: Vocab exercises (gpt-4o-mini), comprehension stories, DALL-E images, Whisper transcription; JSON validation; fallback when unavailable.
- FastAPI backend: Endpoints for vocab generation, comprehension generation, pronunciation scoring, quiz saving, progress retrieval, default vocab, CSV upload, transcription; CORS enabled.
- Data: SQLite for children/exercises/history; default vocab CSV; CSV upload supported via API.
- Quick check logic retained in core for future frontend use.

## 5. Integration Results & Gaps
- OpenAI: gpt-4o-mini for chat JSON; DALL-E 3 for images; Whisper-1 for transcription. JSON validated; deterministic fallback on failure.
- FastAPI: Endpoints functional; React client not yet built. Needs auth/secrets hardening; wider CORS policy tuning; frontend wiring for audio capture/playback.
- Gaps/TBD: LLM latency/JSON validity metrics; Whisper accuracy; DALL-E availability; SQLite permissions in constrained environments.

## 6. Evaluation Plan
- Quantitative: Quiz correctness; pronunciation similarity scores; JSON validity rate from LLM calls; latency (P50/P90) for generation/transcription; API success/fallback counts.
- Engagement: Exercises per session, distinct words, repeats on weak words.
- Qualitative: Parent/teacher feedback on clarity, safety, setup; frontend UX in React once built.
- Reliability: Track fallback usage and transcription failures; monitor API error rates.
- Tests: pytest suite covering loader, scoring, and basic API health/vocab endpoints.

## 7. Risks & Mitigations
- API unavailability/quota: Deterministic fallback; user messaging; consider caching and retry.
- Unsafe/off-topic outputs: Strict prompts, JSON enforcement, input sanitization; consider topic filtering for future.
- Audio variability: Provide text-input fallback; guide users on browser/device support.
- Data persistence: SQLite path must be writable; consider per-user or cloud DB for deployment.
- Timeline creep: Keep Phase 1 to vocab/comprehension basics; defer advanced personalization.

## 8. Next Steps (toward Final Report/Presentation)
- Backend: Harden auth/secrets, JSON schema validation, error handling; finalize file upload and Whisper transcription endpoints; tune CORS.
- Frontend: Scaffold React/Next.js client; implement vocab practice, comprehension, pronunciation (record/transcribe/score), quick check, and progress dashboard; integrate Web Audio APIs.
- Data: Harden SQLite path/config; document migrations; consider per-user storage or managed DB.
- Metrics: Capture latency, JSON validity, fallback counts, API error rates; include in Milestone/Final Report; add basic logging.
- Demo: Prepare short video + screenshots; update architecture/data-flow diagrams for React + FastAPI.
