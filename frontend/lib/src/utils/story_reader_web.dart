import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'story_reader.dart';

StoryReader getStoryReader() => _WebStoryReader();

class _WebStoryReader implements StoryReader {
  html.SpeechSynthesisUtterance? _utterance;
  bool _isSpeaking = false;
  bool _isPaused = false;
  Timer? _fallbackTimer;
  bool _boundarySeen = false;
  bool _fallbackActive = false;
  int _fallbackIndex = 0;
  List<_WordInfo> _fallbackWords = [];
  String _fallbackText = '';
  double _fallbackRate = 1.0;
  ValueChanged<int>? _fallbackOnBoundary;

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
    utterance.lang =
        RegExp(r'[\u4e00-\u9fff]').hasMatch(trimmed) ? 'zh-CN' : 'en-US';
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
    _isPaused = false;
    html.window.speechSynthesis?.speak(utterance);
  }

  @override
  void pause() {
    if (!_isSpeaking || _isPaused) {
      return;
    }
    html.window.speechSynthesis?.pause();
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _isPaused = true;
  }

  @override
  void resume() {
    if (!_isPaused) {
      return;
    }
    html.window.speechSynthesis?.resume();
    _isPaused = false;
    final onBoundary = _fallbackOnBoundary;
    if (_fallbackActive &&
        !_boundarySeen &&
        _fallbackWords.isNotEmpty &&
        onBoundary != null) {
      _scheduleNextFallback(_fallbackText, _fallbackRate, onBoundary);
    }
  }

  @override
  void stop() {
    html.window.speechSynthesis?.cancel();
    _isSpeaking = false;
    _isPaused = false;
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
    _fallbackText = text;
    _fallbackRate = rate;
    _fallbackOnBoundary = onBoundary;
    _fallbackWords = RegExp(r"[A-Za-z']+|[\u4e00-\u9fff]|[,.!?;:]")
        .allMatches(text)
        .map((match) {
          final token = match.group(0) ?? '';
          final isPause = RegExp(r'[,.!?;:]').hasMatch(token);
          return _WordInfo(
            start: match.start,
            length: token.length,
            isPause: isPause,
          );
        })
        .toList();
    if (_fallbackWords.isEmpty) {
      _fallbackActive = false;
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
    if (_boundarySeen || !_isSpeaking || _isPaused) {
      return;
    }
    final nextIndex = _fallbackIndex + 1;
    if (nextIndex >= _fallbackWords.length) {
      return;
    }
    final currentWord = _fallbackWords[_fallbackIndex];
    final safeRate = rate.clamp(0.1, 1.0);
    final baseDuration = currentWord.isPause
        ? (420 / safeRate).round()
        : ((240 + currentWord.length * 70) / safeRate).round();
    final milliseconds = baseDuration.clamp(220, 2600);
    _fallbackTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (_boundarySeen || !_isSpeaking || _isPaused) {
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
    _fallbackText = '';
    _fallbackRate = 1.0;
    _fallbackOnBoundary = null;
  }
}

class _WordInfo {
  final int start;
  final int length;
  final bool isPause;

  _WordInfo({
    required this.start,
    required this.length,
    required this.isPause,
  });
}
