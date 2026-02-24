import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/comprehension_exercise.dart';
import '../models/save_exercise.dart';
import '../models/session_state.dart';
import '../models/vocab_exercise.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/mascot_header.dart';
import '../widgets/audio_level_indicator.dart';
import '../widgets/audio_waveform_preview.dart';
import '../utils/speech_helper.dart';
import '../utils/audio_recorder.dart';
import '../utils/audio_playback.dart';
import '../utils/story_reader.dart';

enum PracticeMode { vocabulary, comprehension }

enum VocabListSource { defaultList, customList, weakList }

enum ReadMode { continuous, lineByLine }

enum ReadLanguage { english, chinese }

const bool _ragDebugEnabled =
    bool.fromEnvironment('GOGOHANNAH_DEBUG', defaultValue: false);

class PracticeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String childName;
  final SessionState sessionState;

  const PracticeScreen({
    super.key,
    required this.apiClient,
    required this.childName,
    required this.sessionState,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late Future<List<String>> _wordListFuture;
  VocabListSource _vocabSource = VocabListSource.defaultList;
  final TextEditingController _customWordsController =
      TextEditingController();
  bool _addingCustom = false;
  String? _customError;
  String _customAddMode = 'append';
  String? _selectedWord;
  VocabExercise? _exercise;
  String? _feedback;
  bool _loading = false;
  bool _showDefinitionChinese = false;
  bool _showExampleChinese = false;
  int _quizVariantSeed = 0;
  bool _exerciseSaved = false;
  final List<_QuizPrompt> _quizPrompts = [];
  final Map<int, String> _quizSelections = {};
  final Map<int, bool> _quizResults = {};
  final Map<int, String> _quizFeedback = {};
  String? _vocabHintImageUrl;
  String? _vocabHintError;
  bool _vocabHintLoading = false;

  PracticeMode _mode = PracticeMode.vocabulary;
  ComprehensionExercise? _comprehension;
  String? _comprehensionError;
  bool _loadingComprehension = false;
  String _storyLevel = 'beginner';
  bool _showStoryChinese = false;
  int? _activeClueBlockIndex;
  final Set<int> _revealedStoryBlockChinese = {};
  int? _autoRevealedStoryBlockChinese;
  final String _outputStyleValue = 'bilingual';
  ReadMode _readMode = ReadMode.continuous;
  ReadLanguage _readLanguage = ReadLanguage.english;
  bool _storyPaused = false;
  int _storyLineIndex = 0;
  final Map<int, String> _compChoices = {};
  final Map<int, bool> _compAnswered = {};
  final Map<int, String> _compFeedback = {};

  AudioRecording? _recording;
  int? _pronunciationScore;
  String? _pronunciationTranscript;
  String? _pronunciationFeedback;
  bool _pronunciationLoading = false;
  String? _lastAutoPlayedWord;
  final SpeechHelper _speechHelper = createSpeechHelper();
  final StoryReader _storyReader = createStoryReader();
  final AudioRecorder _audioRecorder = createAudioRecorder();
  final AudioPlayback _audioPlayback = createAudioPlayback();
  final ValueNotifier<List<double>> _waveformNotifier = ValueNotifier([]);
  late final VoidCallback _waveformListener;
  bool _ragDebugLoading = false;
  double _storyRate = 1.0;
  bool _storySpeaking = false;
  _StoryHighlightRange? _highlightedRange;
  List<_StoryLine> _storyLines = [];
  List<_StoryToken> _storyTokens = [];
  List<int> _storySpokenIndexMap = [];

  @override
  void initState() {
    super.initState();
    _waveformListener = () {
      if (!_audioRecorder.isRecording) {
        return;
      }
      final updated = List<double>.from(_waveformNotifier.value);
      updated.add(_audioRecorder.levelListenable.value);
      if (updated.length > 60) {
        updated.removeAt(0);
      }
      _waveformNotifier.value = updated;
    };
    _audioRecorder.levelListenable.addListener(_waveformListener);
    _wordListFuture = _fetchWordList();
  }

  @override
  void dispose() {
    _audioRecorder.levelListenable.removeListener(_waveformListener);
    _waveformNotifier.dispose();
    _storyReader.stop();
    _customWordsController.dispose();
    super.dispose();
  }

  Future<void> _generateExercise(List<String> wordPool) async {
    final word = _selectedWord;
    if (word == null || word.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _exercise = null;
      _feedback = null;
      _vocabHintImageUrl = null;
      _vocabHintError = null;
      _vocabHintLoading = false;
      _showDefinitionChinese = false;
      _showExampleChinese = false;
      _exerciseSaved = false;
      _quizPrompts.clear();
      _quizSelections.clear();
      _quizResults.clear();
      _quizFeedback.clear();
    });
    try {
      final exercise = await widget.apiClient.generateVocabExercise(
        word,
        learningDirection: _learningDirectionValue,
        outputStyle: _outputStyleValue,
      );
      final prompts = _buildQuizPrompts(
        exercise: exercise,
        word: word,
        wordPool: wordPool,
      );
      setState(() {
        _exercise = exercise;
        _quizPrompts
          ..clear()
          ..addAll(prompts);
      });
      _maybeAutoPlayWord(word);
    } catch (error) {
      setState(() {
        _feedback = 'Unable to load exercise. ${error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _generateVocabImageHint() async {
    final exercise = _exercise;
    final word = _selectedWord;
    if (exercise == null || word == null || word.isEmpty || _vocabHintLoading) {
      return;
    }
    if (!exercise.imageHintEnabled) {
      setState(() {
        _vocabHintError = 'Abstract word cannot generate image hint.';
      });
      return;
    }
    setState(() {
      _vocabHintLoading = true;
      _vocabHintError = null;
    });
    try {
      final result = await widget.apiClient.generateVocabImageHint(
        word: word,
        definition: exercise.definition,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _vocabHintImageUrl = result.imageUrl;
        if (result.imageHintReason == 'abstract_word') {
          _vocabHintError = 'Abstract word cannot generate image hint.';
        } else if ((result.imageUrl ?? '').isEmpty) {
          _vocabHintError = 'Image hint is unavailable right now. Please retry.';
        } else {
          _vocabHintError = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _vocabHintError = 'Image hint is unavailable right now. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _vocabHintLoading = false);
      }
    }
  }

  Future<List<String>> _fetchWordList() async {
    switch (_vocabSource) {
      case VocabListSource.customList:
        return widget.apiClient.fetchCustomVocab(widget.childName);
      case VocabListSource.weakList:
        final summary =
            await widget.apiClient.fetchProgressSummary(widget.childName);
        return summary.weakWords.map((word) => word.word).toList();
      case VocabListSource.defaultList:
      default:
        return widget.apiClient.fetchDefaultVocab();
    }
  }

  void _refreshWordList() {
    setState(() {
      _wordListFuture = _fetchWordList();
      _resetPracticeState();
    });
  }

  void _resetPracticeState() {
    _exercise = null;
    _feedback = null;
    _vocabHintImageUrl = null;
    _vocabHintError = null;
    _vocabHintLoading = false;
    _showDefinitionChinese = false;
    _showExampleChinese = false;
    _exerciseSaved = false;
    _quizPrompts.clear();
    _quizSelections.clear();
    _quizResults.clear();
    _quizFeedback.clear();
    _recording = null;
    _pronunciationScore = null;
    _pronunciationTranscript = null;
    _pronunciationFeedback = null;
  }

  void _resetComprehensionState() {
    _comprehension = null;
    _comprehensionError = null;
    _compChoices.clear();
    _compAnswered.clear();
    _compFeedback.clear();
    _showStoryChinese = false;
    _activeClueBlockIndex = null;
    _revealedStoryBlockChinese.clear();
    _autoRevealedStoryBlockChinese = null;
    _highlightedRange = null;
    _storyLines = [];
    _storyTokens = [];
    _storySpokenIndexMap = [];
    _storyPaused = false;
    _storyLineIndex = 0;
  }

  List<String> _parseCustomWords(String raw) {
    final normalized = raw.replaceAll('\r', '\n');
    final tokens = <String>[];
    for (final chunk in normalized.split(',')) {
      tokens.addAll(chunk.split('\n'));
    }
    return tokens
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  Future<List<String>?> _resolveSuggestedWords(
    List<String> original,
  ) async {
    try {
      final suggested =
          await widget.apiClient.suggestCustomVocab(words: original);
      if (listEquals(original, suggested)) {
        return original;
      }
      final useSuggested = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm suggested words'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'We found possible typos. Review the suggested list:',
                    ),
                    const SizedBox(height: 12),
                    ...original.asMap().entries.map((entry) {
                      final index = entry.key;
                      final originalWord = entry.value;
                      final suggestedWord = suggested[index];
                      final changed = originalWord != suggestedWord;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          changed
                              ? '$originalWord → $suggestedWord'
                              : originalWord,
                          style: TextStyle(
                            color: changed ? Colors.deepPurple : null,
                            fontWeight:
                                changed ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep Original'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Use Suggestions'),
              ),
            ],
          );
        },
      );
      if (useSuggested == null) {
        return null;
      }
      return useSuggested ? suggested : original;
    } catch (_) {
      return original;
    }
  }

  Future<void> _addCustomWords() async {
    final words = _parseCustomWords(_customWordsController.text);
    if (words.isEmpty) {
      setState(() {
        _customError = 'Enter at least one word.';
      });
      return;
    }
    setState(() {
      _customError = null;
      _addingCustom = true;
    });
    try {
      final resolved = await _resolveSuggestedWords(words);
      if (resolved == null) {
        setState(() => _addingCustom = false);
        return;
      }
      if (_customAddMode == 'replace') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Replace custom list?'),
              content: const Text(
                'This will overwrite your existing custom words.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Replace'),
                ),
              ],
            );
          },
        );
        if (confirmed != true) {
          setState(() => _addingCustom = false);
          return;
        }
      }
      final saved = await widget.apiClient.addCustomVocab(
        childName: widget.childName,
        words: resolved,
        mode: _customAddMode,
      );
      final refreshed =
          await widget.apiClient.fetchCustomVocab(widget.childName);
      setState(() {
        _vocabSource = VocabListSource.customList;
        _wordListFuture = Future.value(refreshed);
        _selectedWord = refreshed.isNotEmpty ? refreshed.first : null;
        _customWordsController.clear();
        _resetPracticeState();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${saved.length} words.')),
        );
      }
    } catch (error) {
      setState(() {
        _customError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _addingCustom = false);
      }
    }
  }

  List<_QuizPrompt> _buildQuizPrompts({
    required VocabExercise exercise,
    required String word,
    required List<String> wordPool,
  }) {
    final definitionLines = _splitBilingualLines(exercise.definition);
    final exampleLines = _splitBilingualLines(exercise.exampleSentence);
    final prompts = <_QuizPrompt>[
      _buildPrimaryPrompt(
        exercise: exercise,
        word: word,
        exampleLines: exampleLines,
        wordPool: wordPool,
      ),
    ];
    prompts.addAll(
      _buildBidirectionalPrompts(
        exercise: exercise,
        word: word,
        definitionLines: definitionLines,
      ),
    );
    return prompts;
  }

  _QuizPrompt _buildPrimaryPrompt({
    required VocabExercise exercise,
    required String word,
    required _BilingualLines exampleLines,
    required List<String> wordPool,
  }) {
    final mode = _quizVariantSeed % 3;
    _quizVariantSeed += 1;
    switch (mode) {
      case 1:
        return _buildContextPrompt(word: word, exampleLines: exampleLines);
      case 2:
        return _buildFillBlankPrompt(
          word: word,
          exampleLines: exampleLines,
          wordPool: wordPool,
        );
      default:
        final keys = ['A', 'B', 'C']
            .where(exercise.quizChoices.containsKey)
            .toList(growable: false);
        final answer = keys.contains(exercise.quizAnswer) && keys.isNotEmpty
            ? exercise.quizAnswer
            : (keys.isNotEmpty ? keys.first : 'A');
        return _QuizPrompt(
          label: 'Meaning Match',
          question: exercise.quizQuestion,
          choices: exercise.quizChoices,
          answer: answer,
        );
    }
  }

  _QuizPrompt _buildContextPrompt({
    required String word,
    required _BilingualLines exampleLines,
  }) {
    final exampleEnglish =
        (exampleLines.english ?? '').trim().isNotEmpty
            ? (exampleLines.english ?? '').trim()
            : 'I can use the word $word today.';
    final exampleChinese = exampleLines.chinese?.trim();
    final correct = _mergeBilingualText(exampleEnglish, exampleChinese);
    const wrongOneEn = 'I can eat this word for lunch.';
    const wrongOneZh = '我可以把这个单词当午餐吃掉。';
    const wrongTwoEn = 'This word is a race car.';
    const wrongTwoZh = '这个单词是一辆赛车。';
    return _createRotatingPrompt(
      label: 'Context Choice',
      question: 'Which sentence best shows the meaning of "$word"?\n哪一句最符合 "$word" 的意思？',
      correctChoice: correct,
      wrongChoiceOne: _mergeBilingualText(wrongOneEn, wrongOneZh),
      wrongChoiceTwo: _mergeBilingualText(wrongTwoEn, wrongTwoZh),
      seed: _quizVariantSeed,
    );
  }

  _QuizPrompt _buildFillBlankPrompt({
    required String word,
    required _BilingualLines exampleLines,
    required List<String> wordPool,
  }) {
    final exampleEnglish =
        (exampleLines.english ?? '').trim().isNotEmpty
            ? (exampleLines.english ?? '').trim()
            : 'I can use the word $word today.';
    final blankEnglish = _blankWord(exampleEnglish, word);
    final exampleChinese = exampleLines.chinese?.trim();
    final blankChinese = exampleChinese == null || exampleChinese.isEmpty
        ? null
        : _blankWord(exampleChinese, word);
    final distractors = _buildFillBlankDistractors(word, wordPool);
    return _createRotatingPrompt(
      label: 'Fill in the Blank',
      question: blankChinese == null
          ? 'Fill in the blank with the correct word:\n$blankEnglish'
          : 'Fill in the blank with the correct word:\n$blankEnglish\n请用正确的单词填空：\n$blankChinese',
      correctChoice: word,
      wrongChoiceOne: distractors[0],
      wrongChoiceTwo: distractors[1],
      seed: _quizVariantSeed,
    );
  }

  List<String> _buildFillBlankDistractors(String word, List<String> wordPool) {
    final target = word.toLowerCase();
    final candidates = <String>[];
    for (final item in wordPool) {
      final trimmed = item.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == target) {
        continue;
      }
      if (!candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
      if (candidates.length >= 2) {
        break;
      }
    }
    if (candidates.length < 2) {
      final synthetic = ['${word}s', '${word}ing', '${word}er'];
      for (final item in synthetic) {
        if (item.toLowerCase() == target || candidates.contains(item)) {
          continue;
        }
        candidates.add(item);
        if (candidates.length >= 2) {
          break;
        }
      }
    }
    while (candidates.length < 2) {
      candidates.add('${word}x');
    }
    return candidates;
  }

  String _blankWord(String text, String word) {
    final escaped = RegExp.escape(word);
    final regex = RegExp('\\b$escaped\\b', caseSensitive: false);
    if (regex.hasMatch(text)) {
      return text.replaceFirst(regex, '____');
    }
    return '$text ____';
  }

  _QuizPrompt _createRotatingPrompt({
    required String label,
    required String question,
    required String correctChoice,
    required String wrongChoiceOne,
    required String wrongChoiceTwo,
    required int seed,
  }) {
    const letters = ['A', 'B', 'C'];
    final options = [correctChoice, wrongChoiceOne, wrongChoiceTwo];
    final rotation = seed % 3;
    final choices = <String, String>{};
    var answer = 'A';
    for (var index = 0; index < letters.length; index++) {
      final optionIndex = (index + rotation) % options.length;
      choices[letters[index]] = options[optionIndex];
      if (optionIndex == 0) {
        answer = letters[index];
      }
    }
    return _QuizPrompt(
      label: label,
      question: question,
      choices: choices,
      answer: answer,
    );
  }

  List<_QuizPrompt> _buildBidirectionalPrompts({
    required VocabExercise exercise,
    required String word,
    required _BilingualLines definitionLines,
  }) {
    final keys = ['A', 'B', 'C']
        .where(exercise.quizChoices.containsKey)
        .toList(growable: false);
    if (keys.length != 3 || !keys.contains(exercise.quizAnswer)) {
      return const [];
    }

    final chineseChoices = <String, String>{};
    final englishChoices = <String, String>{};
    var hasChinese = true;
    for (final key in keys) {
      final raw = exercise.quizChoices[key] ?? '';
      final lines = _splitBilingualLines(raw);
      final english = lines.english ?? raw;
      final chinese = lines.chinese;
      englishChoices[key] = english;
      if (chinese == null || chinese.trim().isEmpty) {
        hasChinese = false;
        chineseChoices[key] = raw;
      } else {
        chineseChoices[key] = chinese;
      }
    }
    if (!hasChinese) {
      return const [];
    }

    final chinesePromptLine = definitionLines.chinese?.trim();
    final enToZh = _QuizPrompt(
      label: 'EN → ZH Meaning',
      question: 'Choose the Chinese meaning of "$word".',
      choices: chineseChoices,
      answer: exercise.quizAnswer,
    );
    final zhToEn = _QuizPrompt(
      label: 'ZH → EN Meaning',
      question: chinesePromptLine == null || chinesePromptLine.isEmpty
          ? '选择 "$word" 的英文意思。'
          : '根据这句中文，选择 "$word" 的英文意思：\n$chinesePromptLine',
      choices: englishChoices,
      answer: exercise.quizAnswer,
    );
    return [enToZh, zhToEn];
  }

  String _mergeBilingualText(String english, String? chinese) {
    final en = english.trim();
    final zh = chinese?.trim();
    if (zh == null || zh.isEmpty) {
      return en;
    }
    return '$en\n$zh';
  }

  Future<void> _checkQuizPrompt(
    int index,
    _BilingualLines definitionLines,
  ) async {
    final exercise = _exercise;
    if (exercise == null || index < 0 || index >= _quizPrompts.length) {
      return;
    }
    if (_quizResults.containsKey(index)) {
      return;
    }
    final selected = _quizSelections[index];
    if (selected == null || selected.isEmpty) {
      return;
    }
    final prompt = _quizPrompts[index];
    final correct = selected == prompt.answer;
    final feedback = _buildInstructionalFeedback(
      correct: correct,
      prompt: prompt,
      selectedChoiceKey: selected,
      definitionLines: definitionLines,
      word: _selectedWord ?? '',
    );
    setState(() {
      _quizResults[index] = correct;
      _quizFeedback[index] = feedback;
    });

    final allChecked = _quizPrompts.isNotEmpty &&
        _quizResults.length == _quizPrompts.length &&
        !_exerciseSaved;
    if (!allChecked) {
      return;
    }

    final correctCount =
        _quizResults.values.where((value) => value == true).length;
    final score = ((correctCount / _quizPrompts.length) * 100).round();
    final passed = score >= 70;
    setState(() {
      _exerciseSaved = true;
      _feedback =
          'Exercise complete: $correctCount/${_quizPrompts.length} correct.';
    });
    widget.sessionState.recordAnswer(correct: passed);
    try {
      await widget.apiClient.saveExercise(
        SaveExercise(
          childName: widget.childName,
          word: _selectedWord ?? '',
          exerciseType: 'quiz',
          score: score,
          correct: passed,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _feedback = 'Saved locally, but failed to sync quiz score: $error';
        });
      }
    }
  }

  String _buildInstructionalFeedback({
    required bool correct,
    required _QuizPrompt prompt,
    required String selectedChoiceKey,
    required _BilingualLines definitionLines,
    required String word,
  }) {
    final englishMeaning =
        (definitionLines.english ?? _exercise?.definition ?? '').trim();
    final chineseMeaning = definitionLines.chinese?.trim();
    final correctChoice = (prompt.choices[prompt.answer] ?? '').trim();
    final selectedChoice = (prompt.choices[selectedChoiceKey] ?? '').trim();
    if (correct) {
      return [
        'Correct! Great job.',
        if (englishMeaning.isNotEmpty) 'EN meaning: $englishMeaning',
        if (chineseMeaning != null && chineseMeaning.isNotEmpty)
          'ZH meaning: $chineseMeaning',
      ].join('\n');
    }
    return [
      'Not quite. Keep going!',
      if (correctChoice.isNotEmpty) 'Correct answer: ${prompt.answer}. $correctChoice',
      if (englishMeaning.isNotEmpty) 'EN meaning: $englishMeaning',
      if (chineseMeaning != null && chineseMeaning.isNotEmpty)
        'ZH meaning: $chineseMeaning',
      if (selectedChoice.isNotEmpty)
        'Why: "$selectedChoice" does not match "$word".',
    ].join('\n');
  }

  Future<void> _showRagDebug() async {
    final query = _mode == PracticeMode.vocabulary
        ? (_selectedWord ?? '')
        : (_comprehension?.storyTitle ?? _storyLevel);
    if (query.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a word or story first.')),
        );
      }
      return;
    }
    setState(() => _ragDebugLoading = true);
    try {
      final result = await widget.apiClient.fetchRagDebug(
        query: query,
        childName: widget.childName,
        limit: 5,
      );
      if (!mounted) {
        return;
      }
      final results = result.results;
      final message = result.message ??
          (results.isEmpty ? 'No retrieval results found.' : null);
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('RAG Retrieval Debug'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Query: ${result.query}'),
                    const SizedBox(height: 8),
                    Text('RAG enabled: ${result.enabled ? 'Yes' : 'No'}'),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(message),
                    ],
                    if (results.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Top matches:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ...results.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('${entry.key + 1}. ${entry.value}'),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('RAG Debug Error'),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _ragDebugLoading = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    final word = _selectedWord;
    if (word == null || word.isEmpty) {
      return;
    }
    if (_audioRecorder.isRecording) {
      setState(() {
        _pronunciationLoading = true;
        _pronunciationScore = null;
        _pronunciationTranscript = null;
        _pronunciationFeedback = null;
      });
      try {
        final recording = await _audioRecorder.stop();
        _recording = recording;
        _audioPlayback.playUrl(recording.url);
        final assessment = await widget.apiClient.assessPronunciationAudio(
          word: word,
          audioBytes: recording.bytes,
          mimeType: recording.mimeType,
        );
        final correct = assessment.score >= 80;
        widget.sessionState.recordAnswer(correct: correct);
        await widget.apiClient.saveExercise(
          SaveExercise(
            childName: widget.childName,
            word: word,
            exerciseType: 'pronunciation',
            score: assessment.score,
            correct: correct,
          ),
        );
        setState(() {
          _pronunciationScore = assessment.score;
          _pronunciationTranscript = assessment.transcription;
          _pronunciationFeedback = correct
              ? 'Great pronunciation!'
              : 'Keep practicing the sounds.';
        });
      } catch (error) {
        setState(() {
          _pronunciationFeedback = _pronunciationErrorMessage(error);
        });
      } finally {
        if (mounted) {
          setState(() => _pronunciationLoading = false);
        }
      }
    } else {
      setState(() {
        _pronunciationScore = null;
        _pronunciationTranscript = null;
        _pronunciationFeedback = null;
      });
      try {
        _waveformNotifier.value = [];
        await _audioRecorder.start();
        setState(() {});
      } catch (error) {
        setState(() {
          _pronunciationFeedback = error is UnsupportedError
              ? 'Audio recording is not supported on this device.'
              : 'Microphone permission needed.';
        });
      }
    }
  }

  String _pronunciationErrorMessage(Object error) {
    if (error is StateError) {
      final message = error.message;
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    }
    return 'Unable to score pronunciation.';
  }

  void _maybeAutoPlayWord(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty || trimmed == _lastAutoPlayedWord) {
      return;
    }
    _lastAutoPlayedWord = trimmed;
    _speechHelper.speak(trimmed);
  }

  _BilingualLines _splitBilingualLines(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const _BilingualLines(null, null);
    }
    if (lines.length == 1) {
      return _BilingualLines(lines.first, null);
    }
    String? english;
    String? chinese;
    for (final line in lines) {
      if (RegExp(r'[\u4e00-\u9fff]').hasMatch(line)) {
        chinese ??= line;
      } else {
        english ??= line;
      }
    }
    return _BilingualLines(english ?? lines.first, chinese ?? lines.last);
  }

  void _startStoryReadAloud() {
    final exercise = _comprehension;
    if (exercise == null) {
      return;
    }
    final text = exercise.storyText.trim();
    if (text.isEmpty) {
      return;
    }
    _stopStoryReadAloud();
    _prepareStoryLines(text);
    if (_readMode == ReadMode.lineByLine) {
      _readNextLine();
      return;
    }
    final spokenText = _buildSpokenText();
    if (spokenText.isEmpty) {
      return;
    }
    setState(() {
      _storySpeaking = true;
      _storyPaused = false;
    });
    _storyReader.speak(
      spokenText,
      rate: _storyRate,
      onBoundary: _updateStoryHighlight,
      onEnd: () {
        if (mounted) {
          setState(() {
            _storySpeaking = false;
            _storyPaused = false;
            _highlightedRange = null;
            _autoRevealedStoryBlockChinese = null;
          });
        }
      },
    );
  }

  void _pauseStoryReadAloud() {
    if (!_storySpeaking || _storyPaused) {
      return;
    }
    _storyReader.pause();
    setState(() => _storyPaused = true);
  }

  void _resumeStoryReadAloud() {
    if (!_storyPaused) {
      return;
    }
    _storyReader.resume();
    setState(() => _storyPaused = false);
  }

  void _stopStoryReadAloud() {
    if (_storySpeaking) {
      _storyReader.stop();
    }
    if (mounted) {
      setState(() {
        _storySpeaking = false;
        _storyPaused = false;
        _highlightedRange = null;
        _autoRevealedStoryBlockChinese = null;
      });
    }
  }

  void _readNextLine() {
    if (_storyLines.isEmpty) {
      return;
    }
    final lines = _selectedStoryLines();
    if (lines.isEmpty) {
      return;
    }
    if (_storyLineIndex >= lines.length) {
      _storyLineIndex = 0;
    }
    final line = lines[_storyLineIndex];
    _storyLineIndex += 1;
    _prepareStorySpeech(lines: [line]);
    setState(() {
      _storySpeaking = true;
      _storyPaused = false;
      final range = _StoryHighlightRange(line.start, line.end);
      _highlightedRange = range;
      _autoRevealedStoryBlockChinese = line.isChinese && !_showStoryChinese
          ? _findChineseBlockIndexForRange(range)
          : null;
    });
    _storyReader.speak(
      line.text,
      rate: _storyRate,
      onBoundary: _updateStoryHighlight,
      onEnd: () {
        if (mounted) {
          setState(() {
            _storySpeaking = false;
            _storyPaused = false;
          });
        }
      },
    );
  }

  void _prepareStoryLines(String text) {
    final lines = text.split('\n');
    var cursor = 0;
    final parsed = <_StoryLine>[];
    for (var i = 0; i < lines.length; i += 1) {
      final line = lines[i];
      final start = cursor;
      final end = cursor + line.length;
      final isChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(line);
      parsed.add(_StoryLine(line, start, end, isChinese));
      cursor = end + 1;
    }
    _storyLines = parsed;
  }

  List<_StoryBlockLineRange> _buildStoryBlockLineRanges(
    ComprehensionExercise exercise,
  ) {
    final lines = _storyLines
        .where((line) => line.text.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty || exercise.storyBlocks.isEmpty) {
      return const [];
    }
    var searchCursor = 0;

    int? findNextLineIndex(String target) {
      final normalizedTarget = target.trim();
      if (normalizedTarget.isEmpty) {
        return null;
      }
      for (var i = searchCursor; i < lines.length; i += 1) {
        if (lines[i].text.trim() == normalizedTarget) {
          searchCursor = i + 1;
          return i;
        }
      }
      for (var i = 0; i < lines.length; i += 1) {
        if (lines[i].text.trim() == normalizedTarget) {
          if (i >= searchCursor) {
            searchCursor = i + 1;
          }
          return i;
        }
      }
      return null;
    }

    final ranges = <_StoryBlockLineRange>[];
    for (final block in exercise.storyBlocks) {
      final englishIndex = findNextLineIndex(block.english);
      final chineseIndex = findNextLineIndex(block.chinese);
      ranges.add(
        _StoryBlockLineRange(
          english: englishIndex == null
              ? null
              : _StoryHighlightRange(
                  lines[englishIndex].start,
                  lines[englishIndex].end,
                ),
          chinese: chineseIndex == null
              ? null
              : _StoryHighlightRange(
                  lines[chineseIndex].start,
                  lines[chineseIndex].end,
                ),
        ),
      );
    }
    return ranges;
  }

  int? _findChineseBlockIndexForRange(_StoryHighlightRange range) {
    final exercise = _comprehension;
    if (exercise == null) {
      return null;
    }
    final ranges = _buildStoryBlockLineRanges(exercise);
    for (var index = 0; index < ranges.length; index += 1) {
      final chineseRange = ranges[index].chinese;
      if (chineseRange == null) {
        continue;
      }
      final overlaps =
          range.start < chineseRange.end && range.end > chineseRange.start;
      if (overlaps) {
        return index;
      }
    }
    return null;
  }

  List<_StoryLine> _selectedStoryLines() {
    final wantChinese = _readLanguage == ReadLanguage.chinese;
    return _storyLines
        .where((line) =>
            line.isChinese == wantChinese && line.text.trim().isNotEmpty)
        .toList();
  }

  String _buildSpokenText() {
    final selected = _selectedStoryLines();
    if (selected.isEmpty) {
      return '';
    }
    _prepareStorySpeech(lines: selected);
    return selected.map((line) => line.text).join('\n');
  }

  void _prepareStorySpeech({required List<_StoryLine> lines}) {
    _storySpokenIndexMap = [];
    for (var i = 0; i < lines.length; i += 1) {
      final line = lines[i];
      for (var j = 0; j < line.text.length; j += 1) {
        _storySpokenIndexMap.add(line.start + j);
      }
      if (i < lines.length - 1) {
        _storySpokenIndexMap.add(-1);
      }
    }
    _storyTokens = _extractStoryTokens(lines.map((line) => line.text).join('\n'));
  }

  List<_StoryToken> _extractStoryTokens(String text) {
    final tokenPattern = RegExp(r'[A-Za-z0-9]+|[\u4e00-\u9fff]|[^\s]');
    return tokenPattern
        .allMatches(text)
        .map((match) => _StoryToken(match.start, match.end))
        .toList();
  }

  void _updateStoryHighlight(int charIndex) {
    if (_storyTokens.isEmpty || _storySpokenIndexMap.isEmpty) {
      return;
    }
    final token = _storyTokens.firstWhere(
      (item) => charIndex >= item.start && charIndex < item.end,
      orElse: () => _storyTokens.last,
    );
    if (token.start >= _storySpokenIndexMap.length) {
      return;
    }
    var mappedStart = token.start;
    while (mappedStart < _storySpokenIndexMap.length &&
        _storySpokenIndexMap[mappedStart] < 0) {
      mappedStart += 1;
    }
    var mappedEnd = token.end - 1;
    while (mappedEnd >= mappedStart && _storySpokenIndexMap[mappedEnd] < 0) {
      mappedEnd -= 1;
    }
    if (mappedEnd < mappedStart || mappedEnd >= _storySpokenIndexMap.length) {
      return;
    }
    final nextRange = _StoryHighlightRange(
      _storySpokenIndexMap[mappedStart],
      _storySpokenIndexMap[mappedEnd] + 1,
    );
    final revealChineseBlock = _showStoryChinese
        ? null
        : _findChineseBlockIndexForRange(nextRange);
    setState(() {
      _highlightedRange = nextRange;
      _autoRevealedStoryBlockChinese = revealChineseBlock;
    });
  }

  Future<void> _generateComprehension() async {
    _stopStoryReadAloud();
    setState(() {
      _loadingComprehension = true;
      _comprehension = null;
      _comprehensionError = null;
      _compChoices.clear();
      _compAnswered.clear();
      _compFeedback.clear();
      _showStoryChinese = false;
      _activeClueBlockIndex = null;
      _revealedStoryBlockChinese.clear();
      _autoRevealedStoryBlockChinese = null;
    });
    try {
      final exercise = await widget.apiClient.generateComprehensionExercise(
        level: _storyLevel,
        learningDirection: _learningDirectionValue,
        outputStyle: _outputStyleValue,
      );
      _prepareStoryLines(exercise.storyText);
      setState(() {
        _comprehension = exercise;
        _storyLineIndex = 0;
        _highlightedRange = null;
        _autoRevealedStoryBlockChinese = null;
      });
    } catch (error) {
      setState(() {
        _comprehensionError = 'Unable to load a story. ${error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingComprehension = false);
      }
    }
  }

  Future<void> _checkComprehensionAnswer(int index) async {
    final exercise = _comprehension;
    if (exercise == null || _compAnswered.containsKey(index)) {
      return;
    }
    final choice = _compChoices[index];
    if (choice == null) {
      return;
    }
    final question = exercise.questions[index];
    final correct = choice == question.answer;
    final explanationEn = (question.explanationEn ?? '').trim();
    final explanationZh = (question.explanationZh ?? '').trim();
    final clueIndex = question.evidenceBlockIndex;
    final feedback = <String>[
      if (correct) 'Correct! Great reading.',
      if (!correct) 'Not quite yet.',
      if (!correct && clueIndex != null)
        'Clue: check story block ${clueIndex + 1}.',
      if (explanationEn.isNotEmpty) 'Why (EN): $explanationEn',
      if (explanationZh.isNotEmpty) '解释 (ZH): $explanationZh',
    ].join('\n');
    setState(() {
      _compAnswered[index] = correct;
      _compFeedback[index] = feedback;
      if (!correct && clueIndex != null) {
        _activeClueBlockIndex = clueIndex;
      } else if (correct) {
        _activeClueBlockIndex = null;
      }
    });
    widget.sessionState.recordAnswer(correct: correct);
    await widget.apiClient.saveExercise(
      SaveExercise(
        childName: widget.childName,
        word: _comprehensionSaveLabel(question, index),
        exerciseType: 'comprehension',
        score: correct ? 100 : 0,
        correct: correct,
      ),
    );
  }

  String _comprehensionSaveLabel(ComprehensionQuestion question, int index) {
    final cleaned = question.question.replaceAll(
      RegExp(r"[^A-Za-z\u4e00-\u9fff\s\-']"),
      '',
    );
    final normalized = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isNotEmpty) {
      final truncated =
          normalized.length <= 32 ? normalized : normalized.substring(0, 32);
      return truncated.trim();
    }
    const fallback = [
      'Story Question One',
      'Story Question Two',
      'Story Question Three',
    ];
    if (index >= 0 && index < fallback.length) {
      return fallback[index];
    }
    return 'Story Question';
  }

  Widget _buildModeSelector() {
    return SegmentedButton<PracticeMode>(
      segments: const [
        ButtonSegment(
          value: PracticeMode.vocabulary,
          label: Text('Vocabulary'),
        ),
        ButtonSegment(
          value: PracticeMode.comprehension,
          label: Text('Story'),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) {
        setState(() {
          _mode = selection.first;
          _feedback = null;
          if (_mode != PracticeMode.comprehension) {
            _stopStoryReadAloud();
          }
        });
      },
    );
  }

  Widget _buildVocabularySection(List<String> words) {
    String? emptyMessage;
    if (words.isEmpty) {
      if (_vocabSource == VocabListSource.customList) {
        emptyMessage =
            'No custom words yet. Add a few below to get started.';
      } else if (_vocabSource == VocabListSource.weakList) {
        emptyMessage =
            'No weak words yet. Keep practicing to unlock suggestions.';
      } else {
        emptyMessage = 'No words available for this list yet.';
      }
    } else if (_selectedWord == null || !words.contains(_selectedWord)) {
      _selectedWord = words.first;
    }
    final word = _selectedWord ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mode: Bilingual (English + Chinese)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Word list:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<VocabListSource>(
          value: _vocabSource,
          items: const [
            DropdownMenuItem(
              value: VocabListSource.defaultList,
              child: Text('Default'),
            ),
            DropdownMenuItem(
              value: VocabListSource.customList,
              child: Text('Custom'),
            ),
            DropdownMenuItem(
              value: VocabListSource.weakList,
              child: Text('Weak words'),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _vocabSource = value;
            });
            _refreshWordList();
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (_vocabSource == VocabListSource.customList) ...[
          const SizedBox(height: 12),
          const Text(
            'Add custom words:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customWordsController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Type words separated by commas or new lines',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'append',
                label: Text('Append'),
              ),
              ButtonSegment(
                value: 'replace',
                label: Text('Replace'),
              ),
            ],
            selected: {_customAddMode},
            onSelectionChanged: (selection) {
              setState(() => _customAddMode = selection.first);
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _addingCustom ? null : _addCustomWords,
            icon: const Icon(Icons.playlist_add),
            label: Text(_addingCustom ? 'Adding...' : 'Add Words'),
          ),
          if (_customError != null) ...[
            const SizedBox(height: 4),
            Text(
              _customError!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
        if (emptyMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            emptyMessage,
            style: const TextStyle(fontSize: 16),
          ),
        ],
        if (words.isNotEmpty) ...[
          const SizedBox(height: 16),
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
              _resetPracticeState();
            }),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : () => _generateExercise(words),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Exercise'),
          ),
          const SizedBox(height: 20),
          if (_loading) const LoadingView(message: 'Creating exercise...'),
          if (_exercise != null) ...[
            Builder(
              builder: (context) {
                final definitionLines =
                    _splitBilingualLines(_exercise!.definition);
                final exampleLines =
                    _splitBilingualLines(_exercise!.exampleSentence);
                return _ExerciseCard(
                  exercise: _exercise!,
                  word: word,
                  definitionLines: definitionLines,
                  exampleLines: exampleLines,
                  imageHintUrl: _vocabHintImageUrl,
                  imageHintError: _vocabHintError,
                  imageHintLoading: _vocabHintLoading,
                  onGenerateImageHint: _generateVocabImageHint,
                  showDefinitionChinese: _showDefinitionChinese,
                  showExampleChinese: _showExampleChinese,
                  onToggleDefinitionChinese: () => setState(
                    () => _showDefinitionChinese = !_showDefinitionChinese,
                  ),
                  onToggleExampleChinese: () => setState(
                    () => _showExampleChinese = !_showExampleChinese,
                  ),
                  onListenWord: () => _speechHelper.speak(word),
                  onListenDefinitionEnglish: () => _speechHelper.speak(
                    definitionLines.english ?? _exercise!.definition,
                  ),
                  onListenDefinitionChinese: () => _speechHelper.speak(
                    definitionLines.chinese ?? _exercise!.definition,
                  ),
                  onListenExampleEnglish: () => _speechHelper.speak(
                    exampleLines.english ?? _exercise!.exampleSentence,
                  ),
                  onListenExampleChinese: () => _speechHelper.speak(
                    exampleLines.chinese ?? _exercise!.exampleSentence,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick checks:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final definitionLines =
                    _splitBilingualLines(_exercise!.definition);
                return Column(
                  children: _quizPrompts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final prompt = entry.value;
                    final selected = _quizSelections[index];
                    final checked = _quizResults[index] != null;
                    final feedback = _quizFeedback[index];
                    return _QuizPromptCard(
                      index: index,
                      prompt: prompt,
                      selectedChoice: selected,
                      checked: checked,
                      feedback: feedback,
                      onChoiceChanged: checked
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _quizSelections[index] = value;
                              });
                            },
                      onCheck: selected == null || checked
                          ? null
                          : () => _checkQuizPrompt(index, definitionLines),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(
              _feedback!,
              style: const TextStyle(fontSize: 16),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Pronunciation practice:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _pronunciationLoading ? null : _toggleRecording,
            icon: Icon(_audioRecorder.isRecording ? Icons.stop : Icons.mic),
            label:
                Text(_audioRecorder.isRecording ? 'Stop Recording' : 'Record'),
          ),
          if (_audioRecorder.isRecording) ...[
            const SizedBox(height: 6),
            const Text('Recording... tap stop when you are done.'),
            const SizedBox(height: 8),
            AudioLevelIndicator(levelListenable: _audioRecorder.levelListenable),
          ],
          if (_pronunciationLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LoadingView(message: 'Scoring pronunciation...'),
            ),
          if (_recording != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Recorded audio:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<List<double>>(
              valueListenable: _waveformNotifier,
              builder: (context, levels, _) {
                if (levels.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AudioWaveformPreview(levels: levels),
                );
              },
            ),
            FilledButton.icon(
              onPressed: () => _audioPlayback.playUrl(_recording!.url),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Back'),
            ),
          ],
          if (_pronunciationTranscript != null) ...[
            const SizedBox(height: 8),
            Text('You said: $_pronunciationTranscript'),
          ],
          if (_pronunciationScore != null) ...[
            const SizedBox(height: 4),
            Text('Score: $_pronunciationScore / 100'),
          ],
          if (_pronunciationFeedback != null) ...[
            const SizedBox(height: 4),
            Text(_pronunciationFeedback!),
          ],
        ],
      ],
    );
  }

  Widget _buildComprehensionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mode: Bilingual (English + Chinese)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose a story level:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _storyLevel,
          items: const [
            DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
            DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
            DropdownMenuItem(value: 'expert', child: Text('Expert')),
          ],
          onChanged: (value) => setState(() {
            _storyLevel = value ?? 'beginner';
          }),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _loadingComprehension ? null : _generateComprehension,
          icon: const Icon(Icons.menu_book),
          label: const Text('Generate Story'),
        ),
        const SizedBox(height: 16),
        if (_loadingComprehension)
          const LoadingView(message: 'Creating your story...'),
        if (_comprehensionError != null) ...[
          Text(
            _comprehensionError!,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
        ],
        if (_comprehension != null)
          _ComprehensionCard(
            exercise: _comprehension!,
            highlightedRange: _highlightedRange,
            storyBlockRanges: _buildStoryBlockLineRanges(_comprehension!),
            showStoryChinese: _showStoryChinese,
            revealedStoryBlockChinese: _revealedStoryBlockChinese,
            autoRevealedStoryBlockChinese: _autoRevealedStoryBlockChinese,
            activeClueBlockIndex: _activeClueBlockIndex,
            onToggleStoryChinese: () {
              setState(() {
                _showStoryChinese = !_showStoryChinese;
                _autoRevealedStoryBlockChinese = null;
              });
            },
            onToggleStoryBlockChinese: (index) {
              setState(() {
                if (_revealedStoryBlockChinese.contains(index)) {
                  _revealedStoryBlockChinese.remove(index);
                } else {
                  _revealedStoryBlockChinese.add(index);
                }
              });
            },
            isSpeaking: _storySpeaking,
            isPaused: _storyPaused,
            rate: _storyRate,
            onRateChanged: (value) => setState(() => _storyRate = value),
            readMode: _readMode,
            readLanguage: _readLanguage,
            onReadModeChanged: (value) {
              _stopStoryReadAloud();
              setState(() {
                _readMode = value;
                _storyLineIndex = 0;
                _highlightedRange = null;
                _autoRevealedStoryBlockChinese = null;
              });
            },
            onReadLanguageChanged: (value) {
              _stopStoryReadAloud();
              setState(() {
                _readLanguage = value;
                _storyLineIndex = 0;
                _highlightedRange = null;
                _autoRevealedStoryBlockChinese = null;
              });
            },
            onListen: _startStoryReadAloud,
            onPause: _pauseStoryReadAloud,
            onResume: _resumeStoryReadAloud,
            onNextLine: _readNextLine,
            onStop: _stopStoryReadAloud,
          ),
        if (_comprehension != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Questions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._comprehension!.questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final selected = _compChoices[index];
            final answered = _compAnswered[index];
            final feedback = _compFeedback[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((question.questionType ?? '').isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Type: ${question.questionType}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                      ),
                    Text(
                      'Q${index + 1}. ${question.question}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ...['A', 'B', 'C']
                        .where((key) => question.choices.containsKey(key))
                        .map(
                          (key) => RadioListTile<String>(
                            value: key,
                            groupValue: selected,
                            onChanged: (value) => setState(() {
                              if (value != null) {
                                _compChoices[index] = value;
                              }
                            }),
                            title: Text('${key}. ${question.choices[key]}'),
                          ),
                        ),
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => _checkComprehensionAnswer(index),
                      child: const Text('Check'),
                    ),
                    if (feedback != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        feedback,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (answered == false && question.evidenceBlockIndex != null) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(
                            () => _activeClueBlockIndex = question.evidenceBlockIndex,
                          );
                        },
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text(
                          'Show clue block ${question.evidenceBlockIndex! + 1}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  String get _learningDirectionValue => 'en_to_zh';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        backgroundColor: const Color(0xFFF6F4FF),
      ),
      body: FutureBuilder<List<String>>(
        future: _wordListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading words...');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorView(
              message: 'Unable to load vocabulary list.',
              onRetry: () {
                _refreshWordList();
              },
            );
          }
          final words = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              MascotHeader(
                childName: widget.childName,
                sessionState: widget.sessionState,
              ),
              const SizedBox(height: 16),
              _buildModeSelector(),
              if (_ragDebugEnabled) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _ragDebugLoading ? null : _showRagDebug,
                  icon: const Icon(Icons.bug_report),
                  label: Text(
                    _ragDebugLoading
                        ? 'Loading retrieval...'
                        : 'Debug: Retrieval',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_mode == PracticeMode.vocabulary)
                _buildVocabularySection(words)
              else
                _buildComprehensionSection(),
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final VocabExercise exercise;
  final String word;
  final _BilingualLines definitionLines;
  final _BilingualLines exampleLines;
  final String? imageHintUrl;
  final String? imageHintError;
  final bool imageHintLoading;
  final VoidCallback onGenerateImageHint;
  final bool showDefinitionChinese;
  final bool showExampleChinese;
  final VoidCallback onToggleDefinitionChinese;
  final VoidCallback onToggleExampleChinese;
  final VoidCallback onListenWord;
  final VoidCallback onListenDefinitionEnglish;
  final VoidCallback onListenDefinitionChinese;
  final VoidCallback onListenExampleEnglish;
  final VoidCallback onListenExampleChinese;

  const _ExerciseCard({
    required this.exercise,
    required this.word,
    required this.definitionLines,
    required this.exampleLines,
    required this.imageHintUrl,
    required this.imageHintError,
    required this.imageHintLoading,
    required this.onGenerateImageHint,
    required this.showDefinitionChinese,
    required this.showExampleChinese,
    required this.onToggleDefinitionChinese,
    required this.onToggleExampleChinese,
    required this.onListenWord,
    required this.onListenDefinitionEnglish,
    required this.onListenDefinitionChinese,
    required this.onListenExampleEnglish,
    required this.onListenExampleChinese,
  });

  Widget _buildHintImage() {
    final imageUrl = imageHintUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    if (imageUrl.startsWith('data:image')) {
      final data = UriData.parse(imageUrl).contentAsBytes();
      return Image.memory(
        data,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Vocabulary hint image unavailable.',
            style: TextStyle(color: Colors.grey),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Word: $word',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onListenWord,
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Listen to the word',
                ),
              ],
            ),
            if (exercise.phonics != null && exercise.phonics!.isNotEmpty) ...[
              Text(
                'Phonics: ${exercise.phonics}',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Definition (English): ${definitionLines.english ?? exercise.definition}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: onListenDefinitionEnglish,
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Listen to the English definition',
                ),
              ],
            ),
            if (definitionLines.chinese != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onToggleDefinitionChinese,
                  icon: Icon(
                    showDefinitionChinese ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(
                    showDefinitionChinese
                        ? 'Hide Chinese meaning'
                        : 'Reveal Chinese meaning',
                  ),
                ),
              ),
            ],
            if (showDefinitionChinese && definitionLines.chinese != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Definition (Chinese): ${definitionLines.chinese}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: onListenDefinitionChinese,
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Listen to the Chinese definition',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Example (English): ${exampleLines.english ?? exercise.exampleSentence}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: onListenExampleEnglish,
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Listen to the English example',
                ),
              ],
            ),
            if (exampleLines.chinese != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onToggleExampleChinese,
                  icon: Icon(
                    showExampleChinese ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(
                    showExampleChinese
                        ? 'Hide Chinese example'
                        : 'Reveal Chinese example',
                  ),
                ),
              ),
            ],
            if (showExampleChinese && exampleLines.chinese != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Example (Chinese): ${exampleLines.chinese}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: onListenExampleChinese,
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Listen to the Chinese example',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Tip: Guess in English first, then reveal Chinese.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            const Text(
              'Image hint:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: exercise.imageHintEnabled && !imageHintLoading
                  ? onGenerateImageHint
                  : null,
              icon: const Icon(Icons.image),
              label: Text(
                imageHintLoading
                    ? 'Generating image hint...'
                    : 'Generate Image Hint',
              ),
            ),
            if (!exercise.imageHintEnabled &&
                exercise.imageHintReason == 'abstract_word') ...[
              const SizedBox(height: 6),
              const Text(
                'Abstract word cannot generate image hint.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
            if (imageHintError != null) ...[
              const SizedBox(height: 6),
              Text(
                imageHintError!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (imageHintUrl != null && imageHintUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildHintImage(),
              ),
            ],
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

class _QuizPromptCard extends StatelessWidget {
  final int index;
  final _QuizPrompt prompt;
  final String? selectedChoice;
  final bool checked;
  final String? feedback;
  final ValueChanged<String?>? onChoiceChanged;
  final VoidCallback? onCheck;

  const _QuizPromptCard({
    required this.index,
    required this.prompt,
    required this.selectedChoice,
    required this.checked,
    required this.feedback,
    required this.onChoiceChanged,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final choiceKeys = ['A', 'B', 'C']
        .where(prompt.choices.containsKey)
        .toList(growable: false);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check ${index + 1}: ${prompt.label}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(prompt.question),
            const SizedBox(height: 6),
            ...choiceKeys.map(
              (key) => RadioListTile<String>(
                value: key,
                groupValue: selectedChoice,
                onChanged: onChoiceChanged,
                title: Text('$key. ${prompt.choices[key]}'),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: onCheck,
              child: Text(checked ? 'Checked' : 'Check'),
            ),
            if (feedback != null) ...[
              const SizedBox(height: 8),
              Text(
                feedback!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizPrompt {
  final String label;
  final String question;
  final Map<String, String> choices;
  final String answer;

  const _QuizPrompt({
    required this.label,
    required this.question,
    required this.choices,
    required this.answer,
  });
}

class _StoryBlockLineRange {
  final _StoryHighlightRange? english;
  final _StoryHighlightRange? chinese;

  const _StoryBlockLineRange({this.english, this.chinese});
}

class _ComprehensionCard extends StatelessWidget {
  final ComprehensionExercise exercise;
  final _StoryHighlightRange? highlightedRange;
  final List<_StoryBlockLineRange> storyBlockRanges;
  final bool showStoryChinese;
  final Set<int> revealedStoryBlockChinese;
  final int? autoRevealedStoryBlockChinese;
  final int? activeClueBlockIndex;
  final VoidCallback onToggleStoryChinese;
  final ValueChanged<int> onToggleStoryBlockChinese;
  final bool isSpeaking;
  final bool isPaused;
  final double rate;
  final ValueChanged<double> onRateChanged;
  final ReadMode readMode;
  final ReadLanguage readLanguage;
  final ValueChanged<ReadMode> onReadModeChanged;
  final ValueChanged<ReadLanguage> onReadLanguageChanged;
  final VoidCallback onListen;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onNextLine;
  final VoidCallback onStop;

  const _ComprehensionCard({
    required this.exercise,
    required this.highlightedRange,
    required this.storyBlockRanges,
    required this.showStoryChinese,
    required this.revealedStoryBlockChinese,
    required this.autoRevealedStoryBlockChinese,
    required this.activeClueBlockIndex,
    required this.onToggleStoryChinese,
    required this.onToggleStoryBlockChinese,
    required this.isSpeaking,
    required this.isPaused,
    required this.rate,
    required this.onRateChanged,
    required this.readMode,
    required this.readLanguage,
    required this.onReadModeChanged,
    required this.onReadLanguageChanged,
    required this.onListen,
    required this.onPause,
    required this.onResume,
    required this.onNextLine,
    required this.onStop,
  });

  Widget _buildStoryImage() {
    final imageUrl = exercise.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    if (imageUrl.startsWith('data:image')) {
      final data = UriData.parse(imageUrl).contentAsBytes();
      return Image.memory(
        data,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Illustration unavailable.',
            style: TextStyle(color: Colors.grey),
          ),
        );
      },
    );
  }

  List<TextSpan> _buildHighlightedLineSpans({
    required String text,
    required _StoryHighlightRange? lineRange,
  }) {
    if (text.isEmpty) {
      return const [TextSpan(text: '')];
    }
    final activeRange = highlightedRange;
    if (activeRange == null || lineRange == null) {
      return [TextSpan(text: text)];
    }
    final overlapStart = math.max(lineRange.start, activeRange.start);
    final overlapEnd = math.min(lineRange.end, activeRange.end);
    if (overlapStart >= overlapEnd) {
      return [TextSpan(text: text)];
    }

    final localStart =
        (overlapStart - lineRange.start).clamp(0, text.length).toInt();
    final localEnd =
        (overlapEnd - lineRange.start).clamp(0, text.length).toInt();
    if (localStart >= localEnd) {
      return [TextSpan(text: text)];
    }
    final spans = <TextSpan>[];
    if (localStart > 0) {
      spans.add(TextSpan(text: text.substring(0, localStart)));
    }
    spans.add(
      TextSpan(
        text: text.substring(localStart, localEnd),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFF3B0),
          color: Color(0xFFD97706),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (localEnd < text.length) {
      spans.add(TextSpan(text: text.substring(localEnd)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final storyBlocks = exercise.storyBlocks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.storyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isSpeaking ? onStop : onListen,
                  icon: Icon(isSpeaking ? Icons.stop : Icons.volume_up),
                  label: Text(isSpeaking ? 'Stop Reading' : 'Read Story Aloud'),
                ),
                if (readMode == ReadMode.lineByLine)
                  FilledButton(
                    onPressed: isSpeaking ? null : onNextLine,
                    child: const Text('Read Next Line'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SegmentedButton<ReadMode>(
                  segments: const [
                    ButtonSegment(
                      value: ReadMode.continuous,
                      label: Text('Continuous'),
                    ),
                    ButtonSegment(
                      value: ReadMode.lineByLine,
                      label: Text('Line by line'),
                    ),
                  ],
                  selected: {readMode},
                  onSelectionChanged: (selection) =>
                      onReadModeChanged(selection.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('English'),
                  selected: readLanguage == ReadLanguage.english,
                  onSelected: (_) =>
                      onReadLanguageChanged(ReadLanguage.english),
                ),
                ChoiceChip(
                  label: const Text('Chinese'),
                  selected: readLanguage == ReadLanguage.chinese,
                  onSelected: (_) =>
                      onReadLanguageChanged(ReadLanguage.chinese),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: isSpeaking && !isPaused ? onPause : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                FilledButton.icon(
                  onPressed: isSpeaking && isPaused ? onResume : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
                Text('${rate.toStringAsFixed(1)}x'),
              ],
            ),
            Slider(
              value: rate,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${rate.toStringAsFixed(1)}x',
              onChanged: onRateChanged,
            ),
            if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildStoryImage(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Story blocks',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: onToggleStoryChinese,
                  icon: Icon(
                    showStoryChinese ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(
                    showStoryChinese ? 'Hide all Chinese' : 'Reveal all Chinese',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...storyBlocks.asMap().entries.map((entry) {
              final index = entry.key;
              final block = entry.value;
              final showChinese =
                  showStoryChinese ||
                  revealedStoryBlockChinese.contains(index) ||
                  autoRevealedStoryBlockChinese == index;
              final isClue = activeClueBlockIndex == index;
              final lineRanges = index < storyBlockRanges.length
                  ? storyBlockRanges[index]
                  : const _StoryBlockLineRange();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isClue ? const Color(0xFFFFF7ED) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isClue
                        ? const Color(0xFFFB923C)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Block ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (isClue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Clue',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context)
                            .style
                            .copyWith(fontSize: 16),
                        children: _buildHighlightedLineSpans(
                          text: block.english,
                          lineRange: lineRanges.english,
                        ),
                      ),
                    ),
                    if (showChinese && block.chinese.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style.copyWith(
                                  fontSize: 16,
                                  color: const Color(0xFF374151),
                                ),
                            children: _buildHighlightedLineSpans(
                              text: block.chinese,
                              lineRange: lineRanges.chinese,
                            ),
                          ),
                        ),
                      ),
                    if (!showStoryChinese && block.chinese.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => onToggleStoryBlockChinese(index),
                          child: Text(
                            showChinese ? 'Hide Chinese' : 'Reveal Chinese',
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            if (exercise.source != null) ...[
              const SizedBox(height: 8),
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

class _StoryLine {
  final String text;
  final int start;
  final int end;
  final bool isChinese;

  _StoryLine(this.text, this.start, this.end, this.isChinese);
}

class _BilingualLines {
  final String? english;
  final String? chinese;

  const _BilingualLines(this.english, this.chinese);
}

class _StoryToken {
  final int start;
  final int end;

  _StoryToken(this.start, this.end);
}

class _StoryHighlightRange {
  final int start;
  final int end;

  _StoryHighlightRange(this.start, this.end);
}
