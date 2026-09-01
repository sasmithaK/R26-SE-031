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

/// Activity 9: වචනයට සවන් දී පින්තූරය සොයමු (Listen to Word & Find Image)
/// Template: audio_image_match_game
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
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudioPrompt(autoPlay: true);
    });
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
    final audioText =
        currentRound['audio_text']?.toString() ??
        currentRound['prompt']?.toString() ??
        'වෘත්තය';
    String spokenInstruction = audioText
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
    
    if (autoPlay && _lastSpokenInstruction == spokenInstruction) {
      return;
    }
    _lastSpokenInstruction = spokenInstruction;
    TtsService().speak(spokenInstruction, folder: 'skill_2');
  }

  void _checkAnswer(int index, int correctIndex, int totalRounds, String selectedAnswer) async {
    if (_isCorrect) return;

    setState(() {
      _selectedIndex = index;
    });

    final bool isRight = (index == correctIndex);

    if (isRight) {
      context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(
        100,
        selectedAnswers: [selectedAnswer],
      );
      setState(() {
        _isCorrect = true;
      });
      SoundUtils.playFeedback('audio/correct.mp3');

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        if (_currentRoundIndex < totalRounds - 1) {
          setState(() {
            _currentRoundIndex++;
            final sId = widget.activityNode?.skillId ?? '';
            final aId = widget.activityNode?.id ?? '';
            if (sId.isNotEmpty && aId.isNotEmpty) {
              int progress =
                  ((_currentRoundIndex /
                              (widget.activityNode?.rounds.length ?? 1)) *
                          100)
                      .toInt();
              ProgressService().saveActivityScore(sId, aId, progress);
              ProgressService().saveActivityState(sId, aId, _currentRoundIndex);
            }
            _selectedIndex = null;
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
    } else {
      context.findAncestorStateOfType<TelemetryWrapperState>()?.logAttempt(
        isCorrect: false,
        selectedAnswers: [selectedAnswer],
        errorType: 'unknown_error',
      );
      SoundUtils.playFeedback('audio/wrong.mp3');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isCorrect) {
          setState(() {
            if (_selectedIndex == index) {
              _selectedIndex = null;
            }
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
    final promptText = 'ශබ්දයට සවන්දී අකුර තෝරන්න';
    var options =
        (currentRound['options'] as List?)?.map((e) => e.toString()).toList() ??
        ['🔵', '🟥', '🔺', '⭐'];
    var correctIndex = (currentRound['correct_index'] as int?) ?? 0;

    if (widget.isRemedial && options.length > 2) {
      // Reduce distractors to max 1 + 1 correct = 2 options total
      final correctItem = options[correctIndex];
      var distractors = options.where((item) => item != correctItem).toList();
      if (distractors.isNotEmpty) distractors = distractors.sublist(0, 1);
      options = [correctItem, ...distractors];
      options.shuffle();
      correctIndex = options.indexOf(correctItem);
    }

    double itemSize;
    double spacing;
    double fontSize;
    final total = options.length;
    final bool hasLongText = options.any(
      (opt) => opt.toString().length > 4 || opt.toString().contains(' '),
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
    } else if (total <= 9) {
      itemSize = 90.0;
      spacing = 12.0;
      fontSize = 44.0;
    } else {
      itemSize = 72.0;
      spacing = 8.0;
      fontSize = 36.0;
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
            const SizedBox(height: 64),

            // Image Option Cards Grid
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
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      alignment: WrapAlignment.center,
                      children: List.generate(options.length, (index) {
                        final isSelected = (_selectedIndex == index);
                        final isRight = isSelected && (index == correctIndex);
                        final isWrong = isSelected && (index != correctIndex);

                        return _FloatingLetterCard(
                          key: ValueKey('${_currentRoundIndex}_$index'),
                          index: index,
                          child: GestureDetector(
                            onTap: () => _checkAnswer(
                              index,
                              correctIndex,
                              rounds.length,
                              options[index],
                            ),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
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
                          ),
                        );
                      }),
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
