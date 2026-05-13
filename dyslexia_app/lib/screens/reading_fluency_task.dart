import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dyslexia_app/models/fluency_progress.dart';
import 'package:dyslexia_app/services/difficulty_profile_service.dart';
import 'package:dyslexia_app/services/fluency_service.dart';
import 'package:dyslexia_app/widgets/skip_button.dart';
import 'package:dyslexia_app/services/task_score_service.dart';
import 'package:dyslexia_app/utils/logger.dart';
import 'package:dyslexia_app/services/visual_service.dart';
import 'package:dyslexia_app/utils/visual_training_loop.dart';

class ReadingFluencyTask extends StatefulWidget {
  final VoidCallback? onComplete;

  const ReadingFluencyTask({super.key, this.onComplete});

  @override
  State<ReadingFluencyTask> createState() => _ReadingFluencyTaskState();
}

class _ReadingFluencyTaskState extends State<ReadingFluencyTask>
    with SingleTickerProviderStateMixin {
  // NIE Grade 1-2 Curriculum-matched sentences
  final Map<int, List<String>> sentencesByLevel = {
    1: [
      // Level 1: 2-word sentences - Simple, correct Sinhala
      'බල්ලා දුවයි',
      'අම්මා එයි.',
      'මල් පිපේ.',
      'ගෙදර තියනවා.',
      'සිසුන් කියවයි.',
    ],
    2: [
      // Level 2: 3-word sentences - Correct grammar, simple vocabulary
      'මල් වත්ත ලස්සනයි.',
      'අම්මා කෑම පිසියි.',
      'අපි පාසලට යමු.',
      'නංගී පොත කියවයි.',
      'තාත්තා වැඩ කරයි.',
    ],
    3: [
      // Level 3: 4-word sentences - Correct, simple, curriculum-aligned
      'ගෙදර ළඟ ගසක් තිබේ.',
      'අපි උදේ පාසලට යමු.',
      'නංගී ලස්සන මලක් අඳියි.',
      'අම්මා කෑම පිසිනවා.',
      'ගුරුවරයා පාඩම උගන්වයි.',
    ],
  };

  // Track current level and sentence
  int currentLevel = DifficultyProfileService.cachedStartingGameLevel;
  int currentSentenceIndex = 0;
  late String currentSentence;
  late List<String> words;
  List<bool> wordRead = [];
  int errorCount = 0;

  Timer? _timer;
  DateTime? _startTime;
  DateTime? _endTime;
  Duration elapsed = Duration.zero;

  int sessionsCompleted = 0;
  double avgWpm = 0.0;
  double avgWer = 0.0; // Average Word Error Rate
  late String studentId;
  int breakdownLevel = 0; // Level where fluency broke down

  late AnimationController _pulseController;
  TypographyConfig _typographyConfig = TypographyConfig.defaultConfig();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.95,
      upperBound: 1.06,
    )..repeat(reverse: true);
    _loadStats();
    _loadNextSentence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    studentId = prefs.getString('student_id') ??
        'student_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      sessionsCompleted = prefs.getInt('rf_sessions') ?? 0;
      avgWpm = prefs.getDouble('rf_avg_wpm') ?? 0.0;
      avgWer = prefs.getDouble('rf_avg_wer') ?? 0.0;
      breakdownLevel = prefs.getInt('rf_breakdown_level') ?? 0;
    });

    // Try to load from MongoDB if connected
    final progress = await FluencyService.getFluencyProgress(studentId);
    if (progress != null) {
      setState(() {
        sessionsCompleted = progress.sessionsCompleted;
        avgWpm = progress.avgWpm;
        currentLevel = currentLevel > progress.fluencyLevel ? currentLevel : progress.fluencyLevel;
      });
    }

    _fetchAdaptiveTypography();
  }

  Future<void> _fetchAdaptiveTypography() async {
    try {
      final config = await VisualService.getTypographyConfig(studentId);
      if (mounted) {
        setState(() {
          _typographyConfig = config;
        });
      }
    } catch (e) {
      AppLogger.error('Error fetching typography for Fluency Task: $e');
    }
  }

  void _loadNextSentence() {
    if (currentLevel > 3) {
      // All levels completed
      return;
    }
    final sentences = sentencesByLevel[currentLevel]!;
    if (currentSentenceIndex >= sentences.length) {
      currentSentenceIndex = 0;
      currentLevel++;
      if (currentLevel > 3) return;
    }
    setState(() {
      currentSentence = sentences[currentSentenceIndex];
      words = currentSentence.split(' ');
      wordRead = List<bool>.filled(words.length, false);
      errorCount = 0;
    });
  }

  Future<void> _saveSession(double wpm, double wer, int lastErrorCount) async {
    final prefs = await SharedPreferences.getInstance();
    final prevSessions = prefs.getInt('rf_sessions') ?? 0;
    final prevAvgWpm = prefs.getDouble('rf_avg_wpm') ?? 0.0;
    final prevAvgWer = prefs.getDouble('rf_avg_wer') ?? 0.0;

    final newSessions = prevSessions + 1;
    final newAvgWpm = ((prevAvgWpm * prevSessions) + wpm) / newSessions;
    final newAvgWer = ((prevAvgWer * prevSessions) + wer) / newSessions;

    // Check if fluency broke down at this level
    int newBreakdownLevel = breakdownLevel;
    if (wpm < 15 || wer > 20) {
      if (newBreakdownLevel == 0) {
        newBreakdownLevel = currentLevel;
      }
    }

    await prefs.setInt('rf_sessions', newSessions);
    await prefs.setDouble('rf_avg_wpm', newAvgWpm);
    await prefs.setDouble('rf_avg_wer', newAvgWer);
    await prefs.setInt('rf_breakdown_level', newBreakdownLevel);
    await prefs.setInt('rf_last_error_count', lastErrorCount);
    await prefs.setDouble('rf_last_wpm', wpm);

    // Also save to MongoDB
    final fluencyLevel =
        FluencyProgress.calculateFluencyLevel(newSessions, newAvgWpm);
    final progress = FluencyProgress(
      studentId: studentId,
      sessionsCompleted: newSessions,
      avgWpm: newAvgWpm,
      fluencyLevel: fluencyLevel,
      lastUpdated: DateTime.now(),
    );

    // Try to save to MongoDB (non-blocking)
    FluencyService.saveFluencyProgress(progress).then((success) {
      if (success) {
        AppLogger.info('Fluency progress saved to MongoDB');
      }
    });

    // Also save a task-level score record for analytics
    TaskScoreService.saveTaskScore(
      studentId: studentId,
      taskName: 'reading_fluency',
      score: newAvgWpm,
      metadata: {
        'avgWer': newAvgWer,
        'sessionsCompleted': newSessions,
        'breakdownLevel': newBreakdownLevel,
      },
    ).then((ok) {
      if (ok) AppLogger.info('Task score saved for reading_fluency');
    });

    setState(() {
      sessionsCompleted = newSessions;
      avgWpm = newAvgWpm;
      avgWer = newAvgWer;
      breakdownLevel = newBreakdownLevel;
    });
  }

  void _start() {
    setState(() {
      errorCount = 0;
      wordRead = List<bool>.filled(words.length, false);
      elapsed = Duration.zero;
      _startTime = DateTime.now();
      _endTime = null;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() {
          if (_startTime != null) {
            elapsed = DateTime.now().difference(_startTime!);
          }
        });
      });
    });
  }

  void _tapWord(int index) {
    if (_startTime == null) return;
    if (wordRead[index]) return;
    setState(() {
      wordRead[index] = true;
      if (wordRead.every((r) => r)) {
        _endTime = DateTime.now();
        _timer?.cancel();
        final totalSeconds =
            _endTime!.difference(_startTime!).inMilliseconds / 1000.0;
        final minutes = totalSeconds / 60.0;
        final wpm = minutes > 0 ? (words.length / minutes) : 0.0;
        final wer = (errorCount / words.length) * 100;

        _saveSession(wpm, wer, errorCount);
        _showResultDialog(wpm, wer, totalSeconds);
      }
    });
  }

  void _recordError() {
    setState(() {
      errorCount++;
    });
  }

  void _skipCurrentSentence() {
    _timer?.cancel();
    _startTime = null;
    _endTime = null;
    currentSentenceIndex++;
    _loadNextSentence();
  }

  void _showResultDialog(double wpm, double wer, double totalSeconds) {
    final isBreakdown = wpm < 15 || wer > 20;
    final nextLevel = isBreakdown ? currentLevel - 1 : currentLevel + 1;
    final canAdjustLevel = nextLevel >= 1 && nextLevel <= 3;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('සැසි ප්‍රතිඵල'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('මට්ටම: $currentLevel'),
            Text('කාලය: ${totalSeconds.toStringAsFixed(1)} තත්පර'),
            Text('වචන/මිනිත්තු: ${wpm.toStringAsFixed(1)}'),
            Text('වචන දෝෂ අනුපාත: ${wer.toStringAsFixed(1)}%'),
            if (isBreakdown)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '⚠️ ප්‍රවාහිතාව බිඳී ගිය මට්ටම',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('සම්පූර්ණ සැසි: $sessionsCompleted'),
            Text('සාමාන්‍ය වචන/මිනිත්තු: ${avgWpm.toStringAsFixed(1)}'),
            Text('සාමාන්‍ය දෝෂ අනුපාත: ${avgWer.toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (canAdjustLevel) {
                setState(() {
                  currentLevel = nextLevel;
                  currentSentenceIndex = 0;
                  _loadNextSentence();
                });
              } else {
                // Show final results
                _showFinalResults();
              }
            },
            child: Text(
              canAdjustLevel
                  ? (isBreakdown ? 'පහළ මට්ටම' : 'ඉදිරි මට්ටම')
                  : 'අවසන්',
            ),
          )
        ],
      ),
    );
  }

  void _showFinalResults() {
    // Trigger MAB training loop reward
    VisualTrainingLoop().endLevel(accuracyDelta: 1.0);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('පරිමාණ සාරාංශ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ප්‍රවාහිතා සාරාංශ:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('සම්පූර්ණ සැසි: $sessionsCompleted'),
            Text('සාමාන්‍ය වචන/මිනිත්තු: ${avgWpm.toStringAsFixed(1)}'),
            Text('සාමාන්‍ය දෝෂ අනුපාත: ${avgWer.toStringAsFixed(1)}%'),
            if (breakdownLevel > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ප්‍රවාහිතාව බිඳී ගිය මට්ටම: $breakdownLevel',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onComplete != null) {
                widget.onComplete!();
                return;
              }
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('හරි'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seconds = elapsed.inMilliseconds / 1000.0;
    final minutes = seconds / 60.0;
    final currentWpm = minutes > 0 ? (words.length / minutes) : 0.0;
    final currentWer = (errorCount / (words.isNotEmpty ? words.length : 1)) * 100;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('අපි කියවමු!'),
            Text(
              'මට්ටම $currentLevel',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          SkipButton(taskName: 'reading_fluency', onSkipped: _skipCurrentSentence),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header with mascot
            Row(
              children: [
                ScaleTransition(
                  scale: _pulseController,
                  child: Image.asset(
                    'assets/images/welcome_owl.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'මට්ටම $currentLevel ඉගෙන ගිය',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentLevel == 1
                            ? '2-වචන සරල වාක්‍ය'
                            : currentLevel == 2
                                ? '3-වචන වාක්‍ය'
                                : '4-වචන සංකීර්ණ වාක්‍ය',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),

            // Reading sentence
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Column(
                  children: [
                    // Word buttons
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: List.generate(words.length, (i) {
                        final read = wordRead[i];
                        return GestureDetector(
                          onTap: () => _tapWord(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: read
                                  ? Colors.yellow.shade200
                                  : Colors.white,
                              border: Border.all(
                                color: Colors.teal.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                if (read)
                                  BoxShadow(
                                    color: Colors.yellow.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: Text(
                              words[i],
                              style: TextStyle(
                                fontSize: _typographyConfig.fontSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: _typographyConfig.letterSpacing,
                                height: _typographyConfig.lineHeight,
                                color: read ? Colors.brown : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Controls: Start, Error button, and Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('ආරම්භ කරන්න'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        // Error button (for teacher/researcher)
                        ElevatedButton.icon(
                          onPressed: _recordError,
                          icon: const Icon(Icons.error_outline),
                          label: Text('දෝෂ ($errorCount)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('කාලය',
                                style: TextStyle(fontSize: 12, color: Colors.black54)),
                            Text('${seconds.toStringAsFixed(1)}s',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('වචන/මිනිත්තු',
                                style: TextStyle(fontSize: 12, color: Colors.black54)),
                            Text(currentWpm.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('දෝෂ %',
                                style: TextStyle(fontSize: 12, color: Colors.black54)),
                            Text('${currentWer.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Instructions
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade400,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'පැහැදිලිව වචන කියවන්න',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ඉතිරි වචනට ටැප් කරන්න'
                      '\n\nගුරුවරයා: වචනක් වැරදුණු විට දෝෂ බටනය ටැප් කරන්න',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
