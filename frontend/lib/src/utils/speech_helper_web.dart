import 'dart:html' as html;

import 'speech_helper.dart';

SpeechHelper getSpeechHelper() => _WebSpeechHelper();

class _WebSpeechHelper implements SpeechHelper {
  @override
  void speak(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final utterance = html.SpeechSynthesisUtterance(trimmed);
    utterance.lang =
        RegExp(r'[\u4e00-\u9fff]').hasMatch(trimmed) ? 'zh-CN' : 'en-US';
    html.window.speechSynthesis?.cancel();
    html.window.speechSynthesis?.speak(utterance);
  }
}
