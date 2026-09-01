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

/// Skill 3 Activity 2 (Word Formation MCQ)
/// Premium redesign: separates instruction from visual equation.
class Skill3Act2WordFormation extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill3Act2WordFormation({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill3Act2WordFormation> createState() =>
      _Skill3Act2WordFormationState();
}

class _Skill3Act2WordFormationState extends State<Skill3Act2WordFormation>
    with TickerProviderStateMixin {
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;
  int _attemptCount = 0;

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
      _currentRoundIndex = ProgressService().getActivityState(
        skillId,
        activityId,
      );
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
      CurvedAnimation(
        parent: _speakerBounceController,
        curve: Curves.elasticOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudioPrompt(autoPlay: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speakerBounceController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudioPrompt({bool autoPlay = false}) {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) return;

    final currentRound = rounds[_currentRoundIndex];
    // TTS should read the full prompt from JSON (e.g. "'ම' + 'ල' එකතු වූ විට...")
    final audioText = 'අකුරු එකතු කර සාදන වචනය තෝරන්න';
    String spokenInstruction = audioText
        .replaceAll('මා', 'ම')
        .replaceAllMapped(
          RegExp(r"'?(.)'? අකුර"),
          (match) => '${match.group(1)}, අකුර',
        )
        .replaceAllMapped(
          RegExp(r"'?(.)'? පින්තූරය"),
          (match) => '${match.group(1)}, පින්තූරය',
        );
    
    if (autoPlay && _lastSpokenInstruction == spokenInstruction) {
      return;
    }
    _lastSpokenInstruction = spokenInstruction;
    TtsService().speak(spokenInstruction, folder: 'skill_3');

    // Bounce the speaker icon
    _speakerBounceController.forward().then((_) {
      _speakerBounceController.reverse();
    });
  }

  void _checkAnswer(int index, int correctIndex, int totalRounds) async {
    if (_isCorrect) return;
    if (_selectedIndex != null) return;

    _attemptCount++;
    setState(() {
      _selectedIndex = index;
    });

    final bool isRight = (index == correctIndex);
    int score = isRight ? 100 : 0;

    if (isRight) {
      context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(
        score,
      );
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
          if (!mounted) return;
          setState(() {
            _selectedIndex = null;
          });
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
  }

  /// Extracts the letters inside single quotes from the prompt string.
  /// Example: "'ම' + 'ල' එකතු වූ විට හැදෙන වචනය කුමක්ද?" -> ["ම", "ල"]
  List<String> _extractEquationParts(String promptText) {
    final regex = RegExp(r"'([^']+)'");
    final matches = regex.allMatches(promptText);
    return matches
        .map((m) => m.group(1) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('වචනය සකසන්න')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    if (rounds.length > 5) {
      rounds = rounds.sublist(0, 5);
    }

    final currentRound = rounds[_currentRoundIndex];
    final titleText = widget.activityNode?.title ?? 'වචනය සකසන්න';
    final promptText = currentRound['prompt']?.toString() ?? '';

    var options =
        (currentRound['options'] as List?)?.map((e) => e.toString()).toList() ??
        ['🔵', '🟥', '🔺', '⭐'];
    var correctIndex = (currentRound['correct_index'] as int?) ?? 0;

    if (widget.isRemedial && options.length > 2) {
      final correctItem = options[correctIndex];
      var distractors = options.where((item) => item != correctItem).toList();
      if (distractors.isNotEmpty) distractors = distractors.sublist(0, 1);
      options = [correctItem, ...distractors];
      options.shuffle();
      correctIndex = options.indexOf(correctItem);
    }

    final equationParts = _extractEquationParts(promptText);

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
            const SizedBox(height: 8),

            // ── Premium Speaker Card (Common Instruction) ──
            _buildSpeakerCard(),

            const Spacer(flex: 1),

            // ── Visual Equation Component (e.g. ම + ල) ──
            if (equationParts.isNotEmpty) _buildEquationDisplay(equationParts),

            const Spacer(flex: 1),

            // ── Premium Answer Pool ──
            _buildAnswerPool(options, correctIndex, rounds.length),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  /// Premium animated speaker card with the generic instruction
  Widget _buildSpeakerCard() {
    return GestureDetector(
      onTap: () {
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
                'අකුරු එකතු කර සාදන වචනය තෝරන්න',
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

  /// Clean equation component matching Act 1 image square styling
  Widget _buildEquationDisplay(List<String> parts) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            // Letter Box mimicking Act 1 Image Square
            Container(
              width: parts[i].length > 1 ? 120.0 : 100.0,
              height: 100.0,
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
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  parts[i],
                  style: AppTypography.sinhala(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ),

            // Plus Sign
            if (i < parts.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warmAmber,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Premium answer pool container with frosted glass effect
  Widget _buildAnswerPool(
    List<String> options,
    int correctIndex,
    int totalRounds,
  ) {
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
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: List.generate(options.length, (index) {
          return _buildOptionTile(
            index,
            options[index],
            correctIndex,
            totalRounds,
            options.length,
          );
        }),
      ),
    );
  }

  Widget _buildOptionTile(
    int index,
    String optionText,
    int correctIndex,
    int totalRounds,
    int totalOptions,
  ) {
    final isSelected = (_selectedIndex == index);
    final isRight = isSelected && (index == correctIndex);
    final isWrong = isSelected && (index != correctIndex);
    final isHidden = _isCorrect && (index != correctIndex);

    double tileWidth = 135.0;
    double tileHeight = 90.0;
    double fontSize = 42.0;

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
        ),
      ];
      // Matching the darker green for text
    } else if (isWrong) {
      tileColor = const Color(0xFFE87C6D).withValues(alpha: 0.15);
      borderColor = const Color(0xFFE87C6D);
      borderWidth = 4.0;
      shadows = [
        BoxShadow(
          color: const Color(0xFFE87C6D).withValues(alpha: 0.3),
          blurRadius: 16,
          spreadRadius: 2,
        ),
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
          margin: const EdgeInsets.all(4.0),
          width: tileWidth,
          height: tileHeight,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: borderWidth),
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
