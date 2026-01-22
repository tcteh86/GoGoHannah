import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class RecordedAudioPlayerImpl extends StatefulWidget {
  final String url;

  const RecordedAudioPlayerImpl({super.key, required this.url});

  @override
  State<RecordedAudioPlayerImpl> createState() =>
      _RecordedAudioPlayerImplState();
}

class _RecordedAudioPlayerImplState extends State<RecordedAudioPlayerImpl> {
  late final String _viewType;
  late final html.AudioElement _audioElement;

  @override
  void initState() {
    super.initState();
    _viewType =
        'recorded-audio-${DateTime.now().microsecondsSinceEpoch}-${widget.url.hashCode}';
    _audioElement = html.AudioElement()
      ..src = widget.url
      ..controls = true
      ..style.width = '100%';
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _audioElement,
    );
  }

  @override
  void didUpdateWidget(covariant RecordedAudioPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _audioElement.src = widget.url;
    }
  }

  @override
  void dispose() {
    _audioElement.src = '';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
