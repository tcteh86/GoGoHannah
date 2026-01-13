import streamlit as st
from gtts import gTTS
import os
import tempfile
import base64
from datetime import datetime
from streamlit_mic_recorder import mic_recorder

from vocab.loader import load_default_vocab, load_vocab_from_csv
from core.exercise import simple_exercise
from core.safety import sanitize_word
from core.scoring import check_answer, calculate_pronunciation_score
from core.progress import get_or_create_child, save_exercise, get_child_progress, get_recommended_words, get_practiced_words_wheel, clear_child_records
from llm.client import generate_vocab_exercise, LLMUnavailable, transcribe_audio, generate_comprehension_exercise, generate_story_image

st.set_page_config(page_title="GoGoHannah", page_icon="📚")

st.title("📚 GoGoHannah")
st.caption("AI-based English vocabulary and comprehension practice for young learners (5–9).")

# Practice Mode Selection
practice_mode = st.radio("Choose Practice Mode:", ["Vocabulary Practice", "Comprehension Practice"], horizontal=True)

# Child name input
child_name = st.text_input("Enter your name:", key="child_name")
if not child_name.strip():
    st.info("Please enter your name to start practicing!")
    st.stop()

child_id = get_or_create_child(child_name.strip())

if practice_mode == "Vocabulary Practice":
    progress = get_child_progress(child_id)
    if progress['total_exercises'] > 0:
        st.subheader("📊 Your Progress")
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Total Exercises", progress['total_exercises'])
        with col2:
            st.metric("Accuracy", f"{progress['accuracy']:.1%}")
        with col3:
            avg_quiz = progress['scores_by_type'].get('quiz', {}).get('avg_score', 0)
            st.metric("Avg Quiz Score", f"{avg_quiz:.1f}")

        # Practiced Words Wheel
        st.subheader("🎡 Your Practiced Words")
        practiced_words = get_practiced_words_wheel(child_id)
        if practiced_words:
            cols = st.columns(min(5, len(practiced_words)))
            for i, word_data in enumerate(practiced_words[:5]):  # Show first 5
                with cols[i % 5]:
                    score_color = "🟢" if word_data['avg_score'] >= 80 else "🟡" if word_data['avg_score'] >= 60 else "🔴"
                    st.markdown(f"""
                    <div style="border: 2px solid #ddd; border-radius: 10px; padding: 10px; text-align: center; margin: 5px;">
                        <h4>{word_data['word']}</h4>
                        <p>{score_color} {word_data['avg_score']:.0f}/100</p>
                        <small>{word_data['attempts']} attempts</small>
                    </div>
                    """, unsafe_allow_html=True)
        
            if len(practiced_words) > 5:
                st.info(f"And {len(practiced_words) - 5} more words practiced!")

        # Smart Suggestions
        st.subheader("💡 Smart Suggestions")
        all_words = load_default_vocab()
        recommended = get_recommended_words(child_id, all_words, 5)
        if recommended:
            st.write("**Recommended for practice:**")
            for word in recommended[:3]:
                st.write(f"• {word}")
            if len(recommended) > 3:
                with st.expander("See more suggestions"):
                    for word in recommended[3:]:
                        st.write(f"• {word}")
        else:
            st.success("🎉 Great job! You've practiced all available words. Try uploading a custom vocabulary list!")

    with st.sidebar:
        st.header("Vocabulary Set")
        mode = st.radio("Choose vocabulary source:", ["Default", "Upload CSV", "Recommended for You"])

        vocab = []
        try:
            if mode == "Default":
                vocab = load_default_vocab()
            elif mode == "Recommended for You":
                all_words = load_default_vocab()
                vocab = get_recommended_words(child_id, all_words)
                if not vocab:
                    vocab = all_words  # Fallback
            else:
                f = st.file_uploader("Upload a CSV with a 'word' column", type=["csv"])
                if f is not None:
                    vocab = load_vocab_from_csv(f)
        except Exception as e:
            st.error(str(e))

        # Clear Records Section
        st.header("🗑️ Manage Records")
        if st.button("Clear My Records", key="clear_confirm"):
            st.warning("⚠️ This will permanently delete all your progress and exercise history!")
            col1, col2 = st.columns(2)
            with col1:
                if st.button("❌ Yes, Delete Everything", key="confirm_delete"):
                    clear_child_records(child_id)
                    st.success("✅ All records cleared! Please refresh the page.")
                    st.rerun()
            with col2:
                if st.button("↩️ Cancel", key="cancel_delete"):
                    st.info("Operation cancelled.")

    if not vocab:
        st.info("Please select a vocabulary set to begin.")
        st.stop()

    word_raw = st.selectbox("Pick a word to practice:", vocab)

    try:
        word = sanitize_word(word_raw)
    except Exception as e:
        st.error(str(e))
        st.stop()

    if "practice_started" not in st.session_state:
        st.session_state.practice_started = False
    if "current_ex" not in st.session_state:
        st.session_state.current_ex = None
    if "current_word" not in st.session_state:
        st.session_state.current_word = None
    if "audio_processed" not in st.session_state:
        st.session_state.audio_processed = False
    if "tts_played" not in st.session_state:
        st.session_state.tts_played = False
    if "last_audio_bytes" not in st.session_state:
        st.session_state.last_audio_bytes = None

    # Reset practice if word changed
    if st.session_state.current_word != word:
        st.session_state.practice_started = False
        st.session_state.current_ex = None
        st.session_state.current_word = word
        st.session_state.audio_processed = False
        st.session_state.tts_played = False
        st.session_state.last_audio_bytes = None

    if st.button("Start Practice"):
        try:
            ex = generate_vocab_exercise(word)
        except LLMUnavailable:
            st.warning("AI service unavailable. Using basic exercise.")
            ex = simple_exercise(word)
        st.session_state.current_ex = ex
        st.session_state.practice_started = True

    if st.session_state.practice_started and st.session_state.current_ex:
        ex = st.session_state.current_ex
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
            correct = check_answer(choice, ex["quiz_answer"])
            if correct:
                st.success("Correct! 🎉")
            else:
                st.warning(f"Not quite. Correct answer is {ex['quiz_answer']}.")
        
            # Save quiz result
            save_exercise(child_id, word, "quiz", 100 if correct else 0, correct)

        # Pronunciation Practice
        st.header("🎤 Practice Pronunciation")
        st.write("Listen to the word, then record yourself saying it:")

        # Generate and play audio automatically when section loads (only once per word)
        if st.session_state.practice_started and not st.session_state.tts_played:
            st.session_state.tts_played = True
            tts = gTTS(text=word, lang='en', slow=False)
            with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as tmp_file:
                tts.save(tmp_file.name)
                # Auto-play using HTML
                audio_html = f"""
                <audio autoplay>
                    <source src="data:audio/mp3;base64,{base64.b64encode(open(tmp_file.name, 'rb').read()).decode()}" type="audio/mp3">
                </audio>
                """
                st.markdown(audio_html, unsafe_allow_html=True)
                st.audio(tmp_file.name, format='audio/mp3')  # Also show player for manual replay

        # Manual replay button
        if st.button("🔊 Play Word Again", key="replay_word"):
            tts = gTTS(text=word, lang='en', slow=False)
            with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as tmp_file:
                tts.save(tmp_file.name)
                st.audio(tmp_file.name, format='audio/mp3')

        # Audio recording
        st.write("Click the microphone to record your pronunciation:")
        audio = mic_recorder(
            start_prompt="🎙️ Start Recording",
            stop_prompt="⏹️ Stop Recording",
            key="recorder"
        )

    # Automatically process when audio is recorded (only if it's a new recording)
        if audio and (st.session_state.last_audio_bytes != audio['bytes']):
            st.session_state.last_audio_bytes = audio['bytes']
            st.session_state.audio_processed = True
            with st.spinner("🎤 Processing your pronunciation..."):
                    try:
                        # Transcribe audio
                        transcription = transcribe_audio(audio['bytes'])
                        st.write(f"**You said:** {transcription}")
                
                        # Calculate score
                        score = calculate_pronunciation_score(transcription, word)
                
                        # Score Card
                        st.subheader("📊 Pronunciation Score Card")
                        col1, col2, col3 = st.columns([1, 2, 1])
                        with col1:
                            st.metric("Score", f"{score}/100")
                        with col2:
                            if score >= 90:
                                st.success("🎉 Excellent! Perfect pronunciation!")
                            elif score >= 80:
                                st.info("👍 Great job! Almost perfect.")
                            elif score >= 70:
                                st.warning("🙂 Good! Keep practicing.")
                            else:
                                st.error("💪 Keep trying! Practice makes perfect.")
                        with col3:
                            st.metric("Accuracy", f"{score}%")
                
                        # Replay recorded audio
                        st.subheader("🔊 Your Recording")
                        st.audio(audio['bytes'], format='audio/wav')
                
                        # Save pronunciation result
                        correct = score >= 80
                        save_exercise(child_id, word, "pronunciation", score, correct)
                
                    except LLMUnavailable as e:
                        st.error(f"Could not process audio: {str(e)}")
                        st.info("Try typing your pronunciation instead:")
                        user_text = st.text_input("Type what you said:")
                        if user_text:
                            score = calculate_pronunciation_score(user_text, word)
                            st.write(f"**Score: {score}/100**")
                            correct = score >= 80
                            save_exercise(child_id, word, "pronunciation", score, correct)

