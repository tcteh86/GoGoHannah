class SaveExercise {
  final String childName;
  final String word;
  final String exerciseType;
  final int score;
  final bool correct;

  SaveExercise({
    required this.childName,
    required this.word,
    required this.exerciseType,
    required this.score,
    required this.correct,
  });

  Map<String, dynamic> toJson() => {
        'child_name': childName,
        'word': word,
        'exercise_type': exerciseType,
        'score': score,
        'correct': correct,
      };
}
