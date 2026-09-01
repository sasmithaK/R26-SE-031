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

/// Activity 8: පින්තූරයට ගැලපෙන හිස්තැන පුරවමු (Fill Blank Slot Matching Image)
/// Template: fill_blank_game
class Skill4Act2FillBlank extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill4Act2FillBlank({super.key, this.activityNode, this.isRemedial = false, this.studentData});

  @override
  State<Skill4Act2FillBlank> createState() => _Skill4Act2FillBlankState();
}

class _Skill4Act2FillBlankState extends State<Skill4Act2FillBlank> with TickerProviderStateMixin {
  String _lastSpokenInstruction = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrentInstruction(autoPlay: true);
    });
  }

  void _playCurrentInstruction({bool autoPlay = false}) {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) return;
    
    final instruction = widget.activityNode?.description ?? 'පින්තූර පෙළෙහි හිස්තැනට ගැලපෙන නිවැරදි පින්තූරය තෝරන්න.';
    
    String spokenInstruction = instruction
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
    TtsService().speak(spokenInstruction, folder: 'skill_4');
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _checkAnswer(int index, String selectedOption, String correctOption, int totalRounds) async {
    if (_isCorrect) return;

    setState(() {
      _selectedIndex = index;
    });

    final bool isRight = (selectedOption == correctOption);
    int score = isRight ? 100 : 0;
    context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(score);

    if (isRight) {
      _bounceController.forward(from: 0.0);
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
          _playCurrentInstruction(autoPlay: true);
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
        if (mounted) {
          setState(() {
            _selectedIndex = null;
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
        appBar: AppBar(title: const Text('හිස්තැන පුරවමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }
    
    if (rounds.length > 5) {
      rounds = rounds.sublist(0, 5);
    }

    final currentRound = rounds[_currentRoundIndex];
    final titleText = widget.activityNode?.title ?? 'පින්තූරයට ගැලපෙන හිස්තැන පුරවමු';
    final instructionText = widget.activityNode?.description ?? 'පින්තූර පෙළෙහි හිස්තැනට ගැලපෙන නිවැරදි පින්තූරය තෝරන්න.';

    final sequence = (currentRound['sequence'] as List?)?.map((e) => e?.toString()).toList() ?? ['🔴', '🔵', null, '🟢'];
    var options = (currentRound['options'] as List?)?.map((e) => e.toString()).toList() ?? ['🟡', '🟣', '🔴', '⭐'];
    final correctOption = currentRound['correctOption']?.toString() ?? options.first;
    
    if (widget.isRemedial && options.length > 2) {
      var distractors = options.where((item) => item != correctOption).toList();
      if (distractors.isNotEmpty) distractors = distractors.sublist(0, 1);
      options = [correctOption, ...distractors];
      options.shuffle();
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
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildInstructionCard(instructionText),
                  const SizedBox(height: 16),

                  // ── Premium Sequence Card (now contains Image) ──
                  Expanded(
                    flex: 6,
                    child: _buildSequenceCard(sequence, correctOption, currentRound['image_url']?.toString()),
                  ),

                  const SizedBox(height: 16),

                  // ── Premium Answer Pool ──
                  Expanded(
                    flex: 5,
                    child: _buildAnswerPool(options, correctOption, rounds.length),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Premium floating sequence card with image and animated blank slot
  Widget _buildSequenceCard(List<String?> sequence, String correctOption, String? imageUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.warmAmber.withValues(alpha: 0.4),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmAmber.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (imageUrl != null)
            Flexible(
              child: Container(
                width: 210,
                constraints: const BoxConstraints(maxHeight: 170),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmAmber.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 4,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    alignment: imageUrl.contains('moon_shining') ? Alignment.topCenter : Alignment.center,
                  ),
                ),
              ),
            ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: sequence.map((item) {
                final isBlank = (item == null);
                final currentText = isBlank ? (_isCorrect ? correctOption : '') : item;
                final isWide = false;

                if (isBlank) {
                  return Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _buildBlankSlot(correctOption, isWide));
                } else {
                  return Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _buildFilledSlot(item, isWide));
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Animated pulsing blank slot with glowing border
  Widget _buildBlankSlot(String correctOption, bool isWide) {
    return AnimatedBuilder(
      animation: _isCorrect ? _bounceAnimation : _pulseAnimation,
      builder: (context, child) {
        final scale = _isCorrect ? _bounceAnimation.value : 1.0;
        final glowOpacity = _isCorrect ? 0.0 : _pulseAnimation.value;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 140.0,
            height: 80.0,
            decoration: BoxDecoration(
              color: _isCorrect
                  ? AppColors.gentleGreen.withValues(alpha: 0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isCorrect
                    ? AppColors.gentleGreen
                    : Color.lerp(
                        const Color(0xFF64B5F6),
                        const Color(0xFF2196F3),
                        glowOpacity,
                      )!,
                width: 3,
              ),
              boxShadow: _isCorrect
                  ? [
                      BoxShadow(
                        color: AppColors.gentleGreen.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF64B5F6).withValues(alpha: glowOpacity * 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: _isCorrect
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          correctOption,
                          style: AppTypography.sinhala(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.gentleGreen,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.help_outline_rounded,
                      size: 36,
                      color: Color.lerp(
                        const Color(0xFF90CAF9),
                        const Color(0xFF42A5F5),
                        glowOpacity,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  /// Filled (non-blank) letter slot with premium styling
  Widget _buildFilledSlot(String instruction, bool isWide) {
    return Container(
      width: 140.0,
      height: 80.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90D9).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              instruction,
              style: AppTypography.sinhala(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Premium answer pool with bouncy interactive tiles
  Widget _buildAnswerPool(List<String> options, String correctOption, int totalRounds) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: List.generate(options.length, (index) {
              return _buildOptionTile(index, options[index], correctOption, totalRounds, options.length);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(int index, String optionText, String correctOption, int totalRounds, int totalOptions) {
    final isSelected = (_selectedIndex == index);
    final isRight = isSelected && (optionText == correctOption);
    final isWrong = isSelected && (optionText != correctOption);
    final isHidden = _isCorrect && (optionText == correctOption);

    final isPressed = isRight || isWrong;
    

    double tileWidth = 145.0;
    double tileHeight = 90.0;
    double fontSize = 42.0;

    if (totalOptions > 4) {
      tileWidth = 115.0;
      tileHeight = 65.0;
      fontSize = 28.0;
    } else if (totalOptions == 4) {
      tileWidth = 140.0;
      tileHeight = 75.0;
      fontSize = 36.0;
    } else if (totalOptions == 3) {
      tileWidth = 140.0;
      tileHeight = 75.0;
      fontSize = 36.0;
    }

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
      key: ValueKey('$_currentRoundIndex-$index'),
      onTap: () => _checkAnswer(index, optionText, correctOption, totalRounds),
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
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: shadows,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
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

  Widget _buildInstructionCard(String instruction) {
    return GestureDetector(
      onTap: () {
        _playCurrentInstruction();
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
    );
  }
}
