import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import '../../../widgets/app_loading_indicator.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../models/curriculum_models.dart';
import '../../../../widgets/telemetry_wrapper.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/tts_service.dart';
import '../../../../services/progress_service.dart';

import 'logic/pattern_generator.dart';
import 'models/pattern_round.dart';
import 'widgets/pattern_background.dart';
import 'widgets/pattern_train.dart';
import 'widgets/pattern_carriage.dart';
import 'widgets/pattern_answer_token.dart';
import '../shared_widgets/shared_celebration_popup.dart';

// ──────────────────────────────────────────────────────────────
// Activity 02: Pattern Adventure
// Grade 1 Pattern Completion Game
// ──────────────────────────────────────────────────────────────

class VisualAct4PatternAdventure extends StatefulWidget {
  final ActivityNode activityNode;
  final Map<String, dynamic>? studentData;

  const VisualAct4PatternAdventure({Key? key, required this.activityNode, this.studentData})
      : super(key: key);

  @override
  _VisualAct4PatternAdventureState createState() =>
      _VisualAct4PatternAdventureState();
}

class _VisualAct4PatternAdventureState
    extends State<VisualAct4PatternAdventure> with TickerProviderStateMixin {
  String _lastSpokenInstruction = '';
  // ── Game state ──
  int _currentRoundIndex = 0;
  late List<PatternRound> _rounds;
  bool _roundComplete = false;
  bool _activityComplete = false;
  int _matchedChoiceIndex = -1;
  bool _answerRevealed = false;

  // ── Audio ──
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Colors ──
  static const List<Color> _wagonAccents = [
    Color(0xFF7CB8E8), // Calm blue
    Color(0xFF82C98B), // Gentle green
    Color(0xFFE8A07C), // Warm coral
    Color(0xFFDDA0DD), // Plum
    Color(0xFFF9C623), // Yellow
  ];

  // ── Animation controllers ──
  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;
  
  late AnimationController _roundTransitionController;
  late Animation<double> _roundFadeAnimation;
  
  late AnimationController _flyController;
  late Animation<double> _flyProgress;
  
  late List<AnimationController> _shakeControllers;
  late List<Animation<double>> _shakeAnimations;
  
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late AnimationController _speakerBounceController;
  late Animation<double> _speakerBounceAnimation;

  late ScrollController _trainScrollController;

  // ── Fly animation positions ──
  final GlobalKey _questionSlotKey = GlobalKey();
  late List<GlobalKey> _choiceKeys;
  Rect _flyFromRect = Rect.zero;
  Rect _flyToRect = Rect.zero;

  // ── Mascot ──
  static const List<String> _mascots = [
    'assets/images/characters/human/human_student_1.png',
    'assets/images/characters/mascots/solo_green.png',
    'assets/images/characters/mascots/solo_orange.png',
    'assets/images/characters/mascots/solo_pink.png',
    'assets/images/characters/mascots/solo_yellow.png',
    'assets/images/characters/mascots/solo_teal.png',
  ];
  late String _currentMascot;

  static const List<String> _encourageMessages = [
    'හොඳට බලන්න! 👀',
    'ඔයාට පුළුවන්! 💪',
    'හොඳයි, දිගටම! ⭐',
    'මනාව! 🌟',
    'සුපිරියි! 🎉',
  ];
  late String _currentEncouragement;

  @override
  void initState() {
    super.initState();
    
    // Generate randomized rounds dynamically
    _rounds = PatternGenerator.generateRounds();
    _currentRoundIndex = ProgressService().getActivityState(
      widget.activityNode.skillId,
      widget.activityNode.id,
    );
    if (_currentRoundIndex >= _rounds.length) _currentRoundIndex = 0;

    _trainScrollController = ScrollController();
    _choiceKeys = List.generate(4, (_) => GlobalKey()); // Max 4 choices

    final rng = Random();
    _currentMascot = _mascots[rng.nextInt(_mascots.length)];
    _currentEncouragement =
        _encourageMessages[rng.nextInt(_encourageMessages.length)];

    // Celebration
    _celebrationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _celebrationScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _celebrationController, curve: Curves.elasticOut),
    );

    // Round transition
    _roundTransitionController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _roundFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _roundTransitionController, curve: Curves.easeOut),
    );

    // Fly animation
    _flyController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _flyProgress = CurvedAnimation(
        parent: _flyController, curve: Curves.easeInOut);
    _flyController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _answerRevealed = true);
        
        // Bounce the carriage
        _bounceController.forward(from: 0).then((_) {
          // Sparkle sound removed as per user request to only have one sound
          
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            _nextRound();
          });
        });
      }
    });

    // Shake for wrong answers
    _shakeControllers = List.generate(
        4,
        (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 400)));
    _shakeAnimations = _shakeControllers
        .map((c) => TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
              TweenSequenceItem(tween: Tween(begin: -10, end: 8), weight: 2),
              TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
              TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
            ]).animate(c))
        .toList();

    // Bounce for correct answer insertion
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOut,
    ));

    // Speaker bounce
    _speakerBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _speakerBounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _speakerBounceController, curve: Curves.elasticOut),
    );

    _roundTransitionController.forward().then((_) {
      _scrollToEndOfTrain();
    });

    _initRound();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playInstruction(autoPlay: true);
    });
  }

  void _playInstruction({bool autoPlay = false}) {
    
    if (autoPlay && _lastSpokenInstruction == 'රටාවට ගැළපෙන පින්තූරය තෝරන්න') {
      return;
    }
    _lastSpokenInstruction = 'රටාවට ගැළපෙන පින්තූරය තෝරන්න';
    TtsService().speak('රටාවට ගැළපෙන පින්තූරය තෝරන්න', folder: 'skill_1');
    _speakerBounceController.forward().then((_) {
      _speakerBounceController.reverse();
    });
  }

  void _scrollToEndOfTrain() {
    if (_rounds[_currentRoundIndex].sequence.length <= 4) return;

    if (_trainScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _trainScrollController.hasClients) {
          _trainScrollController.animateTo(
            _trainScrollController.position.maxScrollExtent,
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _roundTransitionController.dispose();
    _flyController.dispose();
    _bounceController.dispose();
    _speakerBounceController.dispose();
    for (var c in _shakeControllers) {
      c.dispose();
    }
    _trainScrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }


  void _initRound() {
    if (_currentRoundIndex >= _rounds.length) return;
    _roundComplete = false;
    _matchedChoiceIndex = -1;
    _answerRevealed = false;
    _flyController.reset();
    setState(() {});
  }

  void _onChoiceTapped(int index) {
    if (_roundComplete) return;
    final currentRound = _rounds[_currentRoundIndex];
    if (index >= currentRound.options.length) return;

    final choicePath = currentRound.options[index];

    if (choicePath == currentRound.correctAnswer) {
      SoundUtils.playFeedback('audio/correct.mp3');
      _capturePositions(index);

      setState(() {
        _matchedChoiceIndex = index;
        _roundComplete = true;
        _currentEncouragement =
            _encourageMessages[Random().nextInt(_encourageMessages.length)];
      });

      _flyController.forward(from: 0);
    } else {
      SoundUtils.playFeedback('audio/wrong.mp3');
      if (index < _shakeControllers.length) {
        _shakeControllers[index].forward(from: 0);
      }
      context
          .findAncestorStateOfType<TelemetryWrapperState>()
          ?.recordMisclick();
    }
  }

  void _capturePositions(int choiceIndex) {
    try {
      final choiceBox = _choiceKeys[choiceIndex].currentContext
          ?.findRenderObject() as RenderBox?;
      final targetBox = _questionSlotKey.currentContext
          ?.findRenderObject() as RenderBox?;
      if (choiceBox != null && targetBox != null) {
        _flyFromRect =
            choiceBox.localToGlobal(Offset.zero) & choiceBox.size;
        _flyToRect =
            targetBox.localToGlobal(Offset.zero) & targetBox.size;
      }
    } catch (_) {}
  }

  void _nextRound() {
    if (!mounted) return;
    context
        .findAncestorStateOfType<TelemetryWrapperState>()
        ?.completeRound(100);

    if (_currentRoundIndex < _rounds.length - 1) {
      _roundTransitionController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentRoundIndex++;
          _initRound();
        });
        ProgressService().saveActivityState(
          widget.activityNode.skillId,
          widget.activityNode.id,
          _currentRoundIndex,
        );
        ProgressService().saveActivityScore(
          widget.activityNode.skillId,
          widget.activityNode.id,
          ((_currentRoundIndex / _rounds.length) * 100).toInt(),
        );
        _roundTransitionController.forward().then((_) {
          _scrollToEndOfTrain();
        });
      });
    } else {
      ProgressService().clearActivityState(
        widget.activityNode.skillId,
        widget.activityNode.id,
      );
      ProgressService().saveActivityScore(
        widget.activityNode.skillId,
        widget.activityNode.id,
        100,
      );
      setState(() => _activityComplete = true);
      _celebrationController.forward();
    }
  }

  void _finishActivity() {
    final wrapper =
        context.findAncestorStateOfType<TelemetryWrapperState>();
    if (wrapper != null) {
      wrapper.completeActivity(context);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rounds.isEmpty) {
      return const Scaffold(
          body: Center(child: AppLoadingIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background layer
          const Positioned.fill(child: PatternBackground(imagePath: 'assets/images/backgrounds/act2_bg.jpg')),

          SafeArea(
            child: FadeTransition(
              opacity: _roundFadeAnimation,
              child: Column(
                children: [
                  _buildTopHUD(),
                  const SizedBox(height: 16),
                  _buildInstructionCard(),
                  const Spacer(flex: 1),

                  // Train section
                  SizedBox(
                    height: 160,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.5, 0), // Slide in from the right
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _roundTransitionController,
                        curve: Curves.easeOutCubic,
                      )),
                      child: _buildTrainSection(),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Answer choices
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildChoiceTokens(),
                  ),

                  const Spacer(flex: 1),
                  

                ],
              ),
            ),
          ),

          // Flying token overlay
          if (_matchedChoiceIndex >= 0 && !_answerRevealed)
            _buildFlyingToken(),

          // Celebration
          if (_activityComplete) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  // ── Top HUD ──
  Widget _buildTopHUD() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF4A90D9), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Text(widget.activityNode.title.isEmpty ? 'Pattern Adventure' : widget.activityNode.title,
                        style: AppTypography.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3E3E3E),
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                _buildProgressDots(),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${_currentRoundIndex + 1}/${_rounds.length}',
                style: AppTypography.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A90D9),
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_rounds.length * 2 - 1, (index) {
        if (index % 2 == 1) {
          final lineIndex = index ~/ 2;
          return Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: lineIndex < _currentRoundIndex
                  ? const Color(0xFF6DBE6D)
                  : const Color(0xFFE0E0E0),
            ),
          );
        } else {
          final dotIndex = index ~/ 2;
          final isCompleted = dotIndex < _currentRoundIndex;
          final isCurrent = dotIndex == _currentRoundIndex;
          return Container(
            width: isCurrent ? 14 : 10,
            height: isCurrent ? 14 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? const Color(0xFF6DBE6D)
                  : isCurrent
                      ? const Color(0xFFF9C623)
                      : const Color(0xFFE0E0E0),
              border: isCurrent
                  ? Border.all(
                      color: const Color(0xFFF9C623).withValues(alpha: 0.3),
                      width: 2)
                  : null,
            ),
          );
        }
      }),
    );
  }

  // ── Instruction Card ──
  Widget _buildInstructionCard() {
    return GestureDetector(
      onTap: () {
        context.findAncestorStateOfType<TelemetryWrapperState>()?.logAudioReplay();
        _playInstruction();
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
              child: Text('රටාවට ගැළපෙන පින්තූරය තෝරන්න', style: AppTypography.sinhala(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            ScaleTransition(
              scale: _speakerBounceAnimation,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.warmAmber, boxShadow: [BoxShadow(color: AppColors.warmAmber.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Train Section ──
  Widget _buildTrainSection() {
    final round = _rounds[_currentRoundIndex];
    
    // Build carriages based on sequence
    List<Widget> carriageWidgets = [];
    for (int i = 0; i < round.sequence.length; i++) {
      final isMissing = (i == round.missingIndex);
      final assetPath = round.sequence[i];
      final accent = _wagonAccents[i % _wagonAccents.length];
      
      carriageWidgets.add(
        PatternCarriage(
          imagePath: isMissing && _answerRevealed ? round.correctAnswer : assetPath,
          accentColor: accent,
          isMissing: isMissing && !_answerRevealed,
          isCorrectRevealed: isMissing && _answerRevealed,
          carriageKey: isMissing ? _questionSlotKey : null,
          bounceAnimation: (isMissing && _answerRevealed) ? _bounceAnimation : null,
        )
      );
    }
    
    return PatternTrain(
      locomotive: _buildLocomotive(),
      carriages: carriageWidgets,
      scrollController: _trainScrollController,
    );
  }

  Widget _buildLocomotive() {
    return Container(
      margin: const EdgeInsets.only(right: 6), // Removed bottom margin so wheels touch track
      child: SizedBox(
        width: 58, // Slightly larger size (58)
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Roof / Smoke stack row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Chimney
                Container(
                  width: 12,
                  height: 18,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF424242),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ),
                // Cab roof
                Container(
                  width: 28,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            // Body
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Cowcatcher
                Container(
                  width: 6,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFF757575),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(6),
                      topLeft: Radius.circular(2),
                    ),
                  ),
                ),
                // Boiler
                Container(
                  width: 24,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1976D2), // Blue boiler
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                    ),
                  ),
                ),
                // Cab
                Container(
                  width: 28,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935), // Red cab
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(6),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3E5FC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Wheels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildWheel(16), // Front wheel
                _buildWheel(16), // Same size cab wheel
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheel(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ── Answer Choices ──
  Widget _buildChoiceTokens() {
    final round = _rounds[_currentRoundIndex];
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: List.generate(round.options.length, (index) {
        return PatternAnswerToken(
          tokenKey: _choiceKeys[index],
          imagePath: round.options[index],
          onTap: () => _onChoiceTapped(index),
          shakeAnimation: _shakeAnimations[index],
          isHidden: (_matchedChoiceIndex == index && !_answerRevealed), // hide the matched token during flight
        );
      }),
    );
  }

  // ── Flying Animation ──
  Widget _buildFlyingToken() {
    return AnimatedBuilder(
      animation: _flyController,
      builder: (context, child) {
        // Curve flight path upward (parabola)
        final double t = _flyProgress.value;
        final double currentX =
            _flyFromRect.left + (_flyToRect.left + 15 - _flyFromRect.left) * t;
        // Y goes up then down to create an arc
        final double curveOffset = sin(t * pi) * -80.0;
        final double currentY =
            _flyFromRect.top + (_flyToRect.top + 15 - _flyFromRect.top) * t + curveOffset;

        // Shrink from token size (90) to carriage content size (~40)
        final double size = 90 - (50 * t);

        return Positioned(
          left: currentX,
          top: currentY,
          width: size,
          height: size,
          child: Opacity(
            opacity: t < 0.9 ? 1.0 : (1.0 - (t - 0.9) * 10), // fade out slightly at the very end
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ]
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/images/activity_icons/${_rounds[_currentRoundIndex].options[_matchedChoiceIndex]}',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Mascot Area ──
  Widget _buildMascotArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.asset(
            _currentMascot,
            width: 50,
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const SizedBox(width: 50, height: 50),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _roundComplete
                    ? 'හොඳයි! 🎉'
                    : _currentEncouragement,
                style: AppTypography.sinhala(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5D7A9E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Celebration Overlay ──
  Widget _buildCelebrationOverlay() {
    return Positioned.fill(
      child: SharedCelebrationPopup(
        studentData: widget.studentData,
        activityTitle: widget.activityNode.title,
        scaleAnimation: _celebrationScale,
        onFinish: _finishActivity,
      ),
    );
  }
}
