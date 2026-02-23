# QA Checklist (Baseline)

Use this checklist to validate the live prototype before new feature work.

## Environment
- [ ] Backend URL: https://gogohannah.onrender.com
- [ ] Frontend URL: https://gogohannah-ui.onrender.com
- [ ] Browser + OS:
- [ ] Test child name:

## Backend API Smoke Checks
- [ ] GET /healthz returns {"status":"ok"}
- [ ] GET /v1/vocab/default returns word list
- [ ] POST /v1/vocab/exercise (valid word) returns quiz payload
- [ ] POST /v1/vocab/exercise (invalid word) returns 400
- [ ] POST /v1/progress/exercise saves result
- [ ] GET /v1/progress/summary reflects saved result
- [ ] POST /v1/comprehension/exercise (include_image=false) returns story + questions
- [ ] POST /v1/comprehension/exercise (include_image=true) returns image_url or fallback
- [ ] POST /v1/pronunciation/score returns numeric score
- [ ] POST /v1/pronunciation/assess accepts non-empty audio upload
- [ ] POST /v1/pronunciation/assess with empty audio returns 400

## Frontend Flow Checks
### Entry + Navigation
- [ ] Enter child name and start
- [ ] Switch between Practice, Results, Quick Check tabs

### Vocabulary Practice
- [ ] Select word and generate exercise
- [ ] Check answer shows feedback
- [ ] Mascot reaction updates for correct/incorrect
- [ ] Result saves and appears in Results summary

### Pronunciation Practice
- [ ] Record audio and stop recording
- [ ] Playback works
- [ ] Scoring returns transcription + score
- [ ] Recording/transcription failure shows friendly retry guidance

### Comprehension Mode
- [ ] Generate story at each level
- [ ] Answer each question and save results
- [ ] Optional image generation loads (or handles fallback)

### Results + Progress
- [ ] Results refresh shows total exercises + accuracy
- [ ] Weak words list populates after incorrect answers

### Engagement Loop
- [ ] Daily goal progress bar updates
- [ ] Badge appears when goal reached
- [ ] Streak counter increments on goal completion

### Error Handling
- [ ] Invalid word shows friendly error
- [ ] Empty audio shows helpful feedback
- [ ] API timeout shows retry guidance

## Evidence
- [ ] Screenshot: Practice (vocab)
- [ ] Screenshot: Practice (comprehension)
- [ ] Screenshot: Pronunciation result
- [ ] Screenshot: Results summary
- [ ] Screenshot: Quick Check
- [ ] Notes / issues:
