import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'story_reader.dart';

StoryReader getStoryReader() => _WebStoryReader();

class _WebStoryReader implements StoryReader {
  html.SpeechSynthesisUtterance? _utterance;
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
    stop();
    final utterance = html.SpeechSynthesisUtterance(trimmed);
    utterance.lang = 'en-US';
    utterance.rate = rate;
    if (onBoundary != null) {
      utterance.onBoundary.listen((event) {
        final index = event.charIndex;
        if (index != null) {
          onBoundary(index);
        }
      });
    }
    utterance.onEnd.listen((_) {
      _isSpeaking = false;
      onEnd?.call();
    });
    utterance.onError.listen((_) {
      _isSpeaking = false;
      onEnd?.call();
    });
    _utterance = utterance;
    _isSpeaking = true;
    html.window.speechSynthesis?.speak(utterance);
  }

  @override
  void stop() {
    html.window.speechSynthesis?.cancel();
    _isSpeaking = false;
    _utterance = null;
  }
}
