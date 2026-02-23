class DailyProgressSummary {
  final int dailyGoal;
  final int todayCompleted;
  final bool todayGoalReached;
  final int currentStreak;
  final int bestStreak;
  final List<DailyProgressEntry> history;

  DailyProgressSummary({
    required this.dailyGoal,
    required this.todayCompleted,
    required this.todayGoalReached,
    required this.currentStreak,
    required this.bestStreak,
    required this.history,
  });

  factory DailyProgressSummary.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['history'];
    final items = <DailyProgressEntry>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map<String, dynamic>) {
          items.add(DailyProgressEntry.fromJson(item));
        } else if (item is Map) {
          items.add(
            DailyProgressEntry.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return DailyProgressSummary(
      dailyGoal: (json['daily_goal'] ?? 0) is num
          ? (json['daily_goal'] as num).toInt()
          : 0,
      todayCompleted: (json['today_completed'] ?? 0) is num
          ? (json['today_completed'] as num).toInt()
          : 0,
      todayGoalReached: json['today_goal_reached'] == true,
      currentStreak: (json['current_streak'] ?? 0) is num
          ? (json['current_streak'] as num).toInt()
          : 0,
      bestStreak: (json['best_streak'] ?? 0) is num
          ? (json['best_streak'] as num).toInt()
          : 0,
      history: items,
    );
  }
}

class DailyProgressEntry {
  final String date;
  final int completed;
  final int goal;
  final bool goalReached;

  DailyProgressEntry({
    required this.date,
    required this.completed,
    required this.goal,
    required this.goalReached,
  });

  factory DailyProgressEntry.fromJson(Map<String, dynamic> json) {
    return DailyProgressEntry(
      date: json['date']?.toString() ?? '',
      completed: (json['completed'] ?? 0) is num
          ? (json['completed'] as num).toInt()
          : 0,
      goal: (json['goal'] ?? 0) is num ? (json['goal'] as num).toInt() : 0,
      goalReached: json['goal_reached'] == true,
    );
  }
}
