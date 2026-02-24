import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/session_state.dart';
import 'practice_screen.dart';
import 'quick_check_screen.dart';
import 'results_screen.dart';

class HomeShell extends StatefulWidget {
  final ApiClient apiClient;

  const HomeShell({super.key, required this.apiClient});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  String _childName = '';
  final TextEditingController _nameController = TextEditingController();
  SessionState? _sessionState;
  Timer? _studyTimer;
  int _lastReportedSeconds = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _studyTimer?.cancel();
    _reportStudyTime();
    _sessionState?.dispose();
    super.dispose();
  }

  void _startPractice() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (_childName.isNotEmpty && _childName != name) {
      _reportStudyTime();
    }
    setState(() {
      if (_childName != name || _sessionState == null) {
        _sessionState?.dispose();
        _sessionState = SessionState();
        _lastReportedSeconds = 0;
      }
      _childName = name;
    });
    _startStudyTimer();
    final sessionState = _sessionState;
    if (sessionState != null) {
      _hydrateSessionProgress(name, sessionState);
    }
  }

  void _startStudyTimer() {
    _studyTimer?.cancel();
    _studyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _reportStudyTime();
    });
  }

  Future<void> _reportStudyTime() async {
    final sessionState = _sessionState;
    if (sessionState == null || _childName.isEmpty) {
      return;
    }
    final elapsed = sessionState.elapsedSeconds;
    final delta = elapsed - _lastReportedSeconds;
    if (delta <= 0) {
      return;
    }
    _lastReportedSeconds = elapsed;
    try {
      await widget.apiClient.addStudyTime(
        childName: _childName,
        date: _todayDate(),
        seconds: delta,
      );
    } catch (_) {
      // Ignore reporting failures; will retry on next tick.
    }
  }

  Future<void> _hydrateSessionProgress(
    String childName,
    SessionState sessionState,
  ) async {
    try {
      final snapshot = await widget.apiClient.fetchDailyProgress(
        childName: childName,
        days: 30,
        dailyGoal: sessionState.dailyGoal,
      );
      if (!mounted || _childName != childName || _sessionState != sessionState) {
        return;
      }
      sessionState.hydrateDailyProgress(
        completedToday: snapshot.todayCompleted,
        currentStreak: snapshot.currentStreak,
        goalReached: snapshot.todayGoalReached,
      );
    } catch (_) {
      // Keep session defaults if progress sync fails.
    }
  }

  String _todayDate() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (_childName.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F4FF),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Welcome to GoGoHannah',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter your name to start your learning adventure!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _startPractice,
                  child: const Text('Start'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sessionState = _sessionState ?? SessionState();
    final screens = [
      PracticeScreen(
        apiClient: widget.apiClient,
        childName: _childName,
        sessionState: sessionState,
      ),
      ResultsScreen(
        apiClient: widget.apiClient,
        childName: _childName,
        sessionState: sessionState,
      ),
      QuickCheckScreen(
        apiClient: widget.apiClient,
        childName: _childName,
        sessionState: sessionState,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Results',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Quiz',
          ),
        ],
      ),
    );
  }
}
