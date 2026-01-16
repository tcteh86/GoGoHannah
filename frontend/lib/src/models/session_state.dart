import 'package:flutter/foundation.dart';

class SessionState extends ChangeNotifier {
  final int dailyGoal;
  int dailyCompleted = 0;
  int streakCount = 0;
  bool dailyGoalReached = false;
  String mascotMessage = "Let's learn something fun today!";
  String mascotEmoji = '🦉';
  bool lastCorrect = false;

  SessionState({this.dailyGoal = 3});

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

  void resetDailyProgress() {
    dailyCompleted = 0;
    dailyGoalReached = false;
    mascotEmoji = '🦉';
    mascotMessage = "Let's learn something fun today!";
    notifyListeners();
  }
}
