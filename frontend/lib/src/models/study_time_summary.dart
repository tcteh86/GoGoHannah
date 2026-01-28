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
