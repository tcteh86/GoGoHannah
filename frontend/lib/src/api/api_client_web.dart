import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import '../models/progress_summary.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
import '../models/vocab_image_hint.dart';
import '../models/comprehension_exercise.dart';
import '../models/pronunciation_assessment.dart';
import '../models/rag_debug_result.dart';
import '../models/recent_exercise.dart';
import '../models/study_time_summary.dart';
import '../models/daily_progress.dart';
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
  Future<VocabImageHint> generateVocabImageHint({
    required String word,
    required String definition,
  }) async {
    final data = await _postJson('/v1/vocab/image-hint', {
      'word': word,
      'definition': definition,
    });
    return VocabImageHint.fromJson(data);
  }

  @override
  Future<ComprehensionExercise> generateComprehensionExercise({
    required String level,
    String? theme,
    String? learningDirection,
    String? outputStyle,
  }) async {
    final payload = {
      'level': level,
      'theme': theme,
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
    final formData = FormData();
    formData.append('target_word', word);
    final normalizedMimeType = _normalizeMimeType(mimeType);
    final blob = Blob([audioBytes], normalizedMimeType);
    final extension = _extensionForMime(normalizedMimeType);
    formData.appendBlob('audio', blob, 'recording.$extension');

    final request = await HttpRequest.request(
      '$_baseUrl/v1/pronunciation/assess',
      method: 'POST',
      sendData: formData,
    );
    if (request.status != null && request.status! >= 400) {
      throw ApiException('Request failed (${request.status})');
    }
    final data = _decodeJson(request.responseText);
    return PronunciationAssessment.fromJson(data);
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
  Future<DailyProgressSummary> fetchDailyProgress({
    required String childName,
    int days = 30,
    int dailyGoal = 3,
  }) async {
    final data = await _getJson(
      '/v1/progress/daily?child_name=${Uri.encodeComponent(childName)}&days=$days&daily_goal=$dailyGoal',
    );
    return DailyProgressSummary.fromJson(data);
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
  Future<void> exportProgressDb({String? token}) async {
    await _downloadFile(
      '/v1/progress/db-export',
      fallbackFilename: 'progress.db',
      token: token,
    );
  }

  @override
  Future<void> importProgressDbFromPicker({String? token}) async {
    final file = await _pickFile('.db,application/x-sqlite3');
    if (file == null) {
      return;
    }
    final formData = FormData();
    formData.appendBlob('file', file, file.name);
    await _postForm('/v1/progress/db-import', formData, token: token);
  }

  @override
  Future<void> exportProgressReportCsv({required String childName}) async {
    await _downloadFile(
      '/v1/progress/report.csv?child_name=${Uri.encodeComponent(childName)}',
      fallbackFilename: 'progress-report-$childName.csv',
    );
  }

  @override
  Future<void> exportCustomVocabCsv({required String childName}) async {
    await _downloadFile(
      '/v1/vocab/custom/export?child_name=${Uri.encodeComponent(childName)}',
      fallbackFilename: 'vocabulary-$childName.csv',
    );
  }

  @override
  Future<void> importCustomVocabCsvFromPicker({
    required String childName,
    String mode = 'append',
    String? listName,
  }) async {
    final file = await _pickFile('.csv,text/csv');
    if (file == null) {
      return;
    }
    final formData = FormData();
    formData.append('child_name', childName);
    formData.append('mode', mode);
    if (listName != null && listName.trim().isNotEmpty) {
      formData.append('list_name', listName.trim());
    }
    formData.appendBlob('file', file, file.name);
    await _postForm('/v1/vocab/custom/import', formData);
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
    final request = await HttpRequest.request(
      '$_baseUrl$path',
      method: 'GET',
      requestHeaders: {'Content-Type': 'application/json'},
    );
    if (request.status != null && request.status! >= 400) {
      throw ApiException(_formatError(request.status, request.responseText));
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
      throw ApiException(_formatError(request.status, request.responseText));
    }
    return _decodeJson(request.responseText);
  }



  Future<void> _downloadFile(
    String path, {
    required String fallbackFilename,
    String? token,
  }) async {
    final headers = <String, String>{};
    if (token != null && token.trim().isNotEmpty) {
      headers['X-DB-Export-Token'] = token.trim();
    }
    final request = await HttpRequest.request(
      '$_baseUrl$path',
      method: 'GET',
      requestHeaders: headers,
      responseType: 'blob',
    );
    if (request.status != null && request.status! >= 400) {
      throw ApiException(_formatError(request.status, request.responseText));
    }
    final blob = request.response as Blob?;
    if (blob == null) {
      throw ApiException('Download failed: empty response body.');
    }
    final filename = _filenameFromDisposition(
          request.getResponseHeader('content-disposition'),
        ) ??
        fallbackFilename;
    final url = Url.createObjectUrlFromBlob(blob);
    try {
      final anchor = AnchorElement(href: url)
        ..download = filename
        ..style.display = 'none';
      document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } finally {
      Url.revokeObjectUrl(url);
    }
  }

  Future<void> _postForm(String path, FormData data, {String? token}) async {
    final headers = <String, String>{};
    if (token != null && token.trim().isNotEmpty) {
      headers['X-DB-Export-Token'] = token.trim();
    }
    final request = await HttpRequest.request(
      '$_baseUrl$path',
      method: 'POST',
      sendData: data,
      requestHeaders: headers,
    );
    if (request.status != null && request.status! >= 400) {
      throw ApiException(_formatError(request.status, request.responseText));
    }
  }

  Future<File?> _pickFile(String accept) async {
    final input = FileUploadInputElement()..accept = accept;
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) {
      return null;
    }
    return input.files!.first;
  }

  String? _filenameFromDisposition(String? header) {
    if (header == null || header.isEmpty) {
      return null;
    }
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
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

  String _formatError(int? status, String? responseText) {
    final code = status == null ? 'unknown' : status.toString();
    if (responseText == null || responseText.isEmpty) {
      return 'Request failed ($code)';
    }
    try {
      final decoded = jsonDecode(responseText);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail != null) {
          return 'Request failed ($code): ${detail.toString()}';
        }
      }
    } catch (_) {
      // Fall back to raw response text.
    }
    return 'Request failed ($code): $responseText';
  }

  String _normalizeMimeType(String mimeType) {
    final normalized = mimeType.trim();
    if (normalized.isEmpty) {
      return 'audio/webm';
    }
    return normalized.split(';').first;
  }

  String _extensionForMime(String mimeType) {
    switch (mimeType) {
      case 'audio/webm':
        return 'webm';
      case 'audio/ogg':
        return 'ogg';
      case 'audio/mp4':
        return 'mp4';
      case 'audio/mpeg':
        return 'mp3';
      case 'audio/wav':
      case 'audio/x-wav':
        return 'wav';
      default:
        return 'webm';
    }
  }
}
