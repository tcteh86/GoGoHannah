import 'dart:typed_data';

import '../models/progress_summary.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
import '../models/comprehension_exercise.dart';
import '../models/pronunciation_assessment.dart';
import '../models/rag_debug_result.dart';
import '../models/recent_exercise.dart';
import '../models/study_time_summary.dart';
import '../models/daily_progress.dart';
import 'api_client.dart';

ApiClient getApiClient(String baseUrl) => _UnsupportedApiClient();

class _UnsupportedApiClient implements ApiClient {
  Never _unsupported() {
    throw UnsupportedError('API client not supported on this platform.');
  }

  @override
  Future<List<String>> fetchDefaultVocab() async => _unsupported();

  @override
  Future<ProgressSummary> fetchProgressSummary(String childName) async =>
      _unsupported();

  @override
  Future<VocabExercise> generateVocabExercise(
    String word, {
    String? learningDirection,
    String? outputStyle,
  }) async =>
      _unsupported();

  @override
  Future<ComprehensionExercise> generateComprehensionExercise({
    required String level,
    String? theme,
    bool includeImage = false,
    String? learningDirection,
    String? outputStyle,
  }) async =>
      _unsupported();

  @override
  Future<int> scorePronunciation(String word, String userText) async =>
      _unsupported();

  @override
  Future<PronunciationAssessment> assessPronunciationAudio({
    required String word,
    required Uint8List audioBytes,
    required String mimeType,
  }) async =>
      _unsupported();

  @override
  Future<List<String>> fetchRecommendedWords(String childName, int limit) async =>
      _unsupported();

  @override
  Future<void> saveExercise(SaveExercise payload) async => _unsupported();

  @override
  Future<List<String>> fetchCustomVocab(String childName) async => _unsupported();

  @override
  Future<List<String>> addCustomVocab({
    required String childName,
    required List<String> words,
    String? listName,
    String mode = 'append',
  }) async =>
      _unsupported();

  @override
  Future<List<String>> suggestCustomVocab({
    required List<String> words,
  }) async =>
      _unsupported();

  @override
  Future<List<RecentExercise>> fetchRecentExercises(
    String childName,
    int limit,
  ) async =>
      _unsupported();

  @override
  Future<DailyProgressSummary> fetchDailyProgress({
    required String childName,
    int days = 30,
    int dailyGoal = 3,
  }) async =>
      _unsupported();

  @override
  Future<void> addStudyTime({
    required String childName,
    required String date,
    required int seconds,
  }) async =>
      _unsupported();

  @override
  Future<StudyTimeSummary> fetchStudyTime({
    required String childName,
    required String date,
  }) async =>
      _unsupported();

  @override
  Future<StudyTimeTotalSummary> fetchStudyTimeTotal({
    required String childName,
  }) async =>
      _unsupported();

  @override
  Future<StudyTimeSummaryOverview> fetchStudyTimeSummary({
    required String childName,
    String? date,
  }) async =>
      _unsupported();

  @override
  Future<RagDebugResult> fetchRagDebug({
    required String query,
    String? childName,
    int limit = 5,
  }) async =>
      _unsupported();
}
