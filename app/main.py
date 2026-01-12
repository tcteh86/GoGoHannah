import streamlit as st

from vocab.loader import load_default_vocab, load_vocab_from_csv
from core.exercise import simple_exercise
from core.safety import sanitize_word
from core.scoring import check_answer

st.set_page_config(page_title="GoGoHannah", page_icon="📚")

st.title("📚 GoGoHannah")
st.caption("AI-based English vocabulary practice for young learners (5–9).")

with st.sidebar:
    st.header("Vocabulary Set")
    mode = st.radio("Choose vocabulary source:", ["Default", "Upload CSV"])

    vocab = []
    try:
        if mode == "Default":
            vocab = load_default_vocab()
        else:
            f = st.file_uploader("Upload a CSV with a 'word' column", type=["csv"])
            if f is not None:
                vocab = load_vocab_from_csv(f)
    except Exception as e:
        st.error(str(e))

if not vocab:
    st.info("Please select a vocabulary set to begin.")
    st.stop()

word_raw = st.selectbox("Pick a word to practice:", vocab)

try:
    word = sanitize_word(word_raw)
except Exception as e:
    st.error(str(e))
    st.stop()

if st.button("Start Practice"):
    ex = simple_exercise(word)  # Replace with LLM output later

    st.subheader(f"Word: {word}")
    st.write("**Definition:**", ex["definition"])
    st.write("**Example:**", ex["example_sentence"])
    st.write("**Quiz:**", ex["quiz_question"])

    choice = st.radio(
        "Choose:",
        list(ex["quiz_choices"].keys()),
        format_func=lambda k: f"{k}. {ex['quiz_choices'][k]}",
    )

    if st.button("Check Answer"):
        if check_answer(choice, ex["quiz_answer"]):
            st.success("Correct! 🎉")
        else:
            st.warning(f"Not quite. Correct answer is {ex['quiz_answer']}.")
