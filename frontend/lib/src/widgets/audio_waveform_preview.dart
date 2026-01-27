import 'package:flutter/material.dart';

class AudioWaveformPreview extends StatelessWidget {
  final List<double> levels;
  final double height;
  final Color color;

  const AudioWaveformPreview({
    super.key,
    required this.levels,
    this.height = 44,
    this.color = const Color(0xFF7B5CFF),
  });

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(levels: levels, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color color;

  _WaveformPainter({required this.levels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    final maxAmp = size.height / 2;
    final step = levels.length > 1 ? size.width / (levels.length - 1) : size.width;

    for (var i = 0; i < levels.length; i += 1) {
      final value = levels[i].clamp(0.0, 1.0);
      final amplitude = (0.15 + value * 0.85) * maxAmp;
      final x = step * i;
      canvas.drawLine(
        Offset(x, midY - amplitude),
        Offset(x, midY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.levels != levels || oldDelegate.color != color;
  }
}
