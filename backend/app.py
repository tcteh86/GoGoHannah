"""FastAPI backend exposing core GoGoHannah features.

This reuses the existing core/LLM logic while providing HTTP endpoints
for a future React frontend. Keep secrets server-side.
"""

from __future__ import annotations

import sys
import random
import json
import re
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, HTMLResponse
from pydantic import BaseModel, Field

# Make existing app modules importable
APP_ROOT = Path(__file__).resolve().parents[1] / "app"
if str(APP_ROOT) not in sys.path:
    sys.path.insert(0, str(APP_ROOT))

from core.exercise import simple_exercise  # type: ignore
from core.safety import sanitize_word  # type: ignore
from core.scoring import check_answer, calculate_pronunciation_score  # type: ignore
from core.progress import get_or_create_child, save_exercise, get_child_progress, get_recommended_words, get_practiced_words_wheel, get_recent_exercises  # type: ignore
from vocab.loader import load_default_vocab, load_vocab_from_csv  # type: ignore
from llm.client import generate_vocab_exercise, generate_comprehension_exercise, transcribe_audio, LLMUnavailable  # type: ignore

app = FastAPI(title="GoGoHannah API", version="0.1.0")

LOG_DIR = Path(__file__).resolve().parents[1] / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / "backend.log"

logger = logging.getLogger("gogohannah")
if not logger.handlers:
    logger.setLevel(logging.INFO)
    _fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    sh = logging.StreamHandler()
    sh.setFormatter(_fmt)
    logger.addHandler(sh)
    fh = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3)
    fh.setFormatter(_fmt)
    logger.addHandler(fh)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ExerciseRequest(BaseModel):
    word: str = Field(..., description="Vocabulary word to practice")
    child_name: Optional[str] = Field(None, description="Child name for tracking")


class AnswerRequest(BaseModel):
    word: str
    exercise_type: str = Field(..., description="quiz|pronunciation|comprehension|test")
    score: int = Field(..., ge=0, le=100)
    correct: bool
    child_name: str


class PronunciationRequest(BaseModel):
    user_text: str
    target_word: str
    child_name: Optional[str] = None


class ComprehensionRequest(BaseModel):
    level: str = Field("intermediate", description="beginner|intermediate|expert")
    child_name: Optional[str] = None


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/ui")


