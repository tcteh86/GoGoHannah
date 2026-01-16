import 'dart:convert';
import 'dart:io';

import '../models/progress_summary.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
import '../models/comprehension_exercise.dart';
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
