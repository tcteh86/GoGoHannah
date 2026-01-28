import 'speech_helper.dart';

SpeechHelper getSpeechHelper() => _NoopSpeechHelper();

class _NoopSpeechHelper implements SpeechHelper {
  @override
  void speak(String text) {
    // No-op for non-web platforms until native TTS is added.
  }
}
