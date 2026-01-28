class StudyTimeSummary {
  final String date;
  final int totalSeconds;

  StudyTimeSummary({required this.date, required this.totalSeconds});

  factory StudyTimeSummary.fromJson(Map<String, dynamic> json) {
    return StudyTimeSummary(
      date: json['date']?.toString() ?? '',
      totalSeconds: (json['total_seconds'] ?? 0) is num
          ? (json['total_seconds'] as num).toInt()
          : 0,
    );
  }
}

class StudyTimeTotalSummary {
  final int totalSeconds;

  StudyTimeTotalSummary({required this.totalSeconds});

  factory StudyTimeTotalSummary.fromJson(Map<String, dynamic> json) {
    return StudyTimeTotalSummary(
      totalSeconds: (json['total_seconds'] ?? 0) is num
          ? (json['total_seconds'] as num).toInt()
          : 0,
    );
  }
}

class StudyTimePeriodSummary {
  final String startDate;
  final String endDate;
  final int totalSeconds;

  StudyTimePeriodSummary({
    required this.startDate,
    required this.endDate,
    required this.totalSeconds,
  });

  factory StudyTimePeriodSummary.fromJson(Map<String, dynamic> json) {
    return StudyTimePeriodSummary(
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      totalSeconds: (json['total_seconds'] ?? 0) is num
          ? (json['total_seconds'] as num).toInt()
          : 0,
    );
  }
}

class StudyTimeSummaryOverview {
  final String date;
  final StudyTimePeriodSummary week;
  final StudyTimePeriodSummary month;

  StudyTimeSummaryOverview({
    required this.date,
    required this.week,
    required this.month,
  });

  factory StudyTimeSummaryOverview.fromJson(Map<String, dynamic> json) {
    final weekRaw = json['week'];
    final monthRaw = json['month'];
    return StudyTimeSummaryOverview(
      date: json['date']?.toString() ?? '',
      week: weekRaw is Map<String, dynamic>
          ? StudyTimePeriodSummary.fromJson(weekRaw)
          : StudyTimePeriodSummary.fromJson(
              (weekRaw as Map).map((key, value) => MapEntry(key.toString(), value)),
            ),
      month: monthRaw is Map<String, dynamic>
          ? StudyTimePeriodSummary.fromJson(monthRaw)
          : StudyTimePeriodSummary.fromJson(
              (monthRaw as Map).map((key, value) => MapEntry(key.toString(), value)),
            ),
    );
  }
}
