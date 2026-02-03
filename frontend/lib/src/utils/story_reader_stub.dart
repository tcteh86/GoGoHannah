import 'story_reader.dart';

StoryReader getStoryReader() => _UnsupportedStoryReader();

class _UnsupportedStoryReader implements StoryReader {
  @override
  bool get isSpeaking => false;

  @override
  void speak(
    String text, {
    double rate = 1.0,
    ValueChanged<int>? onBoundary,
    VoidCallback? onEnd,
  }) {
    throw UnsupportedError('Story reader not supported on this platform.');
  }

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void stop() {}
}
