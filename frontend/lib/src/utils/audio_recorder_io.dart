import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _NoopAudioRecorder();

class _NoopAudioRecorder implements AudioRecorder {
  @override
  bool get isRecording => false;

  Future<void> start() async {
    throw UnsupportedError('Audio recording is web-only for now.');
  }

  @override
  Future<AudioRecording> stop() async {
    throw UnsupportedError('Audio recording is web-only for now.');
  }
}