def _html_page(body: str) -> HTMLResponse:
    base = f"""
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1"/>
      <title>GoGoHannah</title>
      <style>
        :root {{
          --bg: linear-gradient(135deg, #fdf3ff, #e6f7ff);
          --card: #ffffff;
          --primary: #ff6fb8;
          --secondary: #6fd6ff;
          --text: #1c1c1c;
          --muted: #555;
          --shadow: 0 10px 30px rgba(0,0,0,0.08);
          --radius: 16px;
        }}
        * {{ box-sizing: border-box; }}
        body {{
          margin: 0;
          font-family: "Poppins", "Arial", sans-serif;
          color: var(--text);
          background: var(--bg);
          min-height: 100vh;
          padding: 16px;
        }}
        .shell {{
          max-width: 1100px;
          margin: 0 auto;
        }}
        header {{
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 16px;
        }}
        .brand {{
          display: flex;
          align-items: center;
          gap: 10px;
          font-weight: 700;
          font-size: 22px;
        }}
        .pill {{
          background: #fff3;
          padding: 6px 12px;
          border-radius: 999px;
          border: 1px solid #fff5;
          font-size: 12px;
        }}
        .nav {{
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
          gap: 10px;
        }}
        .nav button {{
          border: none;
          padding: 12px;
          border-radius: var(--radius);
          background: var(--card);
          box-shadow: var(--shadow);
          cursor: pointer;
          font-weight: 600;
          color: var(--text);
          transition: transform 0.1s ease, box-shadow 0.1s ease, background 0.2s ease;
        }}
        .nav button.active {{
          background: linear-gradient(135deg, var(--primary), var(--secondary));
          color: white;
          box-shadow: 0 12px 30px rgba(0,0,0,0.12);
        }}
        .nav button:hover {{
          transform: translateY(-2px);
          box-shadow: 0 14px 32px rgba(0,0,0,0.12);
        }}
        .grid {{
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
          gap: 14px;
        }}
        .card {{
          background: var(--card);
          border-radius: var(--radius);
          box-shadow: var(--shadow);
          padding: 16px;
        }}
        h1, h2, h3 {{
          margin: 0 0 10px 0;
        }}
        label {{
          display: block;
          font-weight: 600;
          margin-top: 8px;
          margin-bottom: 4px;
        }}
        input, select, button.cta {{
          width: 100%;
          padding: 12px;
          border-radius: 10px;
          border: 1px solid #e1e5eb;
          font-size: 15px;
        }}
        button.cta {{
          background: linear-gradient(135deg, var(--primary), var(--secondary));
          color: white;
          border: none;
          font-weight: 700;
          cursor: pointer;
          box-shadow: var(--shadow);
          margin-top: 10px;
        }}
        pre {{
          background: #f6f8fb;
          padding: 12px;
          border-radius: 10px;
          overflow-x: auto;
          font-size: 13px;
        }}
        .badge {{ display: inline-block; padding: 4px 8px; border-radius: 8px; font-size: 12px; }}
        .muted {{ color: var(--muted); font-size: 14px; }}
        .row {{ display: flex; gap: 10px; flex-wrap: wrap; }}
        .row .half {{ flex: 1 1 200px; }}
        .answers button {{
          margin: 6px 0;
          width: 100%;
          border-radius: 12px;
          border: 1px solid #e1e5eb;
          padding: 10px;
          text-align: left;
          background: #fafbff;
          cursor: pointer;
        }}
        .answers button.selected {{
          border-color: var(--primary);
          background: #fff0fa;
        }}
        table {{ width: 100%; border-collapse: collapse; font-size: 14px; }}
        th, td {{ padding: 8px; border-bottom: 1px solid #eceff3; text-align: left; }}
        @media (max-width: 600px) {{
          header {{ flex-direction: column; align-items: flex-start; }}
        }}
      </style>
    </head>
    <body>
      <div class="shell">
        {body}
      </div>
    </body>
    </html>
    """
    return HTMLResponse(base)


