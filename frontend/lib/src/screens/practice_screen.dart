import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/save_exercise.dart';
import '../models/vocab_exercise.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class PracticeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String childName;

  const PracticeScreen({
    super.key,
    required this.apiClient,
    required this.childName,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late Future<List<String>> _vocabFuture;
  String? _selectedWord;
  VocabExercise? _exercise;
  String? _selectedChoice;
  String? _feedback;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _vocabFuture = widget.apiClient.fetchDefaultVocab();
  }

  Future<void> _generateExercise() async {
    final word = _selectedWord;
    if (word == null || word.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _exercise = null;
      _selectedChoice = null;
      _feedback = null;
    });
    try {
      final exercise = await widget.apiClient.generateVocabExercise(word);
      setState(() {
        _exercise = exercise;
      });
    } catch (error) {
      setState(() {
        _feedback = 'Unable to load exercise. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkAnswer() async {
    final exercise = _exercise;
    if (exercise == null || _selectedChoice == null) {
      return;
    }
    final correct = _selectedChoice == exercise.quizAnswer;
    setState(() {
      _feedback = correct ? 'Correct! Great job!' : 'Nice try! Keep practicing.';
    });
    await widget.apiClient.saveExercise(
      SaveExercise(
        childName: widget.childName,
        word: _selectedWord ?? '',
        exerciseType: 'quiz',
        score: correct ? 100 : 0,
        correct: correct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        backgroundColor: const Color(0xFFF6F4FF),
      ),
      body: FutureBuilder<List<String>>(
        future: _vocabFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading words...');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorView(
              message: 'Unable to load vocabulary list.',
              onRetry: () {
                setState(() {
                  _vocabFuture = widget.apiClient.fetchDefaultVocab();
                });
              },
            );
          }
          final words = snapshot.data!;
          _selectedWord ??= words.isNotEmpty ? words.first : null;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Pick a word to practice:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedWord,
                items: words
                    .map(
                      (word) => DropdownMenuItem(
                        value: word,
                        child: Text(word),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedWord = value;
                  _exercise = null;
                  _feedback = null;
                  _selectedChoice = null;
                }),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _generateExercise,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Exercise'),
              ),
              const SizedBox(height: 20),
              if (_loading) const LoadingView(message: 'Creating exercise...'),
              if (_exercise != null) ...[
                _ExerciseCard(exercise: _exercise!),
                const SizedBox(height: 16),
                const Text(
                  'Choose the answer:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _AnswerChoices(
                  exercise: _exercise!,
                  selectedChoice: _selectedChoice,
                  onChanged: (value) => setState(() => _selectedChoice = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _selectedChoice == null ? null : _checkAnswer,
                  child: const Text('Check Answer'),
                ),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: 12),
                Text(
                  _feedback!,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final VocabExercise exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Definition: ${exercise.definition}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Example: ${exercise.exampleSentence}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Quiz: ${exercise.quizQuestion}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (exercise.source != null) ...[
              const SizedBox(height: 6),
              Text(
                'Source: ${exercise.source}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerChoices extends StatelessWidget {
  final VocabExercise exercise;
  final String? selectedChoice;
  final ValueChanged<String?> onChanged;

  const _AnswerChoices({
    required this.exercise,
    required this.selectedChoice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keys = ['A', 'B', 'C'];
    return Column(
      children: keys
          .where((key) => exercise.quizChoices.containsKey(key))
          .map(
            (key) => RadioListTile<String>(
              value: key,
              groupValue: selectedChoice,
              onChanged: onChanged,
              title: Text('${key}. ${exercise.quizChoices[key]}'),
            ),
          )
          .toList(),
    );
  }
}
