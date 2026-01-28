import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'story_reader.dart';

StoryReader getStoryReader() => _FlutterStoryReader();

class _FlutterStoryReader implements StoryReader {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  void speak(
    String text, {
    double rate = 1.0,
    ValueChanged<int>? onBoundary,
    VoidCallback? onEnd,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _tts.stop();
    final mappedRate = ((rate - 0.25) / (1.5 - 0.25))
        .clamp(0.0, 1.0)
        .toDouble();
    if (onBoundary != null) {
      _tts.setProgressHandler((_, startOffset, __, ___) {
        onBoundary(startOffset);
      });
    }
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onEnd?.call();
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      onEnd?.call();
    });
    _isSpeaking = true;
    () async {
      await _tts.setSpeechRate(mappedRate);
      await _tts.speak(trimmed);
    }();
  }

  @override
  void stop() {
    _tts.stop();
    _isSpeaking = false;
  }
}