@app.get("/ui", include_in_schema=False)
def ui_home():
    try:
        default_words = load_default_vocab()
    except Exception:
        default_words = []
    default_words_json = json.dumps(default_words[:200])

    body = """
    <header>
      <div class="brand">🌈 GoGoHannah <span class="pill">AI vocab & stories</span></div>
      <div class="pill">Kids-friendly • Mobile-ready</div>
    </header>
    <div class="nav">
      <button class="active" onclick="showTab('vocab')">Vocabulary</button>
      <button onclick="showTab('comprehension')">Comprehension</button>
      <button onclick="showTab('progress')">Progress</button>
      <button onclick="showTab('quick')">Quick Check</button>
      <button onclick="location.href='/docs'">API Docs</button>
    </div>
    <div style="height:12px;"></div>
    <div class="card">
      <div class="row">
        <div class="half">
          <label>Child Name</label>
          <input id="childName" placeholder="Hannah"/>
        </div>
        <div class="half muted">Name is used to track progress.</div>
      </div>
      <div id="toast" class="muted"></div>
    </div>

    <div id="tab-vocab" class="tab">
      <div class="grid">
        <div class="card">
          <h2>Vocabulary Practice</h2>
          <p class="muted">Pick a word and let Hannah build a mini exercise.</p>
          <label>Choose a word</label>
          <select id="wordSelect"></select>
          <label>Or type your own</label>
          <input id="wordInput" placeholder="Type a new word"/>
          <button class="cta" onclick="generateVocab()">Generate Exercise</button>
        </div>
        <div class="card" id="vocabResultCard" style="display:none;">
          <h3 id="vocabWord"></h3>
          <p id="vocabDefinition"></p>
          <p><strong>Example:</strong> <span id="vocabExample"></span></p>
          <p><strong>Quiz:</strong> <span id="vocabQuizQ"></span></p>
          <div class="answers" id="vocabAnswers"></div>
          <div id="vocabFeedback" class="muted"></div>
        </div>
      </div>
    </div>

    <div id="tab-comprehension" class="tab" style="display:none;">
      <div class="grid">
        <div class="card">
          <h2>Comprehension Practice</h2>
          <p class="muted">Generate a short story and answer 3 questions.</p>
          <label>Level</label>
          <select id="compLevel">
            <option value="beginner">Beginner</option>
            <option value="intermediate" selected>Intermediate</option>
            <option value="expert">Expert</option>
          </select>
          <button class="cta" onclick="generateStory()">Generate Story</button>
        </div>
        <div class="card" id="compResultCard" style="display:none;">
          <h3 id="compTitle"></h3>
          <p id="compStory"></p>
          <div id="compQuestions"></div>
          <div id="compFeedback" class="muted"></div>
        </div>
      </div>
    </div>

    <div id="tab-progress" class="tab" style="display:none;">
      <div class="grid">
        <div class="card">
          <h2>Progress</h2>
          <button class="cta" onclick="loadProgress()">Refresh Progress</button>
          <div id="progressData" class="muted" style="margin-top:10px;">No data yet.</div>
        </div>
      </div>
    </div>

    <div id="tab-quick" class="tab" style="display:none;">
      <div class="grid">
        <div class="card">
          <h2>Quick Check</h2>
          <p class="muted">A mini quiz with a few words.</p>
          <button class="cta" onclick="generateQuick()">Generate Quick Check</button>
        </div>
        <div class="card" id="quickResult" style="display:none;">
          <div id="quickList"></div>
        </div>
      </div>
    </div>

    <script>
    let defaultWords = __DEFAULT_WORDS__;
    let vocabExercise = null;
    let compExercise = null;
    let quickExercises = [];

    function toast(msg) {
      const t = document.getElementById('toast');
      t.textContent = msg || '';
      t.style.color = msg ? '#d14' : 'var(--muted)';
    }

    document.addEventListener('DOMContentLoaded', async () => {
      ensureDefaultWords();
      populateDefaultWords();
      await loadDefaultWords();
    });

    function showTab(name) {
      document.querySelectorAll('.nav button').forEach(btn => btn.classList.remove('active'));
      document.querySelectorAll('.tab').forEach(t => t.style.display = 'none');
      document.getElementById(`tab-${name}`).style.display = 'block';
      const btn = Array.from(document.querySelectorAll('.nav button')).find(b => b.textContent.toLowerCase().includes(name));
      if (btn) btn.classList.add('active');
    }

    function ensureDefaultWords() {
      if (!Array.isArray(defaultWords) || defaultWords.length === 0) {
        defaultWords = ["happy","brave","gentle","kind","bright","curious","friendly","smile","play","share"];
      }
    }

    function populateDefaultWords() {
      if (!defaultWords || defaultWords.length === 0) return;
      const select = document.getElementById('wordSelect');
      select.innerHTML = defaultWords.map(w => `<option value="${w}">${w}</option>`).join('');
    }

    async function loadDefaultWords() {
      try {
        const resp = await fetch('/vocab/default');
        const data = await resp.json();
        if (Array.isArray(data.words) && data.words.length) {
          defaultWords = data.words;
          populateDefaultWords();
        }
      } catch (e) {
        toast('Could not load default words. Using built-in list.');
      }
    }

    function getChild() {{
      return document.getElementById('childName').value.trim();
    }}

    async function generateVocab() {{
      const child = getChild();
      const typed = document.getElementById('wordInput').value.trim();
      const picked = document.getElementById('wordSelect').value;
      const word = typed || picked;
      if (!word) {{ alert('Please choose or type a word.'); return; }}
      try {{
        const resp = await fetch('/exercise/generate', {{
          method: 'POST',
          headers: {{'Content-Type': 'application/json'}},
          body: JSON.stringify({{word, child_name: child || null}})
        }});
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detail || 'Error');
        vocabExercise = data.exercise;
        renderVocab(word, data.exercise);
        toast('');
      }} catch (e) {{
        toast(e.message);
      }}
    }}

    function renderVocab(word, ex) {{
      document.getElementById('vocabResultCard').style.display = 'block';
      document.getElementById('vocabWord').textContent = word;
      document.getElementById('vocabDefinition').textContent = ex.definition;
      document.getElementById('vocabExample').textContent = ex.example_sentence;
      document.getElementById('vocabQuizQ').textContent = ex.quiz_question;
      const ans = document.getElementById('vocabAnswers');
      ans.innerHTML = '';
      ['A','B','C'].forEach(letter => {{
        const btn = document.createElement('button');
        btn.textContent = `${{letter}}. ${{ex.quiz_choices[letter]}}`;
        btn.onclick = () => checkVocab(letter);
        ans.appendChild(btn);
      }});
      document.getElementById('vocabFeedback').textContent = '';
    }}

    async function checkVocab(letter) {{
      if (!vocabExercise) return;
      const correct = letter === vocabExercise.quiz_answer;
      document.getElementById('vocabFeedback').textContent = correct ? 'Great job! 🌟' : `Try again! Correct answer is ${vocabExercise.quiz_answer}.`;
      const child = getChild();
      if (child) {{
        await fetch('/exercise/check', {{
          method: 'POST',
          headers: {{'Content-Type': 'application/json'}},
          body: JSON.stringify({{
            word: document.getElementById('vocabWord').textContent,
            exercise_type: 'quiz',
            score: correct ? 100 : 0,
            correct,
            child_name: child
          }})
        }});
      }}
    }}

    async function generateStory() {{
      const child = getChild();
      const level = document.getElementById('compLevel').value;
      try {{
        const resp = await fetch('/comprehension/generate', {{
          method: 'POST',
          headers: {{'Content-Type': 'application/json'}},
          body: JSON.stringify({{level, child_name: child || null}})
        }});
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detail || 'Error');
        compExercise = data.exercise;
        renderStory(compExercise);
        toast('');
      }} catch (e) {{
        toast(e.message);
      }}
    }}

    function renderStory(ex) {{
      document.getElementById('compResultCard').style.display = 'block';
      document.getElementById('compTitle').textContent = ex.story_title;
      document.getElementById('compStory').textContent = ex.story_text;
      const qwrap = document.getElementById('compQuestions');
      qwrap.innerHTML = '';
      ex.questions.forEach((q, idx) => {{
        const section = document.createElement('div');
        section.innerHTML = `<p><strong>Q${{idx+1}}:</strong> ${{q.question}}</p>`;
        const answers = document.createElement('div');
        answers.className = 'answers';
        ['A','B','C'].forEach(letter => {{
          const btn = document.createElement('button');
          btn.textContent = `${{letter}}. ${{q.choices[letter]}}`;
          btn.onclick = () => checkComp(idx, letter);
          btn.id = `comp-${{idx}}-${{letter}}`;
          answers.appendChild(btn);
        }});
        section.appendChild(answers);
        qwrap.appendChild(section);
      }});
      document.getElementById('compFeedback').textContent = '';
    }}

    async function checkComp(idx, letter) {{
      if (!compExercise) return;
      const q = compExercise.questions[idx];
      const correct = letter === q.answer;
      document.getElementById('compFeedback').textContent = correct ? 'Nice! 🎉' : `Correct answer: ${q.answer}`;
      const child = getChild();
      if (child) {{
        await fetch('/exercise/check', {{
          method: 'POST',
          headers: {{'Content-Type': 'application/json'}},
          body: JSON.stringify({{
            word: `comp_q${{idx+1}}`,
            exercise_type: 'comprehension',
            score: correct ? 100 : 0,
            correct,
            child_name: child
          }})
        }});
      }}
    }}

    async function loadProgress() {{
      const child = getChild();
      if (!child) {{ alert('Enter child name first.'); return; }}
      try {{
        const resp = await fetch(`/progress/${{encodeURIComponent(child)}}`);
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detail || 'Error');
        const p = data.progress || {{}};
        const weak = data.progress?.weak_words || [];
        const recent = data.recent || [];
        const recs = data.recommended || [];
        document.getElementById('progressData').innerHTML = `
          <p><strong>Total:</strong> ${{p.total_exercises || 0}} | <strong>Accuracy:</strong> ${(p.accuracy*100||0).toFixed(1)}%</p>
          <p><strong>Weak words:</strong> ${{weak.slice(0,5).map(w => w.word).join(', ') || 'None'}}</p>
          <p><strong>Recommended:</strong> ${{recs.slice(0,5).join(', ') || 'None'}}</p>
          <p><strong>Recent:</strong></p>
          <ul>${{recent.slice(0,5).map(r => `<li>${{r.word}} (${r.exercise_type}) - ${{r.score}}</li>`).join('')}} </ul>
        `;
        toast('');
      }} catch (e) {{
        toast(e.message);
      }}
    }}

    async function generateQuick() {{
      const child = getChild();
      if (!child) {{ alert('Enter child name first.'); return; }}
      try {{
        const resp = await fetch(`/quick-check?child_name=${{encodeURIComponent(child)}}&count=3`);
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detail || 'Error');
        quickExercises = data.items || [];
        renderQuick();
        toast('');
      }} catch (e) {{
        toast(e.message);
      }}
    }}

    function renderQuick() {{
      const wrap = document.getElementById('quickList');
      document.getElementById('quickResult').style.display = 'block';
      wrap.innerHTML = '';
      quickExercises.forEach((item, idx) => {{
        const card = document.createElement('div');
        card.style.marginBottom = '12px';
        card.innerHTML = `<p><strong>Word:</strong> ${{item.word}}</p><p>${{item.exercise.quiz_question}}</p>`;
        const answers = document.createElement('div');
        answers.className = 'answers';
        ['A','B','C'].forEach(letter => {{
          const btn = document.createElement('button');
          btn.textContent = `${{letter}}. ${{item.exercise.quiz_choices[letter]}}`;
          btn.onclick = () => checkQuick(idx, letter);
          answers.appendChild(btn);
        }});
        card.appendChild(answers);
        wrap.appendChild(card);
      }});
    }}

    async function checkQuick(idx, letter) {{
      const item = quickExercises[idx];
      const correct = letter === item.exercise.quiz_answer;
      alert(correct ? 'Great job! 🌟' : `Correct answer: ${item.exercise.quiz_answer}`);
      const child = getChild();
      if (child) {{
        await fetch('/exercise/check', {{
          method: 'POST',
          headers: {{'Content-Type': 'application/json'}},
          body: JSON.stringify({{
            word: item.word,
            exercise_type: 'test',
            score: correct ? 100 : 0,
            correct,
            child_name: child
          }})
        }});
      }}
    }}
    </script>
    """
    body = body.replace("__DEFAULT_WORDS__", default_words_json)
    # Normalize doubled braces used in the inline JS/HTML so the browser parses it.
    body = body.replace("{{", "{").replace("}}", "}")
    return _html_page(body)


