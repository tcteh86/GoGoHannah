import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart' as rec;

import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _WebAudioRecorder();

class _WebAudioRecorder implements AudioRecorder {
  final rec.AudioRecorder _record = rec.AudioRecorder();
  StreamSubscription<rec.Amplitude>? _amplitudeSubscription;
  final ValueNotifier<double> _levelNotifier = ValueNotifier(0);
  bool _isRecording = false;
  String _mimeType = 'audio/webm';

  @override
  bool get isRecording => _isRecording;

  @override
  ValueListenable<double> get levelListenable => _levelNotifier;

  @override
  Future<void> start() async {
    if (_isRecording) {
      return;
    }
    final allowed = await _record.hasPermission();
    if (!allowed) {
      throw UnsupportedError('Microphone permission needed.');
    }
    const config = rec.RecordConfig(encoder: rec.AudioEncoder.opus);
    _mimeType = _mimeTypeForEncoder(config.encoder);
    final filename = _suggestedFilename(_mimeType);
    await _record.start(config, path: filename);
    _isRecording = true;
    _startAmplitudeMonitor();
  }

  @override
  Future<AudioRecording> stop() async {
    if (!_isRecording) {
      throw StateError('Recorder is not running.');
    }
    final path = await _record.stop();
    _isRecording = false;
    await _stopAmplitudeMonitor();
    if (path == null || path.isEmpty) {
      throw StateError('No audio captured. Try recording again.');
    }
    final bytes = await _readBytes(path);
    final mimeType = _resolveMimeType(path);
    return AudioRecording(bytes: bytes, mimeType: mimeType, url: path);
  }

  Future<Uint8List> _readBytes(String path) async {
    if (path.startsWith('data:')) {
      final data = UriData.parse(path);
      return Uint8List.fromList(data.contentAsBytes());
    }
    final response = await html.HttpRequest.request(
      path,
      responseType: 'arraybuffer',
    );
    final buffer = response.response as ByteBuffer;
    return Uint8List.view(buffer);
  }

  String _resolveMimeType(String path) {
    if (path.startsWith('data:')) {
      final data = UriData.parse(path);
      return data.mimeType;
    }
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lower.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
      return 'audio/mp4';
    }
    if (lower.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    return _mimeType;
  }

  void _startAmplitudeMonitor() {
    _levelNotifier.value = 0;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _record
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amplitude) {
      _levelNotifier.value = _normalizeAmplitude(amplitude.current);
    });
  }

  Future<void> _stopAmplitudeMonitor() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _levelNotifier.value = 0;
  }

  double _normalizeAmplitude(double currentDb) {
    const minDb = -60.0;
    const maxDb = 0.0;
    if (currentDb <= minDb) {
      return 0.0;
    }
    if (currentDb >= maxDb) {
      return 1.0;
    }
    return (currentDb - minDb) / (maxDb - minDb);
  }

  String _mimeTypeForEncoder(rec.AudioEncoder encoder) {
    if (encoder == rec.AudioEncoder.wav) {
      return 'audio/wav';
    }
    if (encoder == rec.AudioEncoder.flac) {
      return 'audio/flac';
    }
    if (encoder == rec.AudioEncoder.aacLc ||
        encoder == rec.AudioEncoder.aacEld ||
        encoder == rec.AudioEncoder.aacHe) {
      return 'audio/mp4';
    }
    if (encoder == rec.AudioEncoder.opus) {
      return 'audio/webm';
    }
    return 'audio/webm';
  }

  String _suggestedFilename(String mimeType) {
    final extension = _extensionForMime(mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'recording_$timestamp.$extension';
  }

  String _extensionForMime(String mimeType) {
    switch (mimeType) {
      case 'audio/wav':
        return 'wav';
      case 'audio/flac':
        return 'flac';
      case 'audio/mp4':
        return 'm4a';
      case 'audio/ogg':
        return 'ogg';
      default:
        return 'webm';
    }
  }
}