elif practice_mode == "Comprehension Practice":
    st.header("📖 Comprehension Practice")
    st.write("Read a short story and answer questions to improve your understanding!")

    # Level selection
    story_level = st.selectbox(
        "Choose story difficulty level:",
        ["beginner", "intermediate", "expert"],
        format_func=lambda x: {
            "beginner": "🌱 Beginner (Short & Simple)",
            "intermediate": "🌿 Intermediate (Medium Length)",
            "expert": "🌳 Expert (Longer & Advanced)"
        }[x]
    )

    # Comprehension session state
    if "comp_ex" not in st.session_state:
        st.session_state.comp_ex = None
    if "comp_started" not in st.session_state:
        st.session_state.comp_started = False
    if "story_tts_played" not in st.session_state:
        st.session_state.story_tts_played = False
    if "questions_answered" not in st.session_state:
        st.session_state.questions_answered = []
    if "audio_generated_time" not in st.session_state:
        st.session_state.audio_generated_time = None
    if "audio_file_path" not in st.session_state:
        st.session_state.audio_file_path = None

    if st.button("Generate New Story"):
        with st.spinner("🪄 Creating your magical story..."):
            try:
                ex = generate_comprehension_exercise(level=story_level)
                st.session_state.comp_ex = ex
                st.session_state.comp_started = True
                st.session_state.story_tts_played = False
                st.session_state.questions_answered = []
                st.session_state.audio_generated_time = None
                st.session_state.audio_file_path = None
                
                # Generate image with progress
                with st.spinner("🎨 Painting the story illustration..."):
                    try:
                        image_url = generate_story_image(ex['image_description'])
                        st.session_state.story_image = image_url
                    except LLMUnavailable:
                        st.session_state.story_image = None
                        st.warning("Illustration couldn't be generated, but the story is ready!")
                
                # Generate audio in background
                with st.spinner("🎵 Preparing story audio..."):
                    try:
                        tts = gTTS(text=ex['story_text'], lang='en', slow=False)
                        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as tmp_file:
                            tts.save(tmp_file.name)
                            st.session_state.audio_file_path = tmp_file.name
                            st.session_state.audio_generated_time = datetime.now().timestamp()
                    except Exception as e:
                        st.warning(f"Audio preparation failed: {str(e)}. You can still read aloud manually.")
                
                st.success("✨ Your story is ready! Audio is prepared too - scroll down to read and enjoy.")
                
            except LLMUnavailable:
                st.error("AI service unavailable. Please try again later.")

    if st.session_state.comp_started and st.session_state.comp_ex:
        ex = st.session_state.comp_ex
        st.subheader(f"📚 {ex['story_title']}")
        
        # Create container for image to prevent re-rendering during audio playback
        image_container = st.container()
        with image_container:
            # Display image if available
            if 'story_image' in st.session_state and st.session_state.story_image:
                st.image(st.session_state.story_image, caption="Story Illustration", use_container_width=True)
        
        # Story text
        st.write(ex['story_text'])
        
        # Read Aloud Button - use key to prevent re-rendering
        if st.button("🔊 Read Story Aloud", key="read_aloud_button"):
            st.session_state.story_tts_played = True
            
            # Check if audio is already generated and file exists
            audio_path = st.session_state.get('audio_file_path')
            if audio_path and os.path.exists(audio_path) and os.path.getsize(audio_path) > 0:
                try:
                    # Audio already exists, just play it
                    audio_key = f"story_audio_{st.session_state.audio_generated_time}"
                    st.audio(audio_path, format='audio/mp3', autoplay=False, key=audio_key)
                    st.info("🎵 Audio ready! Click play above to listen.")
                except Exception as e:
                    st.warning(f"Audio file issue: {str(e)}. Regenerating...")
                    # Fall through to generate new audio
                    audio_path = None
            
            if not audio_path or not os.path.exists(audio_path):
                # Generate audio on demand
                st.session_state.audio_generated_time = datetime.now().timestamp()  # Force unique audio key
                with st.spinner("🎵 Generating audio..."):
                    try:
                        tts = gTTS(text=ex['story_text'], lang='en', slow=False)
                        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as tmp_file:
                            tts.save(tmp_file.name)
                            st.session_state.audio_file_path = tmp_file.name
                            # Display audio immediately with unique key to prevent caching
                            audio_key = f"story_audio_{st.session_state.audio_generated_time}"
                            st.audio(tmp_file.name, format='audio/mp3', autoplay=False, key=audio_key)
                    except Exception as e:
                        st.error(f"Failed to generate audio: {str(e)}")
        
        # Questions
        st.header("❓ Comprehension Questions")
        total_score = 0
        for i, q in enumerate(ex['questions']):
            st.subheader(f"Question {i+1}")
            st.write(q['question'])
            
            choice = st.radio(
                f"Choose for Q{i+1}:",
                list(q['choices'].keys()),
                format_func=lambda k: f"{k}. {q['choices'][k]}",
                key=f"q_{i}"
            )
            
            if st.button(f"Check Q{i+1}", key=f"check_{i}"):
                correct = choice == q['answer']
                if correct:
                    st.success("Correct! 🎉")
                    total_score += 1
                else:
                    st.warning(f"Not quite. Correct answer is {q['answer']}: {q['choices'][q['answer']]}")
                
                # Save result
                save_exercise(child_id, f"comp_q{i+1}", "comprehension", 100 if correct else 0, correct)
        
        if total_score == 3:
            st.balloons()
            st.success("🎉 Excellent! You got all questions right!")
        elif total_score >= 1:
            st.info(f"👍 Good job! You got {total_score}/3 correct.")