@app.get("/vocab/default")
def vocab_default():
    words = load_default_vocab()
    return {"words": words}


@app.post("/exercise/generate")
def generate_exercise(payload: ExerciseRequest):
    logger.info("generate_exercise request word=%r child=%r", payload.word, payload.child_name)
    try:
        word = sanitize_word(payload.word)
    except Exception as e:
        logger.warning("sanitize failed for generate_exercise word=%r child=%r: %s", payload.word, payload.child_name, e)
        raise HTTPException(status_code=400, detail=str(e))

    try:
        ex = generate_vocab_exercise(word)
        source = "llm"
    except LLMUnavailable:
        ex = simple_exercise(word)
        source = "fallback"
    except Exception:
        logger.exception("generate_exercise failed word=%r child=%r", payload.word, payload.child_name)
        raise

    child_id = None
    if payload.child_name:
        child_id = get_or_create_child(payload.child_name.strip())

    logger.info("generate_exercise success word=%r child=%r source=%s", word, payload.child_name, source)
    return {"exercise": ex, "source": source, "child_id": child_id}


@app.post("/vocab/upload")
def vocab_upload(file: UploadFile = File(...)):
    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are supported.")
    try:
        words = load_vocab_from_csv(file.file)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"words": words}


_INTERNAL_EXERCISE_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


