import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/telemetry_wrapper.dart';
import '../../../models/curriculum_models.dart';
import '../../../services/tts_service.dart';
import '../shared_templates/widgets/shared_game_layout.dart';
import '../../../services/progress_service.dart';
import '../shared_widgets/shared_celebration_popup.dart';
import '../../../adaptive/controllers/adaptive_choice_controller.dart';
import '../../../adaptive/models/adaptive_scaffold_models.dart';
import '../../../adaptive/widgets/adaptive_answer_pool.dart';
import 'skill2_round_resolver.dart';

class Skill2Act3Audio extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;

  const Skill2Act3Audio({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill2Act3Audio> createState() => _Skill2Act3AudioState();
}

class _Skill2Act3AudioState extends State<Skill2Act3Audio> {
  final Skill2ItemAutoplayGate _autoplayGate = Skill2ItemAutoplayGate();
  final Skill2PromptReadiness _promptReadiness = Skill2PromptReadiness();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentRoundIndex = 0;
  bool _isRoundComplete = false;
  bool _activityComplete = false;

  late List<String> _options;
  int _correctIndex = 0;
  String _promptText = '';
  String _currentItemId = '';

  Set<int> _wrongIndices = {};
  final AdaptiveChoiceController<int> _choiceController =
      AdaptiveChoiceController<int>();
  String? _currentVariantId;

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
    _setupRound();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _playAudioPrompt(autoPlay: true);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _choiceController.dispose();
    super.dispose();
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
      _promptReadiness.prepare(_currentItemId);
      final roundData = resolved.data;

      _promptText =
          roundData['prompt']?.toString() ?? 'ශබ්දයට සවන්දී අකුර තෝරන්න';
      _options =
          (roundData['options'] as List?)?.map((e) => e.toString()).toList() ??
          [];

      final correctOption = roundData['correctOption']?.toString() ?? '';
      _correctIndex = _options.indexOf(correctOption);
      if (_correctIndex == -1) _correctIndex = 0;
      _choiceController.configure(
        List<AdaptiveOption<int>>.generate(
          _options.length,
          (index) => AdaptiveOption<int>(
            id: _optionId(index),
            value: index,
            role: index == _correctIndex
                ? AdaptiveOptionRole.target
                : AdaptiveOptionRole.phonologicalDistractor,
            metadata: <String, dynamic>{'label': _options[index]},
          ),
        ),
      );
    } else {
      _options = [];
    }

    _wrongIndices.clear();
    _isRoundComplete = false;
  }

  String _optionId(int index) => '${_currentItemId}_O${index + 1}';

  void _transitionToNextRound(Map<String, dynamic>? c4Result) {
    final rounds = widget.activityNode?.rounds ?? [];

    int? nextIdx;
    if (c4Result != null && c4Result.containsKey('next_action')) {
      final nextAction = c4Result['next_action'];

      if (nextAction['decision'] == 'CURRICULUM_COMPLETE' ||
          nextAction['decision'] == 'ACTIVITY_COMPLETE') {
        setState(() {
          _activityComplete = true;
        });
        final sId = widget.activityNode?.skillId ?? '';
        final aId = widget.activityNode?.id ?? '';
        if (sId.isNotEmpty && aId.isNotEmpty) {
          ProgressService().saveActivityScore(sId, aId, 100);
          ProgressService().clearActivityState(sId, aId);
        }
        return;
      }

      if (nextAction['next_item'] != null) {
        String nextItem = nextAction['next_item'];
        _currentVariantId = Skill2RoundResolver.variantFromItemId(nextItem);
        nextIdx = Skill2RoundResolver.roundIndexFromItemId(nextItem);
      }
    }

    setState(() {
      _currentRoundIndex = nextIdx ?? (_currentRoundIndex + 1);
      if (_currentRoundIndex >= rounds.length) {
        _activityComplete = true;
      } else {
        _setupRound();
      }
    });

    if (!_activityComplete) {
      Future.delayed(const Duration(milliseconds: 300), () async {
        await _playAudioPrompt(autoPlay: true);
      });
    }
  }

  Future<void> _playAudioPrompt({bool autoPlay = false}) async {
    String spokenInstruction = _promptText;

    if (_promptText.contains("ශබ්දයට සවන් දී අකුර තෝරන්න")) {
      final correctLetter =
          _options.isNotEmpty &&
              _correctIndex >= 0 &&
              _correctIndex < _options.length
          ? _options[_correctIndex]
          : '';
      if (correctLetter.isNotEmpty) {
        spokenInstruction = "ශබ්දයට සවන් දී $correctLetterයන්න තෝරන්න";
      }
    } else {
      spokenInstruction = _promptText
          .replaceAll('මා', 'ම')
          .replaceAllMapped(
            RegExp(r"'?(.)'? අකුර"),
            (match) => '${match.group(1)}, අකුර',
          )
          .replaceAllMapped(
            RegExp(r"'?(.)'? පින්තූරය"),
            (match) => '${match.group(1)}, පින්තූරය',
          )
          .replaceAllMapped(
            RegExp(r"'?(.)'? තෝරන්න"),
            (match) => '${match.group(1)}යන්න තෝරන්න',
          );
    }

    if (autoPlay && !_autoplayGate.shouldPlay(_currentItemId)) {
      return;
    }
    if (_promptReadiness.isLoading) return;

    final requestItemId = _currentItemId;
    final requestToken = _promptReadiness.begin(requestItemId);
    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    wrapper?.pauseHesitationTimer();
    if (mounted) setState(() {});

    final didPlay = await TtsService().speak(
      spokenInstruction,
      folder: 'skill_2',
      waitUntilComplete: true,
    );
    if (!mounted ||
        !_promptReadiness.finish(
          itemId: requestItemId,
          requestToken: requestToken,
          didPlay: didPlay,
        )) {
      return;
    }

    setState(() {});
    if (didPlay) {
      if (autoPlay) {
        // Required stimulus delivery is not part of the child's response time.
        wrapper?.resetRoundTimers(clearPreResponseEvidence: true);
      } else {
        wrapper?.resumeHesitationTimer();
      }
    }
  }

  void _checkAnswer(int index) async {
    if (_isRoundComplete ||
        _choiceController.removedIds.contains(_optionId(index)))
      return;

    final bool isRight = (index == _correctIndex);

    if (isRight) {
      setState(() {
        _isRoundComplete = true;
        _choiceController.markCorrect(_optionId(index));
      });
      SoundUtils.playFeedback('audio/correct.mp3');

      final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
      if (wrapper != null) {
        final result = await wrapper.completeAdaptiveRound(
          100,
          currentRoundIndex: _currentRoundIndex,
          itemId: _currentItemId,
          selectedAnswers: <String>[_options[index]],
        );
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) _transitionToNextRound(result);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) _transitionToNextRound(null);
        });
      }
    } else {
      SoundUtils.playFeedback('audio/wrong.mp3');
      setState(() {
        _wrongIndices.add(index);
        _choiceController.markIncorrect(_optionId(index));
      });

      final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
      if (wrapper != null) {
        final result = await wrapper.registerAdaptiveWrongAttempt(
          currentRoundIndex: _currentRoundIndex,
          itemId: _currentItemId,
          extraTelemetry: {
            "original_options_count": _options.length,
            "visible_option_ids": _choiceController.visibleOptions
                .map((option) => option.id)
                .toList(),
            "incorrect_option_ids": <String>[
              _optionId(index),
              ..._choiceController.visibleOptions
                  .where(
                    (option) =>
                        option.value != _correctIndex && option.value != index,
                  )
                  .map((option) => option.id),
            ],
            "correct_option_ids": <String>[_optionId(_correctIndex)],
            "selected_option_ids": <String>[_optionId(index)],
            "supported_actions": <String>[
              "REMOVE_OPTION",
              "HIGHLIGHT_OPTION",
              "REPLAY_INSTRUCTION",
            ],
            "minimum_visible_options": 2,
            "error_type": "phoneme_grapheme_confusion",
          },
        );
        wrapper.applyScaffoldResult<int>(
          controller: _choiceController,
          result: result,
          correctOptionIds: <String>[_optionId(_correctIndex)],
        );
      }

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _wrongIndices.remove(index);
            _choiceController.clearTransientFeedback();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('අකුර අසා හඳුනා ගනිමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    final titleText = widget.activityNode?.title ?? 'අකුර අසා හඳුනා ගනිමු';

    double itemSize;
    double spacing;
    double fontSize;
    final total = _options.length;
    final bool hasLongText = _options.any(
      (opt) => opt.length > 4 || opt.contains(' '),
    );

    if (total <= 2) {
      itemSize = 180.0;
      spacing = 32.0;
      fontSize = 84.0;
    } else if (total <= 5) {
      itemSize = 150.0;
      spacing = 24.0;
      fontSize = 72.0;
    } else if (total <= 6) {
      itemSize = 120.0;
      spacing = 16.0;
      fontSize = 56.0;
    } else {
      itemSize = 90.0;
      spacing = 12.0;
      fontSize = 44.0;
    }

    return SharedGameLayout(
      studentData: widget.studentData,
      activityTitle: widget.activityNode?.title ?? '',
      title: titleText,
      currentRoundIndex: _currentRoundIndex,
      totalRounds: rounds.length,
      isRoundComplete: _isRoundComplete,
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
            _buildInstructionCard(_promptText),
            const SizedBox(height: 64),
            Flexible(
              fit: FlexFit.loose,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: AdaptiveAnswerPool<int>(
                      controller: _choiceController,
                      spacing: spacing,
                      minExtent: itemSize,
                      maxExtent: itemSize,
                      itemBuilder: (context, option, state, extent) {
                        final index = option.value;
                        return _FloatingLetterCard(
                          key: ValueKey(option.id),
                          index: index,
                          child: AdaptiveOptionFrame(
                            state: state,
                            onTap: () => _checkAnswer(index),
                            width: hasLongText ? null : extent,
                            height: hasLongText ? null : extent,
                            padding: hasLongText
                                ? const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  )
                                : const EdgeInsets.all(12),
                            semanticLabel: _options[index],
                            child: Text(
                              _options[index],
                              style: TextStyle(
                                fontSize: hasLongText ? 24.0 : fontSize,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
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
        if (_promptReadiness.isLoading) return;
        context
            .findAncestorStateOfType<TelemetryWrapperState>()
            ?.logAudioReplay();
        await _playAudioPrompt();
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

class _FloatingLetterCard extends StatefulWidget {
  final Widget child;
  final int index;
  const _FloatingLetterCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<_FloatingLetterCard> createState() => _FloatingLetterCardState();
}

class _FloatingLetterCardState extends State<_FloatingLetterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500 + (widget.index * 150)),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
