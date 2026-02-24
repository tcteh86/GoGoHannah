# Project Summary
## A Prototype of an AI-Based English Vocabulary Learning Assistant for Young Learners

---

## 1. Problem Formulation & User Need

Young learners (ages 5-9) need consistent English practice outside school, but
many families have limited time for guided vocabulary and reading support.
GoGoHannah addresses this with a child-friendly practice app that combines
structured exercises with AI-generated content.

---

## 2. Method & Generative AI Services (Current Implementation)

The current implementation uses a Flutter web frontend and FastAPI backend with
OpenAI services:

- Text generation (`gpt-4o-mini`) for vocabulary and comprehension exercises
- Audio transcription (`whisper-1`) for pronunciation assessment
- Image generation (`dall-e-3`) for on-demand vocabulary hint images
- Embeddings support (`text-embedding-3-small`) for optional RAG scaffolding

Boundaries are enforced with prompt constraints, schema validation, and input
sanitization to keep outputs age-appropriate and structurally reliable.

---

## 3. Integration, Features & User Interaction Flow

### Current Scope

- Web-based prototype with child-friendly UI
- Child-name gate before practice starts
- Vocabulary and comprehension practice modes
- Progress tracking, recent history, weak-word insights, and study-time summaries
- Recommended-word quiz flow
- Custom vocabulary manual entry with typo suggestion support

### Core Implemented Features

- **Vocabulary Selection**
  - Built-in default word list
  - Custom per-child word list via manual entry (comma/newline separated)

- **Vocabulary Practice**
  - Generate definition + example + single meaning-match 3-choice quiz
  - Backend uses LLM-first generation with deterministic fallback
  - Bilingual English/Chinese output currently used in UI
  - Image hint button for visualizable words; abstract words are flagged and disabled

- **Pronunciation Practice**
  - Auto-play word TTS
  - Audio recording + upload for transcription and scoring
  - Recording preview and playback in UI

- **Comprehension Practice**
  - Story generation by level with 3 comprehension questions
  - Story read-aloud with highlighting and speed control

- **Results & Progress**
  - Total exercises, accuracy, average quiz score
  - Weak-word list and recent practice history
  - Study-time views (daily, weekly, monthly, total)

### Notes on Current Limits

- CSV upload is not wired into the current Flutter UI flow.
- Record deletion is not currently exposed as a user-facing API/UI action.
