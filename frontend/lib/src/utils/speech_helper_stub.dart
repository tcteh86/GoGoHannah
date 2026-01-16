import 'speech_helper.dart';

SpeechHelper getSpeechHelper() => _UnsupportedSpeechHelper();

class _UnsupportedSpeechHelper implements SpeechHelper {
  @override
  void speak(String text) {
    throw UnsupportedError('Speech helper not supported on this platform.');
  }
}
