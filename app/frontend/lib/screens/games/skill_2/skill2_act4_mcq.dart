import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/telemetry_wrapper.dart';
import '../../../../models/curriculum_models.dart';
import '../../../../services/tts_service.dart';
import '../shared_templates/widgets/shared_game_layout.dart';
import '../../../../services/progress_service.dart';
import '../shared_widgets/shared_celebration_popup.dart';

/// Activity 4: වචනයට සවන් දී පින්තූරය සොයමු (Listen to Word & Find Image)
/// Template: audio_image_match_game
class Skill2Act4Mcq extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill2Act4Mcq({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill2Act4Mcq> createState() => _Skill2Act4McqState();
}

class _Skill2Act4McqState extends State<Skill2Act4Mcq> {
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<int> _selectedIndices = {};
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _attemptCount = 0;
  int _currentRoundIndex = 0;

  @override
  void initState() {
    super.initState();
    _attemptCount = 0;
    final skillId = widget.activityNode?.skillId ?? '';
    final activityId = widget.activityNode?.id ?? '';
    if (skillId.isNotEmpty && activityId.isNotEmpty) {
      _currentRoundIndex = ProgressService().getActivityState(
        skillId,
        activityId,
      );
    }
    final rounds = widget.activityNode?.rounds ?? [];
    if (_currentRoundIndex >= rounds.length && rounds.isNotEmpty) {
      _currentRoundIndex = 0;
    }
    _playAudioPrompt(autoPlay: true);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudioPrompt({bool autoPlay = false}) {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) return;

    final currentRound = rounds[_currentRoundIndex];
    final prompt = currentRound['prompt']?.toString() ?? 'ගැලපෙන පින්තූරය තෝරන්න';
    final targetWord = currentRound['target_word']?.toString() ?? '';

    String spokenInstruction;
    if (prompt.contains('සමාන') || prompt.contains('ගැලපෙන')) {
      spokenInstruction = '$targetWord, ශබ්දයට සමාන ශබ්දය තෝරන්න';
    } else {
      spokenInstruction = '$targetWord, ශබ්දය ඇති පින්තූරය තෝරන්න';
    }

    if (autoPlay && _lastSpokenInstruction == spokenInstruction) {
      return;
    }
    _lastSpokenInstruction = spokenInstruction;
    TtsService().speak(spokenInstruction, folder: 'skill_2');
  }

  void _checkAnswer(
    int index,
    List<int> correctIndices,
    int totalRounds,
  ) async {
    if (_isCorrect) return;

    final bool wasSelected = _selectedIndices.contains(index);
    setState(() {
      if (wasSelected) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });

    if (_selectedIndices.length == correctIndices.length) {
      _attemptCount++;
      bool isRight = _selectedIndices.containsAll(correctIndices);
      int score = isRight ? 100 : 0;

      if (isRight) {
        context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(score);
        setState(() {
          _isCorrect = true;
        });
        SoundUtils.playFeedback('audio/correct.mp3');

        _advanceRoundAfterDelay(totalRounds);
      } else {
        SoundUtils.playFeedback('audio/wrong.mp3');

        if (_attemptCount >= 2) {
          context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(0);
          setState(() {
            _selectedIndices.clear();
            _selectedIndices.addAll(correctIndices);
            _isCorrect = true;
          });
          _advanceRoundAfterDelay(totalRounds);
        } else {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _selectedIndices.clear();
              });
            }
          });
        }
      }
    } else if (!wasSelected) {
      if (correctIndices.contains(index)) {
        SoundUtils.playFeedback('audio/correct.mp3');
      } else {
        SoundUtils.playFeedback('audio/wrong.mp3');
      }
    }
  }

  void _advanceRoundAfterDelay(int totalRounds) {
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_currentRoundIndex < totalRounds - 1) {
        setState(() {
          _currentRoundIndex++;
          _attemptCount = 0;
          final sId = widget.activityNode?.skillId ?? '';
          final aId = widget.activityNode?.id ?? '';
          if (sId.isNotEmpty && aId.isNotEmpty) {
            int progress =
                ((_currentRoundIndex /
                            (widget.activityNode?.rounds.length ?? 1)) *
                        100)
                    .toInt();
            ProgressService().saveActivityScore(sId, aId, progress);
            ProgressService().saveActivityState(
              sId,
              aId,
              _currentRoundIndex,
            );
          }
          _selectedIndices.clear();
          _isCorrect = false;
        });
        _playAudioPrompt(autoPlay: true);
      } else {
        setState(() {
          _activityComplete = true;
          final sId = widget.activityNode?.skillId ?? '';
          final aId = widget.activityNode?.id ?? '';
          if (sId.isNotEmpty && aId.isNotEmpty) {
            ProgressService().saveActivityScore(sId, aId, 100);
            ProgressService().clearActivityState(sId, aId);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('වචනයට සවන් දී පින්තූරය සොයමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    if (rounds.length > 5) {
      rounds = rounds.sublist(0, 5);
    }

    final currentRound = rounds[_currentRoundIndex];
    final titleText =
        widget.activityNode?.title ?? 'වචනයට සවන් දී පින්තූරය සොයමු';
    final promptText =
        currentRound['prompt']?.toString() ?? 'අසා සිටින පින්තූරය තෝරන්න';
    var options =
        (currentRound['options'] as List?)?.map((e) => e.toString()).toList() ??
        ['🔵', '🟥', '🔺', '⭐'];

    List<int> correctIndices = [];
    if (currentRound['correct_indices'] != null) {
      correctIndices = List<int>.from(currentRound['correct_indices']);
    } else if (currentRound['correct_index'] != null) {
      correctIndices = [currentRound['correct_index'] as int];
    } else {
      correctIndices = [0];
    }

    if (widget.isRemedial && options.length > correctIndices.length) {
      // Reduce distractors to max 1 + correct items
      List<String> correctItems = correctIndices
          .map((idx) => options[idx])
          .toList();
      var distractors = options
          .where((item) => !correctItems.contains(item))
          .toList();
      if (distractors.isNotEmpty) distractors = distractors.sublist(0, 1);
      options = [...correctItems, ...distractors];
      options.shuffle();
      correctIndices = correctItems
          .map((item) => options.indexOf(item))
          .toList();
    }

    double itemSize;
    double spacing;
    double fontSize;
    final total = options.length;
    final bool hasLongText = options.any(
      (opt) => opt.toString().length > 4 || opt.toString().contains(' '),
    );

    if (total <= 2) {
      itemSize = 160.0;
      spacing = 32.0;
      fontSize = 72.0;
    } else if (total <= 4) {
      itemSize = 130.0;
      spacing = 16.0;
      fontSize = 56.0;
    } else if (total <= 6) {
      itemSize = 100.0;
      spacing = 12.0;
      fontSize = 48.0;
    } else if (total <= 9) {
      itemSize = 80.0;
      spacing = 10.0;
      fontSize = 40.0;
    } else {
      itemSize = 64.0;
      spacing = 8.0;
      fontSize = 32.0;
    }

    return SharedGameLayout(
      studentData: widget.studentData,
      activityTitle: widget.activityNode?.title ?? '',
      title: titleText,
      currentRoundIndex: _currentRoundIndex,
      totalRounds: rounds.length,
      isRoundComplete: _isCorrect,
      isActivityComplete: _activityComplete,
      onNext: () {
        final wrapper = context
            .findAncestorStateOfType<TelemetryWrapperState>();
        if (wrapper != null) {
          wrapper.completeActivity(context);
        } else {
          Navigator.pop(context, 100);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            // Standardized Instruction Card
            _buildInstructionCard(promptText),
            Builder(
              builder: (context) {
                final RegExp quoteRegex = RegExp(r"'(.*?)'");
                final match = quoteRegex.firstMatch(promptText);
                final displayWord =
                    currentRound['target_word']?.toString() ?? match?.group(1);

                if (displayWord != null && displayWord.isNotEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.warmAmber.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warmAmber.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          displayWord,
                          style: AppTypography.sinhala(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (correctIndices.length > 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'අකුරු ${correctIndices.length} ක් තෝරන්න (${_selectedIndices.length}/${correctIndices.length})',
                  style: AppTypography.sinhala(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE65100),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 20),
            ],

            // Answer Pool Container (consistent with other Skill 2 activities)
            Flexible(
              fit: FlexFit.loose,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Center(
                  child: Wrap(
                    key: ValueKey('round_$_currentRoundIndex'),
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.center,
                    children: List.generate(options.length, (index) {
                      final isSelected = _selectedIndices.contains(index);
                      final isRight =
                          isSelected && correctIndices.contains(index);
                      final isWrong =
                          isSelected && !correctIndices.contains(index);

                      return GestureDetector(
                        onTap: () =>
                            _checkAnswer(index, correctIndices, rounds.length),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: hasLongText ? null : itemSize,
                          height: hasLongText ? null : itemSize,
                          padding: hasLongText
                              ? const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                )
                              : null,
                          decoration: BoxDecoration(
                            color: isRight
                                ? const Color(
                                    0xFF6DBE6D,
                                  ).withValues(alpha: 0.15)
                                : isWrong
                                ? const Color(
                                    0xFFE87C6D,
                                  ).withValues(alpha: 0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isRight
                                  ? const Color(0xFF6DBE6D)
                                  : isWrong
                                  ? const Color(0xFFE87C6D)
                                  : AppColors.borderLight,
                              width: (isRight || isWrong) ? 4.0 : 3.0,
                            ),
                            boxShadow: [
                              if (isRight)
                                BoxShadow(
                                  color: const Color(
                                    0xFF6DBE6D,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                )
                              else if (isWrong)
                                BoxShadow(
                                  color: const Color(
                                    0xFFE87C6D,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                )
                              else
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              options[index],
                              style: TextStyle(
                                fontSize: hasLongText ? 24.0 : fontSize,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(String instruction) {
    return GestureDetector(
      onTap: () async {
        context
            .findAncestorStateOfType<TelemetryWrapperState>()
            ?.logAudioReplay();
        _playAudioPrompt();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.warmAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.warmAmber, width: 3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                instruction,
                style: AppTypography.sinhala(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warmAmber,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warmAmber.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
