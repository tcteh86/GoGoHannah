class RecentExercise {
  final String word;
  final String exerciseType;
  final int score;
  final bool correct;
  final String createdAt;

  RecentExercise({
    required this.word,
    required this.exerciseType,
    required this.score,
    required this.correct,
    required this.createdAt,
  });

  factory RecentExercise.fromJson(Map<String, dynamic> json) {
    return RecentExercise(
      word: json['word']?.toString() ?? '',
      exerciseType: json['exercise_type']?.toString() ?? '',
      score: (json['score'] ?? 0) is num ? (json['score'] as num).toInt() : 0,
      correct: json['correct'] == true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
