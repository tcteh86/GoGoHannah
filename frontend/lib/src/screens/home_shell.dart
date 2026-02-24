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



  Future<void> _runDataAction(
    String successMessage,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $error')),
      );
    }
  }

  Future<void> _showDataToolsSheet() async {
    final childName = (_childName.isNotEmpty
            ? _childName
            : _nameController.text.trim())
        .trim();
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Data Tools',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Backup/restore progress and import/export vocabulary.'),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export Progress Backup (.db)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _runDataAction(
                    'Progress backup downloaded.',
                    () => widget.apiClient.exportProgressDb(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Import Progress Backup (.db)'),
                subtitle: const Text('Replaces current database.'),
                onTap: () {
                  Navigator.of(context).pop();
                  _runDataAction(
                    'Progress backup imported.',
                    () => widget.apiClient.importProgressDbFromPicker(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Export Progress Report (.csv)'),
                enabled: childName.isNotEmpty,
                subtitle: childName.isEmpty
                    ? const Text('Enter child name first.')
                    : Text('Child: $childName'),
                onTap: childName.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _runDataAction(
                          'Progress report downloaded.',
                          () => widget.apiClient.exportProgressReportCsv(
                            childName: childName,
                          ),
                        );
                      },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Export Vocabulary (.csv)'),
                enabled: childName.isNotEmpty,
                subtitle: childName.isEmpty
                    ? const Text('Enter child name first.')
                    : Text('Child: $childName'),
                onTap: childName.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _runDataAction(
                          'Vocabulary exported.',
                          () => widget.apiClient.exportCustomVocabCsv(
                            childName: childName,
                          ),
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Import Vocabulary (.csv, append)'),
                enabled: childName.isNotEmpty,
                onTap: childName.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _runDataAction(
                          'Vocabulary imported (append).',
                          () => widget.apiClient.importCustomVocabCsvFromPicker(
                            childName: childName,
                            mode: 'append',
                          ),
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.restore_page_outlined),
                title: const Text('Import Vocabulary (.csv, replace)'),
                subtitle: const Text('Replaces existing custom vocabulary.'),
                enabled: childName.isNotEmpty,
                onTap: childName.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _runDataAction(
                          'Vocabulary imported (replace).',
                          () => widget.apiClient.importCustomVocabCsvFromPicker(
                            childName: childName,
                            mode: 'replace',
                          ),
                        );
                      },
              ),
            ],
          ),
        );
      },
    );
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
      QuickCheckScreen(
        apiClient: widget.apiClient,
        childName: _childName,
        sessionState: sessionState,
      ),
      ResultsScreen(
        apiClient: widget.apiClient,
        childName: _childName,
        sessionState: sessionState,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('GoGoHannah - $_childName'),
        actions: [
          IconButton(
            tooltip: 'Data Tools',
            icon: const Icon(Icons.storage_outlined),
            onPressed: _showDataToolsSheet,
          ),
        ],
      ),
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
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Quiz',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Results',
          ),
        ],
      ),
    );
  }
}
