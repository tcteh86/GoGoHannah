import 'audio_playback_stub.dart'
    if (dart.library.html) 'audio_playback_web.dart'
    if (dart.library.io) 'audio_playback_io.dart';

abstract class AudioPlayback {
  void playUrl(String url);
}

AudioPlayback createAudioPlayback() => getAudioPlayback();