@app.post("/exercise/check")
def check_quiz(payload: AnswerRequest):
    raw_word = (payload.word or "").strip()
    logger.info(
        "exercise_check request word=%r type=%s child=%r score=%s correct=%s",
        raw_word,
        payload.exercise_type,
        payload.child_name,
        payload.score,
        payload.correct,
    )

    try:
        word = sanitize_word(raw_word)
    except Exception as e:
        # Synthetic exercise IDs (e.g., comp_q1, test_q2) are generated server-side
        # and can include underscores/digits that sanitize_word rejects. Allow them
        # for non-vocab exercise types while still blocking unexpected input.
        if payload.exercise_type in {"quiz", "comprehension", "test"} and _INTERNAL_EXERCISE_ID.match(raw_word):
            word = raw_word
        else:
            logger.warning(
                "exercise_check sanitize failed word=%r type=%s child=%r: %s",
                raw_word,
                payload.exercise_type,
                payload.child_name,
                e,
            )
            raise HTTPException(status_code=400, detail=str(e))

    child_id = get_or_create_child(payload.child_name.strip())
    try:
        save_exercise(child_id, word, payload.exercise_type, payload.score, payload.correct)
    except Exception:
        logger.exception(
            "exercise_check failed saving word=%r type=%s child=%r score=%s correct=%s",
            word,
            payload.exercise_type,
            payload.child_name,
            payload.score,
            payload.correct,
        )
        raise
    logger.info(
        "exercise_check saved word=%r type=%s child=%r score=%s correct=%s",
        word,
        payload.exercise_type,
        payload.child_name,
        payload.score,
        payload.correct,
    )
    return {"status": "saved"}


