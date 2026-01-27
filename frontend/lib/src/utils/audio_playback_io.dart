import 'audio_playback.dart';

AudioPlayback getAudioPlayback() => _NoopAudioPlayback();

class _NoopAudioPlayback implements AudioPlayback {
  @override
  void playUrl(String url) {
    // No-op for non-web platforms until native audio is added.
  }
}
