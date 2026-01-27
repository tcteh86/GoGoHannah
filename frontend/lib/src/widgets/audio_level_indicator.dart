import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AudioLevelIndicator extends StatelessWidget {
  final ValueListenable<double> levelListenable;
  final double height;
  final Color color;

  const AudioLevelIndicator({
    super.key,
    required this.levelListenable,
    this.height = 32,
    this.color = const Color(0xFF7B5CFF),
  });

  @override
  Widget build(BuildContext context) {
    const barWeights = [0.35, 0.55, 0.75, 1.0, 0.75, 0.55, 0.35];
    return ValueListenableBuilder<double>(
      valueListenable: levelListenable,
      builder: (context, level, _) {
        final clamped = level.clamp(0.0, 1.0);
        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final weight in barWeights)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      height: (height - 4) * (0.2 + clamped * weight),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3 + clamped * 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
