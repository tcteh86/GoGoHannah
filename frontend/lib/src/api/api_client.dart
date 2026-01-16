import 'dart:typed_data';

import 'api_client_stub.dart'
    if (dart.library.html) 'api_client_web.dart'
    if (dart.library.io) 'api_client_io.dart';
import '../models/progress_summary.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
import '../models/comprehension_exercise.dart';
import '../models/pronunciation_assessment.dart';

abstract class ApiClient {
  Future<List<String>> fetchDefaultVocab();
  Future<VocabExercise> generateVocabExercise(String word);
  Future<ComprehensionExercise> generateComprehensionExercise({
    required String level,
    String? theme,
    bool includeImage = false,
  });
  Future<int> scorePronunciation(String word, String userText);
  Future<PronunciationAssessment> assessPronunciationAudio({
    required String word,
    required Uint8List audioBytes,
    required String mimeType,
  });
  Future<void> saveExercise(SaveExercise payload);
  Future<ProgressSummary> fetchProgressSummary(String childName);
  Future<List<String>> fetchRecommendedWords(String childName, int limit);
}

ApiClient createApiClient(String baseUrl) => getApiClient(baseUrl);
