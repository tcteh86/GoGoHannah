import 'audio_playback.dart';

AudioPlayback getAudioPlayback() => _UnsupportedPlayback();

class _UnsupportedPlayback implements AudioPlayback {
  @override
  void playUrl(String url) {
    throw UnsupportedError('Audio playback not supported on this platform.');
  }
}
