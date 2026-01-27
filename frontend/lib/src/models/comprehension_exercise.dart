class ComprehensionExercise {
  final String storyTitle;
  final String storyText;
  final String imageDescription;
  final String? imageUrl;
  final List<ComprehensionQuestion> questions;
  final String? source;

  ComprehensionExercise({
    required this.storyTitle,
    required this.storyText,
    required this.imageDescription,
    required this.questions,
    this.imageUrl,
    this.source,
  });

  factory ComprehensionExercise.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    final questions = <ComprehensionQuestion>[];
    if (rawQuestions is List) {
      for (final item in rawQuestions) {
        if (item is Map<String, dynamic>) {
          questions.add(ComprehensionQuestion.fromJson(item));
        } else if (item is Map) {
          questions.add(
            ComprehensionQuestion.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }
    return ComprehensionExercise(
      storyTitle: json['story_title']?.toString() ?? '',
      storyText: json['story_text']?.toString() ?? '',
      imageDescription: json['image_description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      questions: questions,
      source: json['source']?.toString(),
    );
  }
}

class ComprehensionQuestion {
  final String question;
  final Map<String, String> choices;
  final String answer;

  ComprehensionQuestion({
    required this.question,
    required this.choices,
    required this.answer,
  });

  factory ComprehensionQuestion.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    final choices = <String, String>{};
    if (rawChoices is Map) {
      rawChoices.forEach((key, value) {
        choices[key.toString()] = value.toString();
      });
    }
    return ComprehensionQuestion(
      question: json['question']?.toString() ?? '',
      choices: choices,
      answer: json['answer']?.toString() ?? '',
    );
  }
}
