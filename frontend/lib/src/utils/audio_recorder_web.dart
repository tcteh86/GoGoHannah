import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _WebAudioRecorder();

class _WebAudioRecorder implements AudioRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  final List<html.Blob> _chunks = [];
  StreamSubscription<html.Event>? _dataSubscription;
  Completer<void>? _firstChunkCompleter;
  bool _isRecording = false;
  final html.EventStreamProvider<html.Event> _dataAvailableStream =
      html.EventStreamProvider<html.Event>('dataavailable');
  final html.EventStreamProvider<html.Event> _stopStream =
      html.EventStreamProvider<html.Event>('stop');

  @override
  bool get isRecording => _isRecording;

  Future<void> start() async {
    if (_isRecording) {
      return;
    }
    _chunks.clear();
    _firstChunkCompleter = Completer<void>();
    _stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'audio': true});
    _recorder = html.MediaRecorder(_stream!);
    _dataSubscription?.cancel();
    _dataSubscription = _dataAvailableStream.forTarget(_recorder!).listen((event) {
      final data = (event as dynamic).data;
      if (data is html.Blob && data.size > 0) {
        _chunks.add(data);
        final completer = _firstChunkCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
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

    _stopStream.forTarget(recorder).first.then((_) async {
      _isRecording = false;
      if (_chunks.isEmpty) {
        final completer = _firstChunkCompleter;
        if (completer != null && !completer.isCompleted) {
          try {
            await completer.future.timeout(const Duration(seconds: 1));
          } catch (_) {
            // Ignore timeout while waiting for final chunk.
          }
        }
      }
      if (_chunks.isEmpty) {
        _cleanupStream();
        completer.completeError(StateError('No audio captured. Try recording again.'));
        return;
      }
      final mimeType = _normalizeMimeType(recorder.mimeType);
      final blob = html.Blob(_chunks, mimeType);
      final url = html.Url.createObjectUrl(blob);
      final bytes = await _blobToBytes(blob);
      _cleanupStream();
      completer.complete(AudioRecording(
        bytes: bytes,
        mimeType: blob.type.isNotEmpty ? blob.type : mimeType,
        url: url,
      ));
    });

    try {
      recorder.requestData();
    } catch (_) {
      // Some browsers may not support requestData; ignore.
    }
    recorder.stop();

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _isRecording = false;
        _cleanupStream();
        throw StateError('Recording timed out.');
      },
    );
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
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _firstChunkCompleter = null;
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
    _recorder = null;
  }

  String _normalizeMimeType(String? mimeType) {
    final value = (mimeType ?? '').trim();
    if (value.isEmpty) {
      return 'audio/webm';
    }
    return value;
  }

}
