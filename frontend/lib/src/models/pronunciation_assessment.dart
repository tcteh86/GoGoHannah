class PronunciationAssessment {
  final String transcription;
  final int score;

  PronunciationAssessment({
    required this.transcription,
    required this.score,
  });

  factory PronunciationAssessment.fromJson(Map<String, dynamic> json) {
    final scoreValue = json['score'];
    return PronunciationAssessment(
      transcription: json['transcription']?.toString() ?? '',
      score: scoreValue is num ? scoreValue.toInt() : 0,
    );
  }
}
