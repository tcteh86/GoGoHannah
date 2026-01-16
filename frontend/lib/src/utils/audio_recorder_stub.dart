import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _UnsupportedAudioRecorder();

class _UnsupportedAudioRecorder implements AudioRecorder {
  @override
  bool get isRecording => false;

  @override
  Future<void> start() async {
    throw UnsupportedError('Audio recording not supported on this platform.');
  }

  @override
  Future<AudioRecording> stop() async {
    throw UnsupportedError('Audio recording not supported on this platform.');
  }
}
