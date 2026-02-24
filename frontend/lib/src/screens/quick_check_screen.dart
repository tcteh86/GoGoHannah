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
  String? _error;
  bool _showChinese = false;
  List<_QuickCheckItem> _items = [];
  final Map<int, String> _selectedChoices = {};
  final Map<int, bool> _answered = {};

  Future<void> _generateQuickCheck() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _selectedChoices.clear();
      _answered.clear();
    });
    try {
      final words =
          await widget.apiClient.fetchRecommendedWords(widget.childName, 3);
      if (words.isEmpty) {
        setState(() {
          _error = 'No recommended words yet. Try some practice first.';
          _items = [];
        });
        return;
      }
      final exercises = await Future.wait(
        words.map(
          (word) => widget.apiClient.generateVocabExercise(
            word,
            learningDirection: 'en_to_zh',
            outputStyle: 'bilingual',
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = List.generate(
          exercises.length,
          (index) => _QuickCheckItem(word: words[index], exercise: exercises[index]),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to prepare quiz right now. ${error.toString()}';
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
    if (choice == null || choice.isEmpty) {
      return;
    }
    final correct = choice == item.exercise.quizAnswer;
    setState(() {
      _answered[index] = correct;
    });
    widget.sessionState.recordAnswer(correct: correct);
    try {
      await widget.apiClient.saveExercise(
        SaveExercise(
          childName: widget.childName,
          word: item.word,
          exerciseType: 'quiz',
          score: correct ? 100 : 0,
          correct: correct,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved locally, but failed to sync: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
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
            'Take a short quiz to review recent words.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('English'),
                icon: Icon(Icons.translate),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('English + 中文'),
                icon: Icon(Icons.language),
              ),
            ],
            selected: {_showChinese},
            onSelectionChanged: (selection) {
              setState(() => _showChinese = selection.first);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _generateQuickCheck,
            icon: const Icon(Icons.play_circle),
            label: const Text('Generate Quiz'),
          ),
          const SizedBox(height: 16),
          if (_loading) const LoadingView(message: 'Preparing questions...'),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
          ],
          if (!_loading && _items.isEmpty)
            const Text('Generate a quiz to start.'),
          if (_items.isNotEmpty)
            ..._items.asMap().entries.map(
                  (entry) => _QuickCheckCard(
                    index: entry.key,
                    item: entry.value,
                    selectedChoice: _selectedChoices[entry.key],
                    answered: _answered[entry.key],
                    showChinese: _showChinese,
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
  final bool showChinese;
  final ValueChanged<String?> onChoiceChanged;
  final VoidCallback onCheck;

  const _QuickCheckCard({
    required this.index,
    required this.item,
    required this.selectedChoice,
    required this.answered,
    required this.showChinese,
    required this.onChoiceChanged,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final keys = ['A', 'B', 'C'];
    final questionLines = _splitBilingualLines(item.exercise.quizQuestion);
    final questionEn = (questionLines.english ?? item.exercise.quizQuestion).trim();
    final questionZh = questionLines.chinese?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quiz ${index + 1}: ${item.word}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(questionEn),
            if (showChinese && questionZh != null && questionZh.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                questionZh,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
            const SizedBox(height: 8),
            ...keys
                .where((key) => item.exercise.quizChoices.containsKey(key))
                .map(
                  (key) {
                    final rawChoice = item.exercise.quizChoices[key] ?? '';
                    final choiceLines = _splitBilingualLines(rawChoice);
                    final choiceEn = (choiceLines.english ?? rawChoice).trim();
                    final choiceZh = choiceLines.chinese?.trim();
                    return RadioListTile<String>(
                      value: key,
                      groupValue: selectedChoice,
                      onChanged: answered != null ? null : onChoiceChanged,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$key. $choiceEn'),
                          if (showChinese &&
                              choiceZh != null &&
                              choiceZh.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              choiceZh,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed:
                  selectedChoice == null || answered != null ? null : onCheck,
              child: const Text('Check Answer'),
            ),
            if (answered != null) ...[
              const SizedBox(height: 8),
              Text(
                answered! ? 'Correct! 🎉\n答对了！' : 'Not quite. Keep trying!\n还差一点，再试试！',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!answered!) ...[
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final answerKey = item.exercise.quizAnswer;
                    final rawAnswer = item.exercise.quizChoices[answerKey] ?? '';
                    final answerLines = _splitBilingualLines(rawAnswer);
                    final answerEn = (answerLines.english ?? rawAnswer).trim();
                    final answerZh = answerLines.chinese?.trim();
                    return Text(
                      showChinese && answerZh != null && answerZh.isNotEmpty
                          ? 'Correct answer: $answerKey. $answerEn\n正确答案：$answerZh'
                          : 'Correct answer: $answerKey. $answerEn',
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

_BilingualLines _splitBilingualLines(String text) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return const _BilingualLines();
  }
  String? english;
  String? chinese;
  for (final line in lines) {
    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(line);
    if (containsChinese) {
      chinese ??= line;
    } else {
      english ??= line;
    }
  }
  if (english == null && lines.isNotEmpty) {
    english = lines.first;
  }
  if (chinese == null && lines.length > 1) {
    chinese = lines.last;
  }
  return _BilingualLines(
    english: english,
    chinese: chinese,
  );
}

class _BilingualLines {
  final String? english;
  final String? chinese;

  const _BilingualLines({this.english, this.chinese});
}
