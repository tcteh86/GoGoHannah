import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'story_reader.dart';

StoryReader getStoryReader() => _WebStoryReader();

class _WebStoryReader implements StoryReader {
  html.SpeechSynthesisUtterance? _utterance;
  bool _isSpeaking = false;
  Timer? _fallbackTimer;
  bool _boundarySeen = false;
  bool _fallbackActive = false;
  int _fallbackIndex = 0;
  List<_WordInfo> _fallbackWords = [];

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
    _boundarySeen = false;
    _fallbackActive = false;
    final utterance = html.SpeechSynthesisUtterance(trimmed);
    utterance.lang = 'en-US';
    utterance.rate = rate;
    if (onBoundary != null) {
      utterance.onBoundary.listen((event) {
        final index = event.charIndex;
        if (index != null) {
          _boundarySeen = true;
          _cancelFallback();
          onBoundary(index);
        }
      });
      utterance.onStart.listen((_) {
        if (!_boundarySeen) {
          _startFallback(trimmed, rate, onBoundary);
        }
      });
      Timer(const Duration(milliseconds: 250), () {
        if (!_boundarySeen && _isSpeaking) {
          _startFallback(trimmed, rate, onBoundary);
        }
      });
    }
    utterance.onEnd.listen((_) {
      _isSpeaking = false;
      _cancelFallback();
      onEnd?.call();
    });
    utterance.onError.listen((_) {
      _isSpeaking = false;
      _cancelFallback();
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
    _cancelFallback();
  }

  void _startFallback(
    String text,
    double rate,
    ValueChanged<int> onBoundary,
  ) {
    if (_fallbackActive) {
      return;
    }
    _fallbackActive = true;
    _fallbackWords = RegExp(r"[A-Za-z']+")
        .allMatches(text)
        .map((match) => _WordInfo(match.start, match.group(0)?.length ?? 0))
        .toList();
    if (_fallbackWords.isEmpty) {
      return;
    }
    _fallbackIndex = 0;
    onBoundary(_fallbackWords[_fallbackIndex].start);
    _scheduleNextFallback(text, rate, onBoundary);
  }

  void _scheduleNextFallback(
    String text,
    double rate,
    ValueChanged<int> onBoundary,
  ) {
    if (_boundarySeen || !_isSpeaking) {
      return;
    }
    final nextIndex = _fallbackIndex + 1;
    if (nextIndex >= _fallbackWords.length) {
      return;
    }
    final currentLength = _fallbackWords[_fallbackIndex].length;
    final milliseconds =
        ((160 + currentLength * 35) / rate.clamp(0.25, 1.5))
            .round()
            .clamp(140, 700);
    _fallbackTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (_boundarySeen || !_isSpeaking) {
        return;
      }
      _fallbackIndex = nextIndex;
      onBoundary(_fallbackWords[_fallbackIndex].start);
      _scheduleNextFallback(text, rate, onBoundary);
    });
  }

  void _cancelFallback() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _fallbackActive = false;
    _fallbackWords = [];
    _fallbackIndex = 0;
  }
}

class _WordInfo {
  final int start;
  final int length;

  _WordInfo(this.start, this.length);
}
