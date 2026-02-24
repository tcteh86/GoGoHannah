class VocabExercise {
  final String definition;
  final String exampleSentence;
  final String quizQuestion;
  final Map<String, String> quizChoices;
  final String quizAnswer;
  final bool imageHintEnabled;
  final String? imageHintReason;
  final String? phonics;
  final String? source;

  VocabExercise({
    required this.definition,
    required this.exampleSentence,
    required this.quizQuestion,
    required this.quizChoices,
    required this.quizAnswer,
    required this.imageHintEnabled,
    this.imageHintReason,
    this.phonics,
    this.source,
  });

  factory VocabExercise.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['quiz_choices'];
    final choices = <String, String>{};
    if (rawChoices is Map) {
      rawChoices.forEach((key, value) {
        choices[key.toString()] = value.toString();
      });
    }
    return VocabExercise(
      definition: json['definition']?.toString() ?? '',
      exampleSentence: json['example_sentence']?.toString() ?? '',
      quizQuestion: json['quiz_question']?.toString() ?? '',
      quizChoices: choices,
      quizAnswer: json['quiz_answer']?.toString() ?? '',
      imageHintEnabled: json['image_hint_enabled'] == true,
      imageHintReason: json['image_hint_reason']?.toString(),
      phonics: json['phonics']?.toString(),
      source: json['source']?.toString(),
    );
  }
}
