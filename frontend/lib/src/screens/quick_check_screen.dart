import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/save_exercise.dart';
import '../models/session_state.dart';
import '../models/vocab_exercise.dart';
import '../widgets/loading_view.dart';
import '../widgets/mascot_header.dart';

class QuickCheckScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String childName;
  final SessionState sessionState;

  const QuickCheckScreen({
    super.key,
    required this.apiClient,
    required this.childName,
    required this.sessionState,
  });

  @override
  State<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

class _QuickCheckScreenState extends State<QuickCheckScreen> {
  bool _loading = false;
  List<_QuickCheckItem> _items = [];
  final Map<int, String> _selectedChoices = {};
  final Map<int, bool> _answered = {};

  Future<void> _generateQuickCheck() async {
    setState(() {
      _loading = true;
      _items = [];
      _selectedChoices.clear();
      _answered.clear();
    });
    try {
      final words =
          await widget.apiClient.fetchRecommendedWords(widget.childName, 3);
      final exercises = await Future.wait(
        words.map(widget.apiClient.generateVocabExercise),
      );
      setState(() {
        _items = List.generate(
          exercises.length,
          (index) => _QuickCheckItem(word: words[index], exercise: exercises[index]),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkAnswer(int index) async {
    final item = _items[index];
    if (_answered.containsKey(index)) {
      return;
    }
    final choice = _selectedChoices[index];
    if (choice == null) {
      return;
    }
    final correct = choice == item.exercise.quizAnswer;
    setState(() {
      _answered[index] = correct;
    });
    widget.sessionState.recordAnswer(correct: correct);
    await widget.apiClient.saveExercise(
      SaveExercise(
        childName: widget.childName,
        word: item.word,
        exerciseType: 'test',
        score: correct ? 100 : 0,
        correct: correct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Check'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MascotHeader(
            childName: widget.childName,
            sessionState: widget.sessionState,
          ),
          const SizedBox(height: 16),
          const Text(
            'Try a quick quiz to check your recent words.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _generateQuickCheck,
            icon: const Icon(Icons.play_circle),
            label: const Text('Generate Quick Check'),
          ),
          const SizedBox(height: 16),
          if (_loading) const LoadingView(message: 'Preparing questions...'),
          if (!_loading && _items.isEmpty)
            const Text('Generate a quick check to start.'),
          if (_items.isNotEmpty)
            ..._items.asMap().entries.map(
                  (entry) => _QuickCheckCard(
                    index: entry.key,
                    item: entry.value,
                    selectedChoice: _selectedChoices[entry.key],
                    answered: _answered[entry.key],
                    onChoiceChanged: (value) => setState(
                      () => _selectedChoices[entry.key] = value ?? '',
                    ),
                    onCheck: () => _checkAnswer(entry.key),
                  ),
                ),
        ],
      ),
    );
  }
}

class _QuickCheckItem {
  final String word;
  final VocabExercise exercise;

  _QuickCheckItem({required this.word, required this.exercise});
}

class _QuickCheckCard extends StatelessWidget {
  final int index;
  final _QuickCheckItem item;
  final String? selectedChoice;
  final bool? answered;
  final ValueChanged<String?> onChoiceChanged;
  final VoidCallback onCheck;

  const _QuickCheckCard({
    required this.index,
    required this.item,
    required this.selectedChoice,
    required this.answered,
    required this.onChoiceChanged,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final keys = ['A', 'B', 'C'];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1}: ${item.word}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(item.exercise.quizQuestion),
            const SizedBox(height: 8),
            ...keys
                .where((key) => item.exercise.quizChoices.containsKey(key))
                .map(
                  (key) => RadioListTile<String>(
                    value: key,
                    groupValue: selectedChoice,
                    onChanged: onChoiceChanged,
                    title: Text('${key}. ${item.exercise.quizChoices[key]}'),
                  ),
                ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: selectedChoice == null ? null : onCheck,
              child: const Text('Check'),
            ),
            if (answered != null) ...[
              const SizedBox(height: 8),
              Text(
                answered! ? 'Correct! 🎉' : 'Not quite. Keep trying!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
