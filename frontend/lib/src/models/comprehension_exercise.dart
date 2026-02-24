class ComprehensionExercise {
  final String storyTitle;
  final String storyText;
  final List<StoryBlock> storyBlocks;
  final List<KeyVocabularyItem> keyVocabulary;
  final String imageDescription;
  final String? imageUrl;
  final List<ComprehensionQuestion> questions;
  final String? source;

  ComprehensionExercise({
    required this.storyTitle,
    required this.storyText,
    required this.storyBlocks,
    required this.keyVocabulary,
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

    final rawBlocks = json['story_blocks'];
    final storyBlocks = <StoryBlock>[];
    if (rawBlocks is List) {
      for (final item in rawBlocks) {
        if (item is Map<String, dynamic>) {
          storyBlocks.add(StoryBlock.fromJson(item));
        } else if (item is Map) {
          storyBlocks.add(
            StoryBlock.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    final rawVocab = json['key_vocabulary'];
    final keyVocabulary = <KeyVocabularyItem>[];
    if (rawVocab is List) {
      for (final item in rawVocab) {
        if (item is Map<String, dynamic>) {
          keyVocabulary.add(KeyVocabularyItem.fromJson(item));
        } else if (item is Map) {
          keyVocabulary.add(
            KeyVocabularyItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    final storyText = json['story_text']?.toString() ?? '';
    final resolvedBlocks = storyBlocks.isNotEmpty
        ? storyBlocks
        : _deriveBlocksFromStoryText(storyText);
    return ComprehensionExercise(
      storyTitle: json['story_title']?.toString() ?? '',
      storyText: storyText,
      storyBlocks: resolvedBlocks,
      keyVocabulary: keyVocabulary,
      imageDescription: json['image_description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      questions: questions,
      source: json['source']?.toString(),
    );
  }

  static List<StoryBlock> _deriveBlocksFromStoryText(String storyText) {
    final lines = storyText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final blocks = <StoryBlock>[];
    String? pendingEnglish;
    for (final line in lines) {
      final isChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(line);
      if (isChinese) {
        blocks.add(
          StoryBlock(english: pendingEnglish ?? line, chinese: line),
        );
        pendingEnglish = null;
      } else {
        if (pendingEnglish == null) {
          pendingEnglish = line;
        } else {
          blocks.add(StoryBlock(english: pendingEnglish, chinese: pendingEnglish));
          pendingEnglish = line;
        }
      }
    }
    if (pendingEnglish != null) {
      blocks.add(StoryBlock(english: pendingEnglish, chinese: pendingEnglish));
    }
    return blocks;
  }
}

class StoryBlock {
  final String english;
  final String chinese;

  StoryBlock({required this.english, required this.chinese});

  factory StoryBlock.fromJson(Map<String, dynamic> json) {
    return StoryBlock(
      english: json['english']?.toString() ?? '',
      chinese: json['chinese']?.toString() ?? '',
    );
  }
}

class KeyVocabularyItem {
  final String word;
  final String meaningEn;
  final String meaningZh;

  KeyVocabularyItem({
    required this.word,
    required this.meaningEn,
    required this.meaningZh,
  });

  factory KeyVocabularyItem.fromJson(Map<String, dynamic> json) {
    return KeyVocabularyItem(
      word: json['word']?.toString() ?? '',
      meaningEn: json['meaning_en']?.toString() ?? '',
      meaningZh: json['meaning_zh']?.toString() ?? '',
    );
  }
}

class ComprehensionQuestion {
  final String question;
  final Map<String, String> choices;
  final String answer;
  final String? questionType;
  final String? explanationEn;
  final String? explanationZh;
  final int? evidenceBlockIndex;

  ComprehensionQuestion({
    required this.question,
    required this.choices,
    required this.answer,
    this.questionType,
    this.explanationEn,
    this.explanationZh,
    this.evidenceBlockIndex,
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
      questionType: json['question_type']?.toString(),
      explanationEn: json['explanation_en']?.toString(),
      explanationZh: json['explanation_zh']?.toString(),
      evidenceBlockIndex: (json['evidence_block_index'] is num)
          ? (json['evidence_block_index'] as num).toInt()
          : null,
    );
  }
}
