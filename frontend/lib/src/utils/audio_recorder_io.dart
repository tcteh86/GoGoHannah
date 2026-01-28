import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart' as rec;

import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _RecordAudioRecorder();

class _RecordAudioRecorder implements AudioRecorder {
  final rec.AudioRecorder _record = rec.AudioRecorder();
  final ValueNotifier<double> _levelNotifier = ValueNotifier(0);
  StreamSubscription<rec.Amplitude>? _amplitudeSubscription;
  bool _isRecording = false;

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
    const config = rec.RecordConfig(encoder: rec.AudioEncoder.wav);
    final filename = _suggestedFilename('audio/wav');
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
    final file = File(path);
    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeForPath(path);
    return AudioRecording(
      bytes: bytes,
      mimeType: mimeType,
      url: file.uri.toString(),
    );
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

  String _mimeTypeForPath(String path) {
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
    return 'audio/aac';
  }

  String _suggestedFilename(String mimeType) {
    final extension = _extensionForMime(mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory.systemTemp;
    return '${dir.path}/recording_$timestamp.$extension';
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
        return 'aac';
    }
  }
}
