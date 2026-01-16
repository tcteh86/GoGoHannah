import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _WebAudioRecorder();

class _WebAudioRecorder implements AudioRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  final List<html.Blob> _chunks = [];
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> start() async {
    if (_isRecording) {
      return;
    }
    _chunks.clear();
    _stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'audio': true});
    _recorder = html.MediaRecorder(_stream!);
    _recorder!.onDataAvailable.listen((event) {
      if (event.data != null) {
        _chunks.add(event.data!);
      }
    });
    _recorder!.start();
    _isRecording = true;
  }

  @override
  Future<AudioRecording> stop() async {
    if (!_isRecording || _recorder == null) {
      throw StateError('Recorder is not running.');
    }
    final recorder = _recorder!;
    final completer = Completer<AudioRecording>();

    recorder.onStop.first.then((_) async {
      _isRecording = false;
      final blob = html.Blob(_chunks, 'audio/webm');
      final url = html.Url.createObjectUrl(blob);
      final bytes = await _blobToBytes(blob);
      _cleanupStream();
      completer.complete(AudioRecording(
        bytes: bytes,
        mimeType: blob.type.isNotEmpty ? blob.type : 'audio/webm',
        url: url,
      ));
    });

    recorder.stop();
    return completer.future;
  }

  Future<Uint8List> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.readAsArrayBuffer(blob);
    reader.onLoad.listen((_) {
      final buffer = reader.result as ByteBuffer;
      completer.complete(Uint8List.view(buffer));
    });
    reader.onError.listen((_) {
      completer.completeError(StateError('Failed to read audio blob.'));
    });
    return completer.future;
  }

  void _cleanupStream() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
    _recorder = null;
  }
}
