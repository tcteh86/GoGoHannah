import 'story_reader_stub.dart'
    if (dart.library.html) 'story_reader_web.dart'
    if (dart.library.io) 'story_reader_io.dart';

import 'package:flutter/foundation.dart';

abstract class StoryReader {
  bool get isSpeaking;
  void speak(
    String text, {
    double rate = 1.0,
    ValueChanged<int>? onBoundary,
    VoidCallback? onEnd,
  });
  void stop();
}

StoryReader createStoryReader() => getStoryReader();
