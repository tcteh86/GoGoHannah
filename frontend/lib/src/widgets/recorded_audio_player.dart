import 'package:flutter/widgets.dart';

import 'recorded_audio_player_stub.dart'
    if (dart.library.html) 'recorded_audio_player_web.dart' as impl;

class RecordedAudioPlayer extends StatelessWidget {
  final String url;

  const RecordedAudioPlayer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return impl.RecordedAudioPlayerImpl(key: key, url: url);
  }
}

