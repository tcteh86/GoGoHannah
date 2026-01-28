import 'audio_recorder_stub.dart'
    if (dart.library.html) 'audio_recorder_web.dart'
    if (dart.library.io) 'audio_recorder_io.dart';

import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class AudioRecording {
  final Uint8List bytes;
  final String mimeType;
  final String url;

  AudioRecording({
    required this.bytes,
    required this.mimeType,
    required this.url,
  });
}

abstract class AudioRecorder {
  bool get isRecording;
  ValueListenable<double> get levelListenable;
  Future<void> start();
  Future<AudioRecording> stop();
}

AudioRecorder createAudioRecorder() => getAudioRecorder();
