import 'speech_helper_stub.dart'
    if (dart.library.html) 'speech_helper_web.dart'
    if (dart.library.io) 'speech_helper_io.dart';

abstract class SpeechHelper {
  void speak(String text);
}

SpeechHelper createSpeechHelper() => getSpeechHelper();
