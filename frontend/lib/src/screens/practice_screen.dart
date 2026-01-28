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
  String? _selectedChoice;
  String? _feedback;
  bool _loading = false;

  PracticeMode _mode = PracticeMode.vocabulary;
  ComprehensionExercise? _comprehension;
  String? _comprehensionError;
  bool _loadingComprehension = false;
  String _storyLevel = 'beginner';
  bool _includeImage = false;
  final Map<int, String> _compChoices = {};
  final Map<int, bool> _compAnswered = {};

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
  int? _highlightedWordIndex;
  String? _storyTextCache;
  List<_StoryWord> _storyWords = [];

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
      _maybeAutoPlayWord(word);
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
    _selectedChoice = null;
    _recording = null;
    _pronunciationScore = null;
    _pronunciationTranscript = null;
    _pronunciationFeedback = null;
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

  Future<void> _checkAnswer() async {
    final exercise = _exercise;
    if (exercise == null || _selectedChoice == null) {
      return;
    }
    final correct = _selectedChoice == exercise.quizAnswer;
    setState(() {
      _feedback = correct ? 'Correct! Great job!' : 'Nice try! Keep practicing.';
    });
    widget.sessionState.recordAnswer(correct: correct);
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

  void _startStoryReadAloud() {
    final text = _comprehension?.storyText ?? '';
    if (text.trim().isEmpty) {
      return;
    }
    _prepareStoryWords(text);
    setState(() {
      _storySpeaking = true;
      _highlightedWordIndex = null;
    });
    _storyReader.speak(
      text,
      rate: _storyRate,
      onBoundary: _updateStoryHighlight,
      onEnd: () {
        if (mounted) {
          setState(() {
            _storySpeaking = false;
            _highlightedWordIndex = null;
          });
        }
      },
    );
  }

  void _stopStoryReadAloud() {
    if (_storySpeaking) {
      _storyReader.stop();
    }
    if (mounted) {
      setState(() {
        _storySpeaking = false;
        _highlightedWordIndex = null;
      });
    }
  }

  void _prepareStoryWords(String text) {
    if (_storyTextCache == text && _storyWords.isNotEmpty) {
      return;
    }
    _storyTextCache = text;
    _storyWords = RegExp(r"[A-Za-z']+").allMatches(text).map((match) {
      return _StoryWord(match.start, match.end);
    }).toList();
  }

  void _updateStoryHighlight(int charIndex) {
    if (_storyWords.isEmpty) {
      return;
    }
    int? index;
    for (var i = 0; i < _storyWords.length; i += 1) {
      final word = _storyWords[i];
      if (charIndex >= word.start && charIndex < word.end) {
        index = i;
        break;
      }
    }
    if (index != null && index != _highlightedWordIndex) {
      setState(() => _highlightedWordIndex = index);
    }
  }

  List<TextSpan> _buildStorySpans(String text) {
    _prepareStoryWords(text);
    final spans = <TextSpan>[];
    var lastIndex = 0;
    for (var i = 0; i < _storyWords.length; i += 1) {
      final word = _storyWords[i];
      if (word.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, word.start)));
      }
      final isHighlighted = i == _highlightedWordIndex;
      spans.add(
        TextSpan(
          text: text.substring(word.start, word.end),
          style: isHighlighted
              ? const TextStyle(
                  backgroundColor: Color(0xFFFFF3B0),
                  fontWeight: FontWeight.bold,
                )
              : null,
        ),
      );
      lastIndex = word.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }
    return spans;
  }

  Future<void> _generateComprehension() async {
    _stopStoryReadAloud();
    setState(() {
      _loadingComprehension = true;
      _comprehension = null;
      _comprehensionError = null;
      _compChoices.clear();
      _compAnswered.clear();
    });
    try {
      final exercise = await widget.apiClient.generateComprehensionExercise(
        level: _storyLevel,
        includeImage: _includeImage,
      );
      setState(() {
        _comprehension = exercise;
      });
    } catch (error) {
      setState(() {
        _comprehensionError = 'Unable to load a story. Try again.';
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
    setState(() {
      _compAnswered[index] = correct;
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
      RegExp(r"[^A-Za-z\s\-']"),
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
            onPressed: _loading ? null : _generateExercise,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Exercise'),
          ),
          const SizedBox(height: 20),
          if (_loading) const LoadingView(message: 'Creating exercise...'),
          if (_exercise != null) ...[
            _ExerciseCard(
              exercise: _exercise!,
              word: word,
              onListen: () => _speechHelper.speak(word),
            ),
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
        SwitchListTile(
          value: _includeImage,
          onChanged: (value) => setState(() => _includeImage = value),
          title: const Text('Include illustration'),
          subtitle: const Text('Uses image generation credits.'),
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
            storySpans: _buildStorySpans(_comprehension!.storyText),
            isSpeaking: _storySpeaking,
            rate: _storyRate,
            onRateChanged: (value) => setState(() => _storyRate = value),
            onListen: _startStoryReadAloud,
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
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (answered != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        answered ? 'Correct!' : 'Not quite. Try again!',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
  final VoidCallback onListen;

  const _ExerciseCard({
    required this.exercise,
    required this.word,
    required this.onListen,
  });

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
                  onPressed: onListen,
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

class _ComprehensionCard extends StatelessWidget {
  final ComprehensionExercise exercise;
  final List<TextSpan> storySpans;
  final bool isSpeaking;
  final double rate;
  final ValueChanged<double> onRateChanged;
  final VoidCallback onListen;
  final VoidCallback onStop;

  const _ComprehensionCard({
    required this.exercise,
    required this.storySpans,
    required this.isSpeaking,
    required this.rate,
    required this.onRateChanged,
    required this.onListen,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                FilledButton.icon(
                  onPressed: isSpeaking ? onStop : onListen,
                  icon: Icon(isSpeaking ? Icons.stop : Icons.volume_up),
                  label: Text(isSpeaking ? 'Stop Reading' : 'Read Story Aloud'),
                ),
                const SizedBox(width: 12),
                Text('${rate.toStringAsFixed(1)}x'),
              ],
            ),
            Slider(
              value: rate,
              min: 0.6,
              max: 1.4,
              divisions: 4,
              label: '${rate.toStringAsFixed(1)}x',
              onChanged: onRateChanged,
            ),
            if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  exercise.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],
            RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontSize: 18),
                children: storySpans,
              ),
            ),
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

class _StoryWord {
  final int start;
  final int end;

  _StoryWord(this.start, this.end);
}
