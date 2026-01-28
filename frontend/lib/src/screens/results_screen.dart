import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/progress_summary.dart';
import '../models/recent_exercise.dart';
import '../models/session_state.dart';
import '../models/study_time_summary.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/mascot_header.dart';

class ResultsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String childName;
  final SessionState sessionState;

  const ResultsScreen({
    super.key,
    required this.apiClient,
    required this.childName,
    required this.sessionState,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late Future<_ResultsData> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = _loadResults();
  }

  Future<_ResultsData> _loadResults() async {
    final summary =
        await widget.apiClient.fetchProgressSummary(widget.childName);
    final recent =
        await widget.apiClient.fetchRecentExercises(widget.childName, 10);
    final date = _todayDate();
    StudyTimeSummary study;
    StudyTimeTotalSummary total;
    StudyTimeSummaryOverview summaryOverview;
    try {
      study = await widget.apiClient.fetchStudyTime(
        childName: widget.childName,
        date: date,
      );
    } catch (_) {
      study = StudyTimeSummary(date: date, totalSeconds: 0);
    }
    try {
      total = await widget.apiClient.fetchStudyTimeTotal(
        childName: widget.childName,
      );
    } catch (_) {
      total = StudyTimeTotalSummary(totalSeconds: 0);
    }
    try {
      summaryOverview = await widget.apiClient.fetchStudyTimeSummary(
        childName: widget.childName,
        date: date,
      );
    } catch (_) {
      summaryOverview = StudyTimeSummaryOverview(
        date: date,
        week: StudyTimePeriodSummary(
          startDate: date,
          endDate: date,
          totalSeconds: 0,
        ),
        month: StudyTimePeriodSummary(
          startDate: date,
          endDate: date,
          totalSeconds: 0,
        ),
      );
    }
    return _ResultsData(
      summary: summary,
      recent: recent,
      studyTime: study,
      totalTime: total,
      periodSummary: summaryOverview,
    );
  }

  void _refresh() {
    setState(() {
      _resultsFuture = _loadResults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_ResultsData>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading progress...');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorView(
              message: 'Unable to load progress.',
              onRetry: _refresh,
            );
          }
          final summary = snapshot.data!.summary;
          final recent = snapshot.data!.recent;
          final studyTime = snapshot.data!.studyTime;
          final totalTime = snapshot.data!.totalTime;
          final periodSummary = snapshot.data!.periodSummary;
          final quizScore = summary.scoresByType['quiz']?.avgScore ?? 0;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              MascotHeader(
                childName: widget.childName,
                sessionState: widget.sessionState,
              ),
              const SizedBox(height: 16),
              _MetricCard(
                title: 'Study time (${studyTime.date})',
                value: _formatDuration(studyTime.totalSeconds),
              ),
              _MetricCard(
                title: 'All-time study time',
                value: _formatDuration(totalTime.totalSeconds),
              ),
              _MetricCard(
                title:
                    'This week (${_formatDateRange(periodSummary.week.startDate, periodSummary.week.endDate)})',
                value: _formatDuration(periodSummary.week.totalSeconds),
              ),
              _MetricCard(
                title:
                    'This month (${_formatDateRange(periodSummary.month.startDate, periodSummary.month.endDate)})',
                value: _formatDuration(periodSummary.month.totalSeconds),
              ),
              _MetricCard(
                title: 'Total Exercises',
                value: summary.totalExercises.toString(),
              ),
              _MetricCard(
                title: 'Accuracy',
                value: '${(summary.accuracy * 100).toStringAsFixed(1)}%',
              ),
              _MetricCard(
                title: 'Avg Quiz Score',
                value: quizScore.toStringAsFixed(1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Words to Revisit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (summary.weakWords.isEmpty)
                const Text('Great job! No weak words yet.')
              else
                ...summary.weakWords
                    .map(
                      (word) => ListTile(
                        title: Text(word.word),
                        subtitle: Text(
                          'Avg score: ${word.avgScore.toStringAsFixed(0)} • Attempts: ${word.attempts} • Recommended to practice',
                        ),
                      ),
                    )
                    .toList(),
              const SizedBox(height: 16),
              const Text(
                'Recent Practice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const Text('No recent practice yet.')
              else
                ...recent.map(
                  (item) {
                    final status = item.correct ? 'Correct' : 'Needs work';
                    return ListTile(
                      title: Text(item.word),
                      subtitle: Text(
                        '${item.exerciseType} • Score ${item.score} • $status',
                      ),
                      trailing: Text(
                        item.createdAt,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultsData {
  final ProgressSummary summary;
  final List<RecentExercise> recent;
  final StudyTimeSummary studyTime;
  final StudyTimeTotalSummary totalTime;
  final StudyTimeSummaryOverview periodSummary;

  _ResultsData({
    required this.summary,
    required this.recent,
    required this.studyTime,
    required this.totalTime,
    required this.periodSummary,
  });
}

String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  final remainingSeconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours}h ${remainingMinutes}m';
  }
  return '${remainingMinutes}m ${remainingSeconds}s';
}

String _todayDate() {
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatDateRange(String start, String end) {
  final formattedStart = _formatCompactDate(start);
  final formattedEnd = _formatCompactDate(end);
  if (formattedStart == formattedEnd) {
    return formattedStart;
  }
  return '$formattedStart – $formattedEnd';
}

String _formatCompactDate(String rawDate) {
  final parsed = DateTime.tryParse(rawDate);
  if (parsed == null) {
    return rawDate;
  }
  return '${parsed.month}/${parsed.day}';
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
