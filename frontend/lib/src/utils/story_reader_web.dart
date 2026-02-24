import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'story_reader.dart';

StoryReader getStoryReader() => _WebStoryReader();

class _WebStoryReader implements StoryReader {
  html.SpeechSynthesisUtterance? _utterance;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _isChineseUtterance = false;
  Timer? _fallbackTimer;
  bool _boundarySeen = false;
  bool _fallbackActive = false;
  int _fallbackIndex = 0;
  int _nativeTokenAnchor = -1;
  int _pendingNativeCharIndex = -1;
  List<_WordInfo> _fallbackWords = [];
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
    final chineseUtterance = RegExp(r'[\u4e00-\u9fff]').hasMatch(trimmed);
    _isChineseUtterance = chineseUtterance;
    _boundarySeen = false;
    _fallbackActive = false;
    _nativeTokenAnchor = -1;
    _pendingNativeCharIndex = -1;
    final utterance = html.SpeechSynthesisUtterance(trimmed);
    utterance.lang = chineseUtterance ? 'zh-CN' : 'en-US';
    utterance.rate = rate;
    if (onBoundary != null) {
      utterance.onBoundary.listen((event) {
        final index = event.charIndex;
        if (index != null) {
          _boundarySeen = true;
          if (!chineseUtterance) {
            _cancelFallback();
            onBoundary(index);
            return;
          }
          if (_fallbackWords.isEmpty) {
            _pendingNativeCharIndex = index;
          } else {
            _updateNativeAnchor(index);
          }
          if (!_fallbackActive) {
            _startFallback(trimmed, rate, onBoundary);
          }
        }
      });
      utterance.onStart.listen((_) {
        if (chineseUtterance) {
          _startFallback(trimmed, rate, onBoundary);
          return;
        }
        if (!_boundarySeen) {
          _startFallback(trimmed, rate, onBoundary);
        }
      });
      Timer(const Duration(milliseconds: 250), () {
        if ((!_boundarySeen || chineseUtterance) && _isSpeaking) {
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
    final canResumeFallback = _fallbackActive &&
        _fallbackWords.isNotEmpty &&
        onBoundary != null &&
        (!_boundarySeen || _isChineseUtterance);
    if (canResumeFallback) {
      _scheduleNextFallback(_fallbackRate, onBoundary);
    }
  }

  @override
  void stop() {
    html.window.speechSynthesis?.cancel();
    _isSpeaking = false;
    _isPaused = false;
    _isChineseUtterance = false;
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
    _fallbackRate = rate;
    _fallbackOnBoundary = onBoundary;
    _fallbackWords = RegExp(r"[A-Za-z0-9]+|[\u4e00-\u9fff]|[^\s]")
        .allMatches(text)
        .map((match) {
          final token = match.group(0) ?? '';
          final isPause = RegExp(r'^[^A-Za-z0-9\u4e00-\u9fff]+$').hasMatch(token);
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
    if (_pendingNativeCharIndex >= 0) {
      _updateNativeAnchor(_pendingNativeCharIndex);
      _pendingNativeCharIndex = -1;
    }
    _fallbackIndex = 0;
    onBoundary(_fallbackWords[_fallbackIndex].start);
    _scheduleNextFallback(rate, onBoundary);
  }

  void _scheduleNextFallback(double rate, ValueChanged<int> onBoundary) {
    final shouldStopForNativeBoundary = !_isChineseUtterance && _boundarySeen;
    if (shouldStopForNativeBoundary || !_isSpeaking || _isPaused) {
      return;
    }
    final nextIndex = _fallbackIndex + 1;
    if (nextIndex >= _fallbackWords.length) {
      return;
    }
    final currentWord = _fallbackWords[_fallbackIndex];
    final safeRate = rate.clamp(0.1, 1.0);
    final baseDuration = currentWord.isPause
        ? (520 / safeRate).round()
        : ((260 + currentWord.length * 80) / safeRate).round();
    var adjustedDuration = baseDuration.toDouble();
    if (_isChineseUtterance && _nativeTokenAnchor >= 0) {
      final drift = _nativeTokenAnchor - _fallbackIndex;
      if (drift > 10) {
        adjustedDuration *= 0.35;
      } else if (drift > 5) {
        adjustedDuration *= 0.50;
      } else if (drift > 2) {
        adjustedDuration *= 0.70;
      } else if (drift < -8) {
        adjustedDuration *= 1.60;
      } else if (drift < -3) {
        adjustedDuration *= 1.30;
      }
    }
    final milliseconds = adjustedDuration.round().clamp(140, 4200);
    _fallbackTimer = Timer(Duration(milliseconds: milliseconds), () {
      final shouldStop = (!_isChineseUtterance && _boundarySeen) ||
          !_isSpeaking ||
          _isPaused;
      if (shouldStop) {
        return;
      }
      _fallbackIndex = nextIndex;
      onBoundary(_fallbackWords[_fallbackIndex].start);
      _scheduleNextFallback(rate, onBoundary);
    });
  }

  void _updateNativeAnchor(int charIndex) {
    if (_fallbackWords.isEmpty) {
      _nativeTokenAnchor = -1;
      return;
    }
    var anchor = 0;
    for (var i = 0; i < _fallbackWords.length; i += 1) {
      if (_fallbackWords[i].start <= charIndex) {
        anchor = i;
      } else {
        break;
      }
    }
    _nativeTokenAnchor = anchor;
  }

  void _cancelFallback() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _fallbackActive = false;
    _fallbackWords = [];
    _fallbackIndex = 0;
    _nativeTokenAnchor = -1;
    _pendingNativeCharIndex = -1;
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
