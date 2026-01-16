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
    source: Optional[str] = None


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
