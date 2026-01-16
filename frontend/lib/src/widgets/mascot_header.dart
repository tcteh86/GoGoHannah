import 'package:flutter/material.dart';

import '../models/session_state.dart';

class MascotHeader extends StatelessWidget {
  final String childName;
  final SessionState sessionState;

  const MascotHeader({
    super.key,
    required this.childName,
    required this.sessionState,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionState,
      builder: (context, _) {
        final goalProgress = sessionState.dailyGoal == 0
            ? 0.0
            : (sessionState.dailyCompleted / sessionState.dailyGoal)
                .clamp(0.0, 1.0);
        return Card(
          color: const Color(0xFFF6F4FF),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    sessionState.mascotEmoji,
                    key: ValueKey(sessionState.mascotEmoji),
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi $childName!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(sessionState.mascotMessage),
                      const SizedBox(height: 12),
                      Text(
                        'Daily goal: ${sessionState.dailyCompleted}/${sessionState.dailyGoal}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: goalProgress),
                      const SizedBox(height: 8),
                      Text(
                        'Streak: ${sessionState.streakCount} day${sessionState.streakCount == 1 ? '' : 's'}',
                      ),
                      if (sessionState.dailyGoalReached) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Badge unlocked: Word Explorer 🏅',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
