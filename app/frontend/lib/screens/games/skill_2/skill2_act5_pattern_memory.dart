import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/telemetry_wrapper.dart';
import '../../../models/curriculum_models.dart';
import '../shared_templates/widgets/shared_game_layout.dart';
import '../../../services/progress_service.dart';
import '../shared_widgets/shared_celebration_popup.dart';
import '../../../services/tts_service.dart';
import '../../../adaptive/controllers/adaptive_choice_controller.dart';
import '../../../adaptive/models/adaptive_scaffold_models.dart';
import '../../../adaptive/widgets/adaptive_answer_pool.dart';
import 'skill2_round_resolver.dart';

/// Activity 5: අකුරු මතකයෙන් සකසමු (Remember the Pattern)
/// Template: pattern_memory_game
class Skill2Act5PatternMemory extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill2Act5PatternMemory({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill2Act5PatternMemory> createState() =>
      _Skill2Act5PatternMemoryState();
}

class _Skill2Act5PatternMemoryState extends State<Skill2Act5PatternMemory>
    with SingleTickerProviderStateMixin {
  final Skill2ItemAutoplayGate _autoplayGate = Skill2ItemAutoplayGate();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMemorizing = true;
  int _countdown = 3;
  Timer? _timer;
  late AnimationController _timerController;

  final List<String> _userSequence = [];
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;

  String _currentItemId = '';
  String? _currentVariantId;
  Map<String, dynamic> _activeRoundData = <String, dynamic>{};

  String? _wrongTappedOption;
  String? _correctTappedOption;

  final AdaptiveChoiceController<String> _choiceController =
      AdaptiveChoiceController<String>();

  @override
  void initState() {
    super.initState();
    final skillId = widget.activityNode?.skillId ?? '';
    final activityId = widget.activityNode?.id ?? '';
    if (skillId.isNotEmpty && activityId.isNotEmpty) {
      _currentRoundIndex = ProgressService().getActivityState(
        skillId,
        activityId,
      );
    }
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isNotEmpty && _currentRoundIndex >= rounds.length) {
      _currentRoundIndex = 0;
    }
    _timerController = AnimationController(vsync: this);
    _setupRound();
    _startMemorizeTimer();
  }

  void _setupRound() {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isNotEmpty && _currentRoundIndex < rounds.length) {
      final resolved = Skill2RoundResolver.resolve(
        activity: widget.activityNode,
        roundIndex: _currentRoundIndex,
        variantId: _currentVariantId,
      );
      _currentItemId = resolved.itemId;
      _currentVariantId = resolved.variantId;
      _activeRoundData = resolved.data;
    } else {
      _currentItemId = '';
      _activeRoundData = <String, dynamic>{};
    }
    final data = _getCurrentRoundData();
    final pattern =
        (data['pattern'] as List?)?.map((value) => value.toString()).toList() ??
        const <String>[];
    final options =
        (data['options'] as List?)?.map((value) => value.toString()).toList() ??
        const <String>[];
    _choiceController.configure(
      List<AdaptiveOption<String>>.generate(
        options.length,
        (index) => AdaptiveOption<String>(
          id: _optionId(index),
          value: options[index],
          role: pattern.contains(options[index])
              ? AdaptiveOptionRole.sequenceToken
              : AdaptiveOptionRole.unrelatedDistractor,
        ),
      ),
    );
    _isCorrect = false;
  }

  String _optionId(int index) => '${_currentItemId}_O${index + 1}';

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _timerController.dispose();
    _choiceController.dispose();
    super.dispose();
  }

  List<dynamic> get _rounds {
    var r = widget.activityNode?.rounds ?? [];
    return r.length > 5 ? r.sublist(0, 5) : r;
  }

  Map<String, dynamic> _getCurrentRoundData() {
    return _activeRoundData;
  }

  Future<void> _playCurrentInstruction({
    bool autoPlay = false,
    bool waitUntilComplete = false,
  }) async {
    final promptText = _isMemorizing
        ? 'රටාව මතක තබා ගන්න!'
        : 'රටාව නැවත සකසන්න';
    String spokenInstruction = promptText
        .replaceAll('මා', 'ම')
        .replaceAllMapped(
          RegExp(r"'?(.)'? අකුර"),
          (match) => '${match.group(1)}, අකුර',
        )
        .replaceAllMapped(
          RegExp(r"'?(.)'? පින්තූරය"),
          (match) => '${match.group(1)}, පින්තූරය',
        );

    final phase = _isMemorizing ? 'memorize' : 'recall';
    if (autoPlay && !_autoplayGate.shouldPlay('$_currentItemId:$phase')) {
      return;
    }

    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    final isManualReplay = !autoPlay;
    if (isManualReplay) {
      wrapper?.pauseHesitationTimer();
    }

    try {
      await TtsService().speak(
        spokenInstruction,
        folder: 'skill_2',
        // A manual replay is learner-requested listening time, so wait for it
        // to finish before restarting hesitation measurement.
        waitUntilComplete: waitUntilComplete || isManualReplay,
      );
    } finally {
      if (isManualReplay && mounted) {
        wrapper?.resumeHesitationTimer();
      }
    }
  }

  void _startMemorizeTimer() {
    final roundData = _getCurrentRoundData();
    if (roundData.isEmpty) return;
    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    wrapper?.pauseHesitationTimer();

    final showSeconds = (roundData['show_seconds'] as int?) ?? 4;

    setState(() {
      _isMemorizing = true;
      _countdown = showSeconds;
      _userSequence.clear();
      _isCorrect = false;
      _choiceController.reset();
    });

    _playCurrentInstruction(autoPlay: true);

    _timerController.duration = Duration(seconds: showSeconds);
    _timerController.forward(from: 0.0);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isMemorizing = false;
        });
        await _playCurrentInstruction(autoPlay: true, waitUntilComplete: true);

        // Reset telemetry timers so memorization time isn't counted as hesitation/latency
        wrapper?.resetRoundTimers(clearPreResponseEvidence: true);
      }
    });
  }

  void _transitionToNextRound(Map<String, dynamic>? nextAction) {
    if (nextAction != null && nextAction['decision'] == 'ACTIVITY_COMPLETE') {
      _completeActivity();
      return;
    }

    int totalRounds = widget.activityNode?.rounds.length ?? 1;
    setState(() {
      if (nextAction != null && nextAction.containsKey('next_item')) {
        final nextItem = nextAction['next_item'].toString();
        final nextRound = Skill2RoundResolver.roundIndexFromItemId(nextItem);
        if (nextRound != null) {
          _currentRoundIndex = nextRound;
        } else {
          _currentRoundIndex++;
        }
        _currentVariantId = Skill2RoundResolver.variantFromItemId(nextItem);
      } else {
        _currentVariantId = null;
        _currentRoundIndex++;
      }

      final sId = widget.activityNode?.skillId ?? '';
      final aId = widget.activityNode?.id ?? '';
      if (sId.isNotEmpty && aId.isNotEmpty) {
        int progress = ((_currentRoundIndex / totalRounds) * 100).toInt();
        ProgressService().saveActivityScore(sId, aId, progress);
        ProgressService().saveActivityState(sId, aId, _currentRoundIndex);
      }
      _setupRound();
    });

    if (_currentRoundIndex < totalRounds || _currentVariantId != null) {
      _startMemorizeTimer();
    } else {
      _completeActivity();
    }
  }

  void _completeActivity() {
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

  void _addItemToUserSequence(
    String item,
    String optionId,
    List<String> targetPattern,
    List<String> allOptions,
    int totalRounds,
  ) async {
    if (_isCorrect || _isMemorizing || _wrongTappedOption != null) return;

    final currentIndex = _userSequence.length;
    if (item != targetPattern[currentIndex]) {
      // Wrong item picked
      setState(() {
        _wrongTappedOption = item;
        _choiceController.markIncorrect(optionId);
      });
      SoundUtils.playFeedback('audio/wrong.mp3');

      // Calculate genuine distractors
      final genuineDistractors = _choiceController.visibleOptions
          .where((option) => !targetPattern.contains(option.value))
          .map((option) => option.id)
          .toList();
      final expectedIds = _choiceController.visibleOptions
          .where((option) => option.value == targetPattern[currentIndex])
          .map((option) => option.id)
          .toList();

      final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
      if (wrapper != null) {
        final result = await wrapper.registerAdaptiveWrongAttempt(
          itemId: _currentItemId,
          extraTelemetry: {
            "selected_option_id": item,
            "selected_option_ids": [optionId],
            "correct_option_ids": expectedIds,
            "original_options_count": allOptions.length,
            "incorrect_option_ids": genuineDistractors,
            "visible_option_ids": _choiceController.visibleOptions
                .map((option) => option.id)
                .toList(),
            "supported_actions": [
              "HIGHLIGHT_OPTION",
              "REVEAL_FIRST_TOKEN",
              "REPLAY_INSTRUCTION",
            ],
            "minimum_visible_options": 2,
            "error_type": "sequence_memory_error",
          },
        );
        wrapper.applyScaffoldResult<String>(
          controller: _choiceController,
          result: result,
          correctOptionIds: expectedIds,
        );
      }

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _wrongTappedOption = null;
            _choiceController.clearTransientFeedback();
            // DO NOT clear user sequence!
          });
        }
      });
      return;
    }

    // Correct item picked
    setState(() {
      _correctTappedOption = item;
      _userSequence.add(item);
      _choiceController.markCorrect(optionId);
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          if (_correctTappedOption == item) {
            _correctTappedOption = null;
          }
        });
      }
    });

    // Check if pattern completed
    if (_userSequence.length == targetPattern.length) {
      setState(() {
        _isCorrect = true;
      });
      SoundUtils.playFeedback('audio/correct.mp3');

      final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
      if (wrapper != null) {
        final result = await wrapper.completeAdaptiveRound(
          100,
          itemId: _currentItemId,
          selectedAnswers: List<String>.from(_userSequence),
        );
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (!mounted) return;
          _transitionToNextRound(result?['next_action']);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (!mounted) return;
          _transitionToNextRound(null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roundData = _getCurrentRoundData();
    if (roundData.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('රටාව මතක තබා ගනිමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    final titleText = widget.activityNode?.title ?? 'රටාව මතක තබා ගනිමු';
    final targetPattern =
        (roundData['pattern'] as List?)?.map((e) => e.toString()).toList() ??
        ['🔴', '🔵'];
    var options =
        (roundData['options'] as List?)?.map((e) => e.toString()).toList() ??
        ['🔴', '🔵', '🟢'];

    double itemSize;
    double spacing;
    double fontSize;
    final total = options.length;
    final bool hasLongText = options.any(
      (opt) => opt.toString().length > 4 || opt.toString().contains(' '),
    );

    if (total <= 2) {
      itemSize = 150.0;
      spacing = 24.0;
      fontSize = 80.0;
    } else if (total <= 4) {
      itemSize = 120.0;
      spacing = 16.0;
      fontSize = 64.0;
    } else if (total <= 6) {
      itemSize = 100.0;
      spacing = 12.0;
      fontSize = 56.0;
    } else {
      itemSize = 80.0;
      spacing = 8.0;
      fontSize = 44.0;
    }

    double topSlotSize = 120.0;
    double topFontSize = 72.0;
    double topSlotShrinkSize = 80.0;
    double topFontShrinkSize = 48.0;

    if (targetPattern.length >= 4) {
      topSlotSize = 70.0;
      topFontSize = 40.0;
      topSlotShrinkSize = 60.0;
      topFontShrinkSize = 32.0;
    } else if (targetPattern.length == 3) {
      topSlotSize = 95.0;
      topFontSize = 56.0;
      topSlotShrinkSize = 75.0;
      topFontShrinkSize = 44.0;
    }

    return SharedGameLayout(
      studentData: widget.studentData,
      activityTitle: widget.activityNode?.title ?? '',
      title: titleText,
      currentRoundIndex: _currentRoundIndex,
      totalRounds: _rounds.length,
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
            Expanded(
              child: Column(
                children: [
                  // Instruction Banner
                  _buildInstructionCard(
                    _isMemorizing ? 'රටාව මතක තබා ගන්න!' : 'රටාව නැවත සකසන්න',
                  ),
                  const SizedBox(height: 8),

                  // Timer Bar
                  _buildTimerBar(),
                  const SizedBox(height: 16),

                  // Target Pattern View / Recall Slots (Premium Wooden Board)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5AB), // Light wooden board
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFD4B872),
                        width: 4,
                      ),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: List.generate(targetPattern.length, (i) {
                        final itemToShow = _isMemorizing
                            ? targetPattern[i]
                            : (i < _userSequence.length
                                  ? _userSequence[i]
                                  : '?');
                        final isFilled =
                            _isMemorizing || i < _userSequence.length;
                        // Determine if this is the currently expected slot and there is an error
                        final isCurrentWrong =
                            (_wrongTappedOption != null) &&
                            (i == _userSequence.length);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isMemorizing
                              ? topSlotSize
                              : topSlotShrinkSize,
                          height: _isMemorizing
                              ? topSlotSize
                              : topSlotShrinkSize,
                          decoration: BoxDecoration(
                            color: isCurrentWrong
                                ? const Color(0xFFE87C6D)
                                : (isFilled
                                      ? (_isMemorizing
                                            ? Colors.white
                                            : const Color(0xFF6DBE6D))
                                      : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentWrong
                                  ? const Color(0xFFE87C6D)
                                  : (isFilled
                                        ? (_isMemorizing
                                              ? AppColors.warmAmber.withValues(
                                                  alpha: 0.4,
                                                )
                                              : const Color(0xFF6DBE6D))
                                        : Colors.black.withValues(alpha: 0.1)),
                              width: 2.0,
                            ),
                            boxShadow: (isFilled && isCurrentWrong)
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFE87C6D,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              itemToShow,
                              style: TextStyle(
                                fontSize: _isMemorizing
                                    ? topFontSize
                                    : topFontShrinkSize,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                                color: isCurrentWrong
                                    ? Colors.white
                                    : (isFilled
                                          ? (_isMemorizing
                                                ? AppColors.textPrimary
                                                : Colors.white)
                                          : Colors.black26),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Recall Candidate Palette (Disabled while memorizing)
                  if (!_isMemorizing) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                          ),
                          child: AdaptiveAnswerPool<String>(
                            controller: _choiceController,
                            spacing: 16,
                            minExtent: itemSize,
                            maxExtent: itemSize,
                            itemBuilder: (context, option, state, extent) {
                              return AdaptiveOptionFrame(
                                state: state,
                                onTap: () => _addItemToUserSequence(
                                  option.value,
                                  option.id,
                                  targetPattern,
                                  options,
                                  _rounds.length,
                                ),
                                width: hasLongText ? null : extent,
                                height: hasLongText ? null : extent,
                                padding: hasLongText
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      )
                                    : const EdgeInsets.all(12),
                                semanticLabel: option.value,
                                child: Text(
                                  option.value,
                                  style: TextStyle(
                                    fontSize: hasLongText ? 40.0 : fontSize,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],
                  const SizedBox(height: 24),
                ],
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
        await _playCurrentInstruction();
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

  Widget _buildTimerBar() {
    if (!_isMemorizing) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedBuilder(
        animation: _timerController,
        builder: (context, child) {
          final progress = (1.0 - _timerController.value).clamp(0.0, 1.0);

          Color barColor = const Color(0xFF6DBE6D);
          if (progress < 0.25) {
            barColor = const Color(0xFFFF4B4B);
          } else if (progress < 0.5) {
            barColor = const Color(0xFFF9C623);
          }

          return Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