@app.post("/pronunciation/score")
def pronunciation_score(payload: PronunciationRequest):
    try:
        word = sanitize_word(payload.target_word)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    score = calculate_pronunciation_score(payload.user_text, word)

    child_id = None
    if payload.child_name:
        child_id = get_or_create_child(payload.child_name.strip())
        save_exercise(child_id, word, "pronunciation", score, score >= 80)

    return {"score": score, "child_id": child_id}


@app.post("/pronunciation/transcribe")
def pronunciation_transcribe(file: UploadFile = File(...)):
    try:
        audio_bytes = file.file.read()
        transcript = transcribe_audio(audio_bytes)
        return {"transcript": transcript}
    except LLMUnavailable as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/quick-check")
def quick_check(child_name: Optional[str] = None, count: int = 3):
    all_words = load_default_vocab()
    sample_size = min(max(count, 1), 5)
    words = random.sample(all_words, sample_size) if all_words else []
    items = [{"word": w, "exercise": simple_exercise(w)} for w in words]
    return {"items": items, "child_name": child_name}


@app.post("/comprehension/generate")
def comprehension_generate(payload: ComprehensionRequest):
    try:
        ex = generate_comprehension_exercise(level=payload.level)
    except LLMUnavailable as e:
        raise HTTPException(status_code=503, detail=str(e))

    child_id = None
    if payload.child_name:
        child_id = get_or_create_child(payload.child_name.strip())

    return {"exercise": ex, "child_id": child_id}


@app.get("/progress/{child_name}")
def progress(child_name: str):
    child_id = get_or_create_child(child_name.strip())
    data = get_child_progress(child_id)
    wheel = get_practiced_words_wheel(child_id)
    recent = get_recent_exercises(child_id, limit=20)

    all_words = load_default_vocab()
    recommended = get_recommended_words(child_id, all_words, 10)

    return {
        "progress": data,
        "practiced_words": wheel,
        "recent": recent,
        "recommended": recommended,
    }
