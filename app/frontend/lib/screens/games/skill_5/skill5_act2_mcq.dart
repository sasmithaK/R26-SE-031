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

/// Skill 5 Activity 2
/// Premium redesign with interactive animations and world-class UI
class Skill5Act2Mcq extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill5Act2Mcq({super.key, this.activityNode, this.isRemedial = false, this.studentData});

  @override
  State<Skill5Act2Mcq> createState() => _Skill5Act2McqState();
}

class _Skill5Act2McqState extends State<Skill5Act2Mcq>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _speakerBounceController;
  late Animation<double> _speakerBounceAnimation;

  @override
  void initState() {
    super.initState();
    final skillId = widget.activityNode?.skillId ?? '';
    final activityId = widget.activityNode?.id ?? '';
    if (skillId.isNotEmpty && activityId.isNotEmpty) {
      _currentRoundIndex = ProgressService().getActivityState(skillId, activityId);
    }
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isNotEmpty && _currentRoundIndex >= rounds.length) {
      _currentRoundIndex = 0;
    }

    // Pulsing glow for the speaker button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Speaker bounce when tapped
    _speakerBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _speakerBounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _speakerBounceController, curve: Curves.elasticOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudioPrompt();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speakerBounceController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudioPrompt() {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) return;

    final currentRound = rounds[_currentRoundIndex];
    final audioText = currentRound['audio_text']?.toString() ?? currentRound['prompt']?.toString() ?? 'වෘත්තය';
    TtsService().speak(audioText);

    // Bounce the speaker icon
    _speakerBounceController.forward().then((_) {
      _speakerBounceController.reverse();
    });
  }

  void _checkAnswer(int index, int correctIndex, int totalRounds) async {
    if (_isCorrect) return;
    if (_selectedIndex != null) return;

    setState(() {
      _selectedIndex = index;
    });

    final bool isRight = (index == correctIndex);
    int score = isRight ? 100 : 0;
    context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(score);

    if (isRight) {
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
                int progress = ((_currentRoundIndex / (widget.activityNode?.rounds.length ?? 1)) * 100).toInt();
                ProgressService().saveActivityScore(sId, aId, progress);
                ProgressService().saveActivityState(sId, aId, _currentRoundIndex);
              }
            _selectedIndex = null;
            _isCorrect = false;
          });
          _playAudioPrompt();
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
      SoundUtils.playFeedback('audio/wrong.mp3');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _selectedIndex = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ශබ්දයට සවන් දී වාක්‍ය තෝරන්න')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    if (rounds.length > 5) {
      rounds = rounds.sublist(0, 5);
    }

    final currentRound = rounds[_currentRoundIndex];
    final titleText = widget.activityNode?.title ?? 'ශබ්දයට සවන් දී වාක්‍ය තෝරන්න';
    var options = (currentRound['options'] as List?)?.map((e) => e.toString()).toList() ?? ['🔵', '🟥', '🔺', '⭐'];
    var correctIndex = (currentRound['correct_index'] as int?) ?? 0;

    if (widget.isRemedial && options.length > 2) {
      final correctItem = options[correctIndex];
      var distractors = options.where((item) => item != correctItem).toList();
      if (distractors.isNotEmpty) distractors = distractors.sublist(0, 1);
      options = [correctItem, ...distractors];
      options.shuffle();
      correctIndex = options.indexOf(correctItem);
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // ── Premium Speaker Card ──
              _buildSpeakerCard(),

              const SizedBox(height: 32),

              // ── Premium Answer Pool ──
              _buildAnswerPool(options, correctIndex, rounds.length),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Premium animated speaker card — tap to hear the word
  Widget _buildSpeakerCard() {
    return GestureDetector(
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
                'ශබ්දයට සවන් දී වාක්‍ය තෝරන්න',
                style: AppTypography.sinhala(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            ScaleTransition(
              scale: _speakerBounceAnimation,
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }

  /// Premium answer pool container with frosted glass effect
  Widget _buildAnswerPool(List<String> options, int correctIndex, int totalRounds) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        key: ValueKey(_currentRoundIndex),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(options.length, (index) {
          return _buildOptionTile(index, options[index], correctIndex, totalRounds, options.length);
        }),
      ),
    );
  }

  Widget _buildOptionTile(int index, String optionText, int correctIndex, int totalRounds, int totalOptions) {
    final isSelected = (_selectedIndex == index);
    final isRight = isSelected && (index == correctIndex);
    final isWrong = isSelected && (index != correctIndex);
    final isHidden = _isCorrect && (index != correctIndex);

    // Detect if the word is complex (has pillam or is multi-character)
    

    double tileHeight;
    double fontSize;

    if (totalOptions <= 2) {
      tileHeight = 100.0;
      fontSize = 38.0;
    } else if (totalOptions == 3) {
      tileHeight = 85.0;
      fontSize = 30.0;
    } else {
      tileHeight = 70.0;
      fontSize = 24.0;
    }

    // Color scheme
    Color tileColor = Colors.white;
    Color borderColor = const Color(0xFFE5E7EB);
    double borderWidth = 1.5;
    List<BoxShadow> shadows = [
      BoxShadow(
        color: const Color(0xFF4A90D9).withValues(alpha: 0.08),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ];
    Color textColor = AppColors.textPrimary;

    if (isRight) {
      tileColor = const Color(0xFF6DBE6D).withValues(alpha: 0.15);
      borderColor = const Color(0xFF6DBE6D);
      borderWidth = 4.0;
      shadows = [
        BoxShadow(
          color: const Color(0xFF6DBE6D).withValues(alpha: 0.3),
          blurRadius: 16,
          spreadRadius: 2,
        )
      ];
      
    } else if (isWrong) {
      tileColor = const Color(0xFFE87C6D).withValues(alpha: 0.15);
      borderColor = const Color(0xFFE87C6D);
      borderWidth = 4.0;
      shadows = [
        BoxShadow(
          color: const Color(0xFFE87C6D).withValues(alpha: 0.3),
          blurRadius: 16,
          spreadRadius: 2,
        )
      ];
      
    }

    return GestureDetector(
      onTap: () => _checkAnswer(index, correctIndex, totalRounds),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isHidden ? 0.0 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12.0),
          width: double.infinity,
          height: tileHeight,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: shadows,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  optionText,
                  maxLines: 1,
                  style: AppTypography.sinhala(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
