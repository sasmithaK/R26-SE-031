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
class Skill4Act1Mcq extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill4Act1Mcq({super.key, this.activityNode, this.isRemedial = false, this.studentData});

  @override
  State<Skill4Act1Mcq> createState() => _Skill4Act1McqState();
}

class _Skill4Act1McqState extends State<Skill4Act1Mcq> {
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;
  int _attemptCount = 0;

  @override
  void initState() {
    super.initState();
    _attemptCount = 0;
    final skillId = widget.activityNode?.skillId ?? '';
    final activityId = widget.activityNode?.id ?? '';
    if (skillId.isNotEmpty && activityId.isNotEmpty) {
      _currentRoundIndex = ProgressService().getActivityState(skillId, activityId);
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
    final audioText = currentRound['audio_text']?.toString() ?? currentRound['prompt']?.toString() ?? 'වෘත්තය';
    
    if (autoPlay && _lastSpokenInstruction == audioText) {
      return;
    }
    _lastSpokenInstruction = audioText;
    TtsService().speak(audioText, folder: 'skill_4');
  }

  void _checkAnswer(int index, int correctIndex, int totalRounds) async {
    if (_isCorrect) return;

    _attemptCount++;
    setState(() {
      _selectedIndex = index;
    });

    final bool isRight = (index == correctIndex);
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
          _selectedIndex = correctIndex;
          _isCorrect = true;
        });
        _advanceRoundAfterDelay(totalRounds);
      } else {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted && !_isCorrect) {
            setState(() {
              _selectedIndex = null;
            });
          }
        });
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
            int progress = ((_currentRoundIndex / (widget.activityNode?.rounds.length ?? 1)) * 100).toInt();
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
    final titleText = widget.activityNode?.title ?? 'වචනයට සවන් දී පින්තූරය සොයමු';
    final promptText = currentRound['prompt']?.toString() ?? 'අසා සිටින පින්තූරය තෝරන්න';
    final imageUrl = currentRound['image_url']?.toString();
    var options = (currentRound['options'] as List?)?.map((e) => e.toString()).toList() ?? ['🔵', '🟥', '🔺', '⭐'];
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
    final bool hasLongText = options.any((opt) => opt.toString().length > 4 || opt.toString().contains(' '));

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
        final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
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
            // Premium Speaker Card (Instruction)
            GestureDetector(
              onTap: () {
                context.findAncestorStateOfType<TelemetryWrapperState>()?.logAudioReplay();
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
                        promptText,
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.warmAmber,
                      ),
                      child: const Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (imageUrl != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.warmAmber.withValues(alpha: 0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmAmber.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Image Option Cards Grid
              Expanded(
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

                      return GestureDetector(
                        onTap: () => _checkAnswer(index, correctIndex, rounds.length),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: hasLongText ? null : itemSize,
                          height: hasLongText ? null : itemSize,
                          padding: hasLongText ? EdgeInsets.symmetric(horizontal: 24, vertical: options.length <= 2 ? 24 : 16) : null,
                          decoration: BoxDecoration(
                            color: isRight
                                ? AppColors.gentleGreen.withValues(alpha: 0.3)
                                : isWrong
                                    ? AppColors.softCoral.withValues(alpha: 0.3)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isRight
                                  ? AppColors.gentleGreen
                                  : isWrong
                                      ? AppColors.softCoral
                                      : AppColors.borderLight,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Center(
                            child: Text(options[index], style: TextStyle(fontSize: hasLongText ? (options.length <= 2 ? 30.0 : 24.0) : fontSize), textAlign: TextAlign.center),
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
}
