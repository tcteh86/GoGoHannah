from typing import Dict, Optional

from pydantic import BaseModel, Field


class VocabExerciseRequest(BaseModel):
    word: str = Field(..., min_length=1, max_length=32)


class VocabExerciseResponse(BaseModel):
    definition: str
    example_sentence: str
    quiz_question: str
    quiz_choices: Dict[str, str]
    quiz_answer: str
    phonics: Optional[str] = None
    source: Optional[str] = None


class CustomVocabResponse(BaseModel):
    words: list[str]
    count: int


class CustomVocabAddRequest(BaseModel):
    child_name: str = Field(..., min_length=1, max_length=64)
    words: list[str] = Field(..., min_items=1, max_items=200)
    list_name: Optional[str] = Field(None, max_length=64)
    mode: str = Field("append", max_length=16)


class CustomVocabSuggestRequest(BaseModel):
    words: list[str] = Field(..., min_items=1, max_items=200)


class CustomVocabSuggestResponse(BaseModel):
    original: list[str]
    suggested: list[str]
    changed: bool


class ComprehensionExerciseRequest(BaseModel):
    level: str = Field("intermediate", min_length=3, max_length=16)
    theme: Optional[str] = Field(None, max_length=64)
    include_image: bool = False


class ComprehensionQuestion(BaseModel):
    question: str
    choices: Dict[str, str]
    answer: str


class ComprehensionExerciseResponse(BaseModel):
    story_title: str
    story_text: str
    image_description: str
    image_url: Optional[str] = None
    questions: list[ComprehensionQuestion]
    source: Optional[str] = None


class RecentExercise(BaseModel):
    word: str
    exercise_type: str
    score: int
    correct: bool
    created_at: str


class RecentExercisesResponse(BaseModel):
    exercises: list[RecentExercise]


class StudyTimeAddRequest(BaseModel):
    child_name: str = Field(..., min_length=1, max_length=64)
    date: str = Field(..., max_length=10)
    seconds: int = Field(..., ge=1, le=3600)


class StudyTimeResponse(BaseModel):
    date: str
    total_seconds: int


class StudyTimeTotalResponse(BaseModel):
    total_seconds: int


class StudyTimePeriodSummary(BaseModel):
    start_date: str
    end_date: str
    total_seconds: int


class StudyTimeSummaryResponse(BaseModel):
    date: str
    week: StudyTimePeriodSummary
    month: StudyTimePeriodSummary


class SaveExerciseRequest(BaseModel):
    child_name: str = Field(..., min_length=1, max_length=64)
    word: str = Field(..., min_length=1, max_length=32)
    exercise_type: str = Field(..., min_length=1, max_length=32)
    score: int = Field(..., ge=0, le=100)
    correct: bool


class PronunciationScoreRequest(BaseModel):
    target_word: str = Field(..., min_length=1, max_length=32)
    user_text: str = Field(..., min_length=1, max_length=128)


class PronunciationScoreResponse(BaseModel):
    score: int


class PronunciationAudioResponse(BaseModel):
    transcription: str
    score: int
