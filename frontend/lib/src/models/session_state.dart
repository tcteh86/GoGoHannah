import 'dart:async';

import 'package:flutter/foundation.dart';

class SessionState extends ChangeNotifier {
  final int dailyGoal;
  int dailyCompleted = 0;
  int streakCount = 0;
  bool dailyGoalReached = false;
  String mascotMessage = "Let's learn something fun today!";
  String mascotEmoji = '🦉';
  bool lastCorrect = false;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  SessionState({this.dailyGoal = 3}) {
    _stopwatch.start();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _stopwatch.elapsed.inSeconds;
      if (next != _elapsedSeconds) {
        _elapsedSeconds = next;
        notifyListeners();
      }
    });
  }

  int get elapsedSeconds => _elapsedSeconds;

  String get elapsedLabel => _formatElapsed(_elapsedSeconds);

  void recordAnswer({required bool correct}) {
    lastCorrect = correct;
    dailyCompleted += 1;

    if (correct) {
      mascotEmoji = '🎉';
      mascotMessage = 'Correct! High five!';
    } else {
      mascotEmoji = '💪';
      mascotMessage = "Keep going! You're getting stronger.";
    }

    if (!dailyGoalReached && dailyCompleted >= dailyGoal) {
      dailyGoalReached = true;
      streakCount += 1;
      mascotEmoji = '🏆';
      mascotMessage = 'Daily goal reached! You earned a badge!';
    }

    notifyListeners();
  }

  void hydrateDailyProgress({
    required int completedToday,
    required int currentStreak,
    bool? goalReached,
  }) {
    dailyCompleted = completedToday < 0 ? 0 : completedToday;
    streakCount = currentStreak < 0 ? 0 : currentStreak;
    dailyGoalReached = goalReached ?? dailyCompleted >= dailyGoal;

    if (dailyGoalReached) {
      mascotEmoji = '🏆';
      mascotMessage = 'Daily goal reached! You earned a badge!';
    } else if (dailyCompleted > 0) {
      mascotEmoji = '🦉';
      mascotMessage = 'Nice progress today! Keep going!';
    } else {
      mascotEmoji = '🦉';
      mascotMessage = "Let's learn something fun today!";
    }

    notifyListeners();
  }

  void resetDailyProgress() {
    dailyCompleted = 0;
    dailyGoalReached = false;
    mascotEmoji = '🦉';
    mascotMessage = "Let's learn something fun today!";
    notifyListeners();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    final remainingSeconds = seconds % 60;
    if (hours > 0) {
      return '${hours.toString()}:${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
