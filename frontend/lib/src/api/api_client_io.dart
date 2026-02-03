import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/progress_summary.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
import '../models/comprehension_exercise.dart';
import '../models/pronunciation_assessment.dart';
import '../models/rag_debug_result.dart';
import '../models/recent_exercise.dart';
import '../models/study_time_summary.dart';
import 'api_client.dart';

ApiClient getApiClient(String baseUrl) => _IoApiClient(baseUrl);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class _IoApiClient implements ApiClient {
  final String _baseUrl;
  final HttpClient _client = HttpClient();

  _IoApiClient(String baseUrl) : _baseUrl = baseUrl.replaceAll(RegExp(r'/$'), '');

  @override
  Future<List<String>> fetchDefaultVocab() async {
    final data = await _getJson('/v1/vocab/default');
    final words = data['words'];
    if (words is List) {
      return words.map((word) => word.toString()).toList();
    }
    throw ApiException('Invalid vocab response');
  }

  @override
  Future<VocabExercise> generateVocabExercise(
    String word, {
    String? learningDirection,
    String? outputStyle,
  }) async {
    final payload = {'word': word};
    if (learningDirection != null) {
      payload['learning_direction'] = learningDirection;
    }
    if (outputStyle != null) {
      payload['output_style'] = outputStyle;
    }
    final data = await _postJson('/v1/vocab/exercise', payload);
    return VocabExercise.fromJson(data);
  }

  @override
  Future<ComprehensionExercise> generateComprehensionExercise({
    required String level,
    String? theme,
    bool includeImage = false,
    String? learningDirection,
    String? outputStyle,
  }) async {
    final payload = {
      'level': level,
      'theme': theme,
      'include_image': includeImage,
    };
    if (learningDirection != null) {
      payload['learning_direction'] = learningDirection;
    }
    if (outputStyle != null) {
      payload['output_style'] = outputStyle;
    }
    final data = await _postJson('/v1/comprehension/exercise', payload);
    return ComprehensionExercise.fromJson(data);
  }

  @override
  Future<int> scorePronunciation(String word, String userText) async {
    final data = await _postJson('/v1/pronunciation/score', {
      'target_word': word,
      'user_text': userText,
    });
    final score = data['score'];
    if (score is num) {
      return score.toInt();
    }
    throw ApiException('Invalid score response');
  }

  @override
  Future<PronunciationAssessment> assessPronunciationAudio({
    required String word,
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    throw ApiException('Audio assessment is only supported on web for now.');
  }

  @override
  Future<void> saveExercise(SaveExercise payload) async {
    await _postJson('/v1/progress/exercise', payload.toJson());
  }

  @override
  Future<ProgressSummary> fetchProgressSummary(String childName) async {
    final data = await _getJson('/v1/progress/summary?child_name=${Uri.encodeComponent(childName)}');
    return ProgressSummary.fromJson(data);
  }

  @override
  Future<List<String>> fetchRecommendedWords(String childName, int limit) async {
    final data = await _getJson(
      '/v1/progress/recommended?child_name=${Uri.encodeComponent(childName)}&limit=$limit',
    );
    final words = data['words'];
    if (words is List) {
      return words.map((word) => word.toString()).toList();
    }
    throw ApiException('Invalid recommended response');
  }

  @override
  Future<List<String>> fetchCustomVocab(String childName) async {
    final data = await _getJson(
      '/v1/vocab/custom?child_name=${Uri.encodeComponent(childName)}',
    );
    final words = data['words'];
    if (words is List) {
      return words.map((word) => word.toString()).toList();
    }
    throw ApiException('Invalid custom vocab response');
  }

  @override
  Future<List<String>> addCustomVocab({
    required String childName,
    required List<String> words,
    String? listName,
    String mode = 'append',
  }) async {
    final payload = {
      'child_name': childName,
      'words': words,
      'list_name': listName,
      'mode': mode,
    };
    final data = await _postJson('/v1/vocab/custom/add', payload);
    final result = data['words'];
    if (result is List) {
      return result.map((word) => word.toString()).toList();
    }
    throw ApiException('Invalid custom vocab response');
  }

  @override
  Future<List<String>> suggestCustomVocab({
    required List<String> words,
  }) async {
    final payload = {'words': words};
    final data = await _postJson('/v1/vocab/custom/suggest', payload);
    final suggested = data['suggested'];
    if (suggested is List) {
      return suggested.map((word) => word.toString()).toList();
    }
    throw ApiException('Invalid suggestion response');
  }

  @override
  Future<List<RecentExercise>> fetchRecentExercises(
    String childName,
    int limit,
  ) async {
    final data = await _getJson(
      '/v1/progress/recent?child_name=${Uri.encodeComponent(childName)}&limit=$limit',
    );
    final exercises = data['exercises'];
    if (exercises is List) {
      return exercises
          .map((item) => item is Map<String, dynamic>
              ? RecentExercise.fromJson(item)
              : RecentExercise.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ))
          .toList();
    }
    throw ApiException('Invalid recent response');
  }

  @override
  Future<void> addStudyTime({
    required String childName,
    required String date,
    required int seconds,
  }) async {
    final payload = {
      'child_name': childName,
      'date': date,
      'seconds': seconds,
    };
    await _postJson('/v1/progress/time', payload);
  }

  @override
  Future<StudyTimeSummary> fetchStudyTime({
    required String childName,
    required String date,
  }) async {
    final data = await _getJson(
      '/v1/progress/time?child_name=${Uri.encodeComponent(childName)}&date=${Uri.encodeComponent(date)}',
    );
    return StudyTimeSummary.fromJson(data);
  }

  @override
  Future<StudyTimeTotalSummary> fetchStudyTimeTotal({
    required String childName,
  }) async {
    final data = await _getJson(
      '/v1/progress/time/total?child_name=${Uri.encodeComponent(childName)}',
    );
    return StudyTimeTotalSummary.fromJson(data);
  }

  @override
  Future<StudyTimeSummaryOverview> fetchStudyTimeSummary({
    required String childName,
    String? date,
  }) async {
    final dateParam = date == null ? '' : '&date_str=${Uri.encodeComponent(date)}';
    final data = await _getJson(
      '/v1/progress/time/summary?child_name=${Uri.encodeComponent(childName)}$dateParam',
    );
    return StudyTimeSummaryOverview.fromJson(data);
  }

  @override
  Future<RagDebugResult> fetchRagDebug({
    required String query,
    String? childName,
    int limit = 5,
  }) async {
    final encodedQuery = Uri.encodeComponent(query);
    final encodedChild =
        childName == null ? '' : '&child_name=${Uri.encodeComponent(childName)}';
    final data = await _getJson(
      '/v1/debug/rag?query=$encodedQuery$encodedChild&limit=$limit',
    );
    return RagDebugResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final request = await _client.getUrl(Uri.parse('$_baseUrl$path'));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      throw ApiException('Request failed (${response.statusCode})');
    }
    return _decodeJson(body);
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> payload) async {
    final request = await _client.postUrl(Uri.parse('$_baseUrl$path'));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      throw ApiException('Request failed (${response.statusCode})');
    }
    return _decodeJson(body);
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Unexpected response format');
  }
}
