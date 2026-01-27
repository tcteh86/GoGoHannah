import 'package:flutter/foundation.dart';

import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _NoopAudioRecorder();

class _NoopAudioRecorder implements AudioRecorder {
  final ValueNotifier<double> _levelNotifier = ValueNotifier(0);

  @override
  bool get isRecording => false;

  @override
  ValueListenable<double> get levelListenable => _levelNotifier;

  @override
  Future<void> start() async {
    throw UnsupportedError('Audio recording is web-only for now.');
  }

  @override
  Future<AudioRecording> stop() async {
    throw UnsupportedError('Audio recording is web-only for now.');
  }
}
