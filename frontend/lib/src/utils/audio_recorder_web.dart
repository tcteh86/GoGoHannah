import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:web_audio' as webaudio;

import 'package:flutter/foundation.dart';

import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _WebAudioRecorder();

class _WebAudioRecorder implements AudioRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  webaudio.AudioContext? _audioContext;
  webaudio.AnalyserNode? _analyser;
  webaudio.MediaStreamAudioSourceNode? _sourceNode;
  final List<html.Blob> _chunks = [];
  StreamSubscription<html.Event>? _dataSubscription;
  Completer<void>? _firstChunkCompleter;
  final ValueNotifier<double> _levelNotifier = ValueNotifier(0);
  Timer? _levelTimer;
  bool _isRecording = false;
  final html.EventStreamProvider<html.Event> _dataAvailableStream =
      html.EventStreamProvider<html.Event>('dataavailable');
  final html.EventStreamProvider<html.Event> _stopStream =
      html.EventStreamProvider<html.Event>('stop');

  @override
  bool get isRecording => _isRecording;

  @override
  ValueListenable<double> get levelListenable => _levelNotifier;

  @override
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
    _startLevelMonitor();
    _isRecording = true;
  }

  @override
  Future<AudioRecording> stop() async {
    if (!_isRecording || _recorder == null) {
      throw StateError('Recorder is not running.');
    }
    final recorder = _recorder!;
    final completer = Completer<AudioRecording>();
    final mimeType = _normalizeMimeType(recorder.mimeType);

    Future<void> finalizeRecording() async {
      if (completer.isCompleted) {
        return;
      }
      if (_chunks.isEmpty) {
        _cleanupStream();
        completer.completeError(
          StateError('No audio captured. Try recording again.'),
        );
        return;
      }
      final blob = html.Blob(_chunks, mimeType);
      final url = html.Url.createObjectUrl(blob);
      final bytes = await _blobToBytes(blob);
      _cleanupStream();
      completer.complete(AudioRecording(
        bytes: bytes,
        mimeType: blob.type.isNotEmpty ? blob.type : mimeType,
        url: url,
      ));
    }

    _stopStream.forTarget(recorder).first.then((_) async {
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
      await finalizeRecording();
    });

    try {
      recorder.requestData();
    } catch (_) {
      // Some browsers may not support requestData; ignore.
    }
    recorder.stop();

    _isRecording = false;
    _stopLevelMonitor();

    Future.delayed(const Duration(seconds: 2), () async {
      if (!completer.isCompleted && _chunks.isNotEmpty) {
        await finalizeRecording();
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        _isRecording = false;
        _cleanupStream();
        throw StateError('No audio captured. Try recording again.');
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
    _stopLevelMonitor();
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

  void _startLevelMonitor() {
    _levelNotifier.value = 0;
    _levelTimer?.cancel();
    try {
      _audioContext = webaudio.AudioContext();
      _analyser = _audioContext!.createAnalyser();
      _analyser!.fftSize = 2048;
      _sourceNode = _audioContext!.createMediaStreamSource(_stream!);
      _sourceNode!.connectNode(_analyser!);

      final buffer = Uint8List(_analyser!.fftSize);
      _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_analyser == null) {
          return;
        }
        _analyser!.getByteTimeDomainData(buffer);
        var sum = 0.0;
        for (final value in buffer) {
          final centered = (value - 128) / 128.0;
          sum += centered * centered;
        }
        final rms = math.sqrt(sum / buffer.length);
        final normalized = rms.clamp(0.0, 1.0);
        if (_levelNotifier.value != normalized) {
          _levelNotifier.value = normalized;
        }
      });
    } catch (_) {
      _levelNotifier.value = 0;
    }
  }

  void _stopLevelMonitor() {
    _levelTimer?.cancel();
    _levelTimer = null;
    _levelNotifier.value = 0;
    try {
      _sourceNode?.disconnect();
    } catch (_) {}
    try {
      _analyser?.disconnect();
    } catch (_) {}
    _sourceNode = null;
    _analyser = null;
    _audioContext?.close();
    _audioContext = null;
  }
}
