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
- [ ] English definition/example show immediately
- [ ] Chinese definition/example can be revealed and hidden
- [ ] Quick checks render for:
  - [ ] rotating primary type (meaning/context/fill-blank)
  - [ ] EN → ZH meaning
  - [ ] ZH → EN meaning
- [ ] Check feedback shows:
  - [ ] correct answer
  - [ ] EN/ZH meaning reference
  - [ ] wrong-choice explanation
- [ ] Mascot reaction updates for correct/incorrect
- [ ] Result saves and appears in Results summary

### Pronunciation Practice
- [ ] Record audio and stop recording
- [ ] Playback works
- [ ] Scoring returns transcription + score
- [ ] Recording/transcription failure shows friendly retry guidance

### Comprehension Mode
- [ ] Generate story at each level
- [ ] Story renders as short blocks (not one long paragraph)
- [ ] English line is visible first for each block
- [ ] Read-aloud highlight appears directly in story blocks (no duplicate highlight panel)
- [ ] Chinese read-aloud highlights each character/word in sequence (no skipped jumps)
- [ ] Chinese reveal works:
  - [ ] per block
  - [ ] reveal all / hide all
- [ ] Answer each question and save results
- [ ] Questions include scaffold mix:
  - [ ] literal
  - [ ] vocabulary-in-context
  - [ ] inference
- [ ] After checking, feedback shows EN/ZH explanation
- [ ] Wrong answer can highlight a clue story block
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
