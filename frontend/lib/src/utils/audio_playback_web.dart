import 'dart:html' as html;

import 'audio_playback.dart';

AudioPlayback getAudioPlayback() => _WebAudioPlayback();

class _WebAudioPlayback implements AudioPlayback {
  @override
  void playUrl(String url) {
    final audio = html.AudioElement(url);
    audio.play();
  }
}
