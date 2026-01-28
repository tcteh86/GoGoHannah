import 'story_reader.dart';

StoryReader getStoryReader() => _NoopStoryReader();

class _NoopStoryReader implements StoryReader {
  @override
  bool get isSpeaking => false;

  @override
  void speak(
    String text, {
    double rate = 1.0,
    ValueChanged<int>? onBoundary,
    VoidCallback? onEnd,
  }) {
    onEnd?.call();
  }

  @override
  void stop() {}
}
