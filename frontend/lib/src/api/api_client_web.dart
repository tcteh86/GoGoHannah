import 'dart:convert';
import 'dart:html';

import '../models/progress_summary.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
import '../models/comprehension_exercise.dart';
import 'api_client.dart';

ApiClient getApiClient(String baseUrl) => _WebApiClient(baseUrl);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class _WebApiClient implements ApiClient {
  final String _baseUrl;

  _WebApiClient(String baseUrl) : _baseUrl = baseUrl.replaceAll(RegExp(r'/$'), '');

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
  Future<VocabExercise> generateVocabExercise(String word) async {
    final data = await _postJson('/v1/vocab/exercise', {'word': word});
    return VocabExercise.fromJson(data);
  }

  @override
  Future<ComprehensionExercise> generateComprehensionExercise({
    required String level,
    String? theme,
    bool includeImage = false,
  }) async {
    final payload = {
      'level': level,
      'theme': theme,
      'include_image': includeImage,
    };
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

  Future<Map<String, dynamic>> _getJson(String path) async {
    final request = await HttpRequest.request(
      '$_baseUrl$path',
      method: 'GET',
      requestHeaders: {'Content-Type': 'application/json'},
    );
    if (request.status != null && request.status! >= 400) {
      throw ApiException('Request failed (${request.status})');
    }
    return _decodeJson(request.responseText);
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> payload) async {
    final request = await HttpRequest.request(
      '$_baseUrl$path',
      method: 'POST',
      sendData: jsonEncode(payload),
      requestHeaders: {'Content-Type': 'application/json'},
    );
    if (request.status != null && request.status! >= 400) {
      throw ApiException('Request failed (${request.status})');
    }
    return _decodeJson(request.responseText);
  }

  Map<String, dynamic> _decodeJson(String? responseText) {
    if (responseText == null || responseText.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(responseText);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Unexpected response format');
  }
}
