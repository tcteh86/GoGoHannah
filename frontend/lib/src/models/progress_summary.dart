class ProgressSummary {
  final int totalExercises;
  final double accuracy;
  final Map<String, ScoreSummary> scoresByType;
  final List<WeakWord> weakWords;

  ProgressSummary({
    required this.totalExercises,
    required this.accuracy,
    required this.scoresByType,
    required this.weakWords,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    final scoresRaw = json['scores_by_type'];
    final scores = <String, ScoreSummary>{};
    if (scoresRaw is Map) {
      scoresRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          scores[key.toString()] = ScoreSummary.fromJson(value);
        } else if (value is Map) {
          scores[key.toString()] = ScoreSummary.fromJson(
            value.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      });
    }

    final weakRaw = json['weak_words'];
    final weakWords = <WeakWord>[];
    if (weakRaw is List) {
      for (final item in weakRaw) {
        if (item is Map<String, dynamic>) {
          weakWords.add(WeakWord.fromJson(item));
        } else if (item is Map) {
          weakWords.add(
            WeakWord.fromJson(item.map((k, v) => MapEntry(k.toString(), v))),
          );
        }
      }
    }

    return ProgressSummary(
      totalExercises: (json['total_exercises'] ?? 0) is num
          ? (json['total_exercises'] as num).toInt()
          : 0,
      accuracy: (json['accuracy'] ?? 0) is num
          ? (json['accuracy'] as num).toDouble()
          : 0,
      scoresByType: scores,
      weakWords: weakWords,
    );
  }
}

class ScoreSummary {
  final double avgScore;
  final int count;

  ScoreSummary({required this.avgScore, required this.count});

  factory ScoreSummary.fromJson(Map<String, dynamic> json) {
    return ScoreSummary(
      avgScore: (json['avg_score'] ?? 0) is num
          ? (json['avg_score'] as num).toDouble()
          : 0,
      count: (json['count'] ?? 0) is num ? (json['count'] as num).toInt() : 0,
    );
  }
}

class WeakWord {
  final String word;
  final double avgScore;
  final int attempts;

  WeakWord({required this.word, required this.avgScore, required this.attempts});

  factory WeakWord.fromJson(Map<String, dynamic> json) {
    return WeakWord(
      word: json['word']?.toString() ?? '',
      avgScore: (json['avg_score'] ?? 0) is num
          ? (json['avg_score'] as num).toDouble()
          : 0,
      attempts: (json['attempts'] ?? 0) is num
          ? (json['attempts'] as num).toInt()
          : 0,
    );
  }
}
