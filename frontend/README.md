# React/Next.js Frontend Plan

Target: Replace the Streamlit UI with a React (Next.js) client consuming the FastAPI backend.

## Endpoints to use (from backend/app.py)
- `GET /health` – service status
- `GET /vocab/default` – default vocab list
- `POST /exercise/generate` – generate vocab exercise (LLM + fallback)
- `POST /exercise/check` – save quiz/test result
- `POST /pronunciation/score` – score pronunciation (text similarity; extend with audio endpoint later)
- `POST /comprehension/generate` – generate story + MCQs
- `GET /progress/{child_name}` – dashboard data (metrics, wheel, recent, recommendations)

Upcoming: `POST /vocab/upload` (CSV), `POST /pronunciation/transcribe` (audio -> text), CORS/auth config.

## Suggested stack
- Next.js (TypeScript) with App Router
- UI: Chakra UI/Material UI or Tailwind + custom components
- Audio: Web Speech/MediaRecorder for capture; `audio` element for playback
- Data fetching: `fetch`/SWR/React Query
- Validation: Zod/TypeScript types matching backend responses

## Pages/components
- `/` (Home/Practice): child name capture; vocab select; quiz flow; TTS playback; answer check
- `/comprehension`: generate story, render MCQs, show image/audio
- `/progress`: metrics, weak words, recent history, practiced words wheel, recommendations
- `/quick-check`: mini quiz sampler

## Dev setup (once scaffolded)
```
npm create next-app@latest frontend --ts
cd frontend
npm install
npm run dev
```
Set backend URL in `.env.local` (e.g., `NEXT_PUBLIC_API_BASE=http://localhost:8000`).
