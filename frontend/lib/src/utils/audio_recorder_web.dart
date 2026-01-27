import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:web_audio' as webaudio;

import 'package:flutter/foundation.dart';

import 'audio_recorder.dart';

AudioRecorder getAudioRecorder() => _WebAudioRecorder();

/// `dart:html` does not expose MediaRecorder's `ondataavailable` / `onstop`
/// as typed getters in all SDK versions. Bind via DOM event names instead.
const _onDataAvailable = html.EventStreamProvider<html.Event>('dataavailable');
const _onStop = html.EventStreamProvider<html.Event>('stop');

class _WebAudioRecorder implements AudioRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  webaudio.AudioContext? _audioContext;
  webaudio.AnalyserNode? _analyser;
  webaudio.MediaStreamAudioSourceNode? _sourceNode;

  final List<html.Blob> _chunks = [];
  Completer<void>? _firstDataEventCompleter;

  final ValueNotifier<double> _levelNotifier = ValueNotifier(0);
  Timer? _levelTimer;

  bool _isRecording = false;
  StreamSubscription<html.Event>? _dataSubscription;

  @override
  bool get isRecording => _isRecording;

  @override
  ValueListenable<double> get levelListenable => _levelNotifier;

  @override
  Future<void> start() async {
    if (_isRecording) return;

    _chunks.clear();
    _firstDataEventCompleter = Completer<void>();

    // NOTE: getUserMedia requires HTTPS (or localhost) and a user gesture.
    _stream =
        await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});

    html.MediaRecorder recorder;
    try {
      recorder = html.MediaRecorder(_stream!);
    } catch (_) {
      final options = _recorderOptions();
      recorder = options == null
          ? html.MediaRecorder(_stream!)
          : html.MediaRecorder(_stream!, options);
    }

    _recorder = recorder;

    // Listen for chunks via DOM events.
    _dataSubscription?.cancel();
    _dataSubscription = _onDataAvailable.forTarget(recorder).listen((event) {
      final dynamic blobEvent = event;
      final dynamic data = blobEvent.data;

      if (data is html.Blob) {
        // Some browsers emit an empty Blob first; signal that we've received
        // at least one dataavailable event (even if empty).
        final c = _firstDataEventCompleter;
        if (c != null && !c.isCompleted) c.complete();

        // Only store non-empty chunks
        if (data.size > 0) {
          _chunks.add(data);
        }
      }
    });

    // ✅ IMPORTANT FIX:
    // Provide a timeslice so dataavailable fires periodically (not only at stop).
    // This avoids "_chunks is empty" in many environments.
    recorder.start(250); // 250ms chunks (tune 100-500ms as you like)

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
      if (completer.isCompleted) return;

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

    const chunkTimeout = Duration(seconds: 4);

    _onStop.forTarget(recorder).first.then((_) async {
      // Give the browser a moment to flush final dataavailable
      // (some browsers fire stop slightly before the last chunk is observed).
      await Future.delayed(const Duration(milliseconds: 150));

      // If nothing captured yet, wait briefly for at least one dataavailable event.
      if (_chunks.isEmpty) {
        await _waitForFirstDataEvent(chunkTimeout);
        // Another tiny delay to allow chunk list to fill
        await Future.delayed(const Duration(milliseconds: 150));
      }

      await finalizeRecording();
    });

    // ✅ IMPORTANT FIX:
    // Don't force requestData() right before stop; it can be flaky and isn't
    // needed once we start with a timeslice.
    recorder.stop();

    _isRecording = false;
    _stopLevelMonitor();

    // Fallback: if stop event is delayed
    Future.delayed(chunkTimeout, () async {
      if (completer.isCompleted) return;

      if (_chunks.isEmpty) {
        await _waitForFirstDataEvent(chunkTimeout);
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (!completer.isCompleted) {
        await finalizeRecording();
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 12),
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
    _firstDataEventCompleter = null;

    _stopLevelMonitor();

    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
    _recorder = null;
  }

  String _normalizeMimeType(String? mimeType) {
    final value = (mimeType ?? '').trim();
    if (value.isEmpty) return 'audio/webm';
    return value;
  }

  Map<String, String>? _recorderOptions() {
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
      'audio/mp4',
    ];
    for (final mimeType in candidates) {
      if (html.MediaRecorder.isTypeSupported(mimeType)) {
        return {'mimeType': mimeType};
      }
    }
    return null;
  }

  Future<void> _waitForFirstDataEvent(Duration timeout) async {
    final completer = _firstDataEventCompleter;
    if (completer == null || completer.isCompleted) return;

    try {
      await completer.future.timeout(timeout);
    } catch (_) {
      // Ignore timeout while waiting for first dataavailable event.
    }
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

      final fftSize = _analyser?.fftSize ?? 2048;
      final buffer = Uint8List(fftSize);

      _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final analyser = _analyser;
        if (analyser == null) return;

        analyser.getByteTimeDomainData(buffer);

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
