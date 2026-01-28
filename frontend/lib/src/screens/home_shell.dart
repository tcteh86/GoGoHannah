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

  @override
  void dispose() {
    _nameController.dispose();
    _sessionState?.dispose();
    super.dispose();
  }

  void _startPractice() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      if (_childName != name || _sessionState == null) {
        _sessionState?.dispose();
        _sessionState = SessionState();
      }
      _childName = name;
    });
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
            label: 'Quick Check',
          ),
        ],
      ),
    );
  }
}
