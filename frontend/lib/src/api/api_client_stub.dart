import '../models/progress_summary.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
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
  Future<VocabExercise> generateVocabExercise(String word) async =>
      _unsupported();

  @override
  Future<List<String>> fetchRecommendedWords(String childName, int limit) async =>
      _unsupported();

  @override
  Future<void> saveExercise(SaveExercise payload) async => _unsupported();
}
