import 'dart:async';
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
import 'widgets/pattern_background.dart';
import '../shared_widgets/shared_celebration_popup.dart';

// ──────────────────────────────────────────────────────────────
// Activity 05: Memory Adventure
// A world-class visual memory game for Grade 1 children
// 3D Card Flipping UI with Mascot and Premium Styling
// ──────────────────────────────────────────────────────────────

enum MemoryPhase { preparing, memorizing, hiding, recall, success }

class MemoryRound {
  final int itemCount;
  final int memoryDurationMs;
  final List<String> assets;
  final String targetAsset;

  MemoryRound({
    required this.itemCount,
    required this.memoryDurationMs,
    required this.assets,
    required this.targetAsset,
  });
}

class VisualAct5MemoryHats extends StatefulWidget {
  final ActivityNode activityNode;
  final Map<String, dynamic>? studentData;
  const VisualAct5MemoryHats({Key? key, required this.activityNode, this.studentData}) : super(key: key);

  @override
  _VisualAct5MemoryAdventureState createState() => _VisualAct5MemoryAdventureState();
}

class _VisualAct5MemoryAdventureState extends State<VisualAct5MemoryHats> with TickerProviderStateMixin {
  // ── Game state ──
  int _currentRoundIndex = 0;
  late List<MemoryRound> _rounds;
  bool _activityComplete = false;
  bool _isProcessingTap = false; // Prevents tapping other cards while one is animating

  MemoryPhase _currentPhase = MemoryPhase.preparing;

  // ── Mistakes & Hints ──
  int _mistakesInRound = 0;
  int _lastMistakeIndex = -1;

  // ── Audio ──
  final AudioPlayer _audioPlayer = AudioPlayer();

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

  // ── Encouragement messages ──
  static const List<String> _encourageMessages = [
    'හොඳට බලන්න! 👀',
    'ඔයාට පුළුවන්! 💪',
    'හොඳයි, දිගටම! ⭐',
    'මනාව! 🌟',
    'සුපිරියි! 🎉',
  ];
  late String _currentEncouragement;

  // ── Animation controllers ──
  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;
  late AnimationController _roundTransitionController;
  late Animation<double> _roundFadeAnimation;

  late AnimationController _wrongShakeController;
  late Animation<double> _wrongShakeAnimation;

  // Track memory phase timer
  late AnimationController _timerController;

  // Track card flip controllers
  List<AnimationController> _cardFlipControllers = [];

  // ── Available Assets ──
  static const List<String> _poolAssets = [
    'animals/bird.png', 'animals/butterfly.png', 'animals/cat.png', 'animals/cow.png',
    'animals/dog.png', 'animals/elephant.png', 'animals/fish.png', 'animals/frog.png',
    'animals/rabbit.png', 'animals/turtle.png',
    'fruits_food/apple.png', 'fruits_food/banana.png', 'fruits_food/grapes.png',
    'fruits_food/ice_cream.png', 'fruits_food/mango.png', 'fruits_food/orange.png', 'fruits_food/watermelon.png',
    'flowers/nil_manel.png', 'flowers/nelum.png', 'flowers/flower_05.png',
  ];

  static const List<String> _instructions = [
    'හොඳින් මතක තබා ගන්න!', // Look carefully!
    'පින්තූර තිබෙන තැන් මතක තියාගන්න!', // Remember where the pictures are!
  ];
  late String _currentInstruction;

  // ── Speaker animation ──
  late AnimationController _speakerBounceController;
  late Animation<double> _speakerBounceAnimation;

  @override
  void initState() {
    super.initState();
    _rounds = _generateRounds();
    _currentRoundIndex = ProgressService().getActivityState(
      widget.activityNode.skillId,
      widget.activityNode.id,
    );
    if (_currentRoundIndex >= _rounds.length) _currentRoundIndex = 0;
    
    final rng = Random();
    _currentInstruction = _instructions[rng.nextInt(_instructions.length)];
    _currentMascot = _mascots[rng.nextInt(_mascots.length)];
    _currentEncouragement = _encourageMessages[rng.nextInt(_encourageMessages.length)];

    // Celebration
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _celebrationScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );

    // Round transition fade
    _roundTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _roundFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _roundTransitionController, curve: Curves.easeOut),
    );

    // Wrong answer shake
    _wrongShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wrongShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _wrongShakeController,
      curve: Curves.easeInOut,
    ));

    // Timer bar
    _timerController = AnimationController(
      vsync: this,
    );

    // Speaker bounce
    _speakerBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _speakerBounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _speakerBounceController, curve: Curves.elasticOut),
    );

    _initRoundState();
    _roundTransitionController.forward();
  }

  void _playInstruction(String text) {
    TtsService().speak(text);
    _speakerBounceController.forward().then((_) {
      _speakerBounceController.reverse();
    });
  }

  List<MemoryRound> _generateRounds() {
    // Progressive Difficulty Levels - Tailored for Grade 1
    final config = [
      {'count': 2, 'time': 6000}, // Very easy start
      {'count': 3, 'time': 5000}, // Mild increase
      {'count': 3, 'time': 4000}, // Same items, less time
      {'count': 4, 'time': 4000}, // Introduce 4 items
      {'count': 5, 'time': 4000}, // Max 5 items for this age group
    ];

    List<MemoryRound> rounds = [];
    final rng = Random();

    for (int i = 0; i < config.length; i++) {
      int count = config[i]['count']!;
      int time = config[i]['time']!;

      List<String> pool = List.from(_poolAssets)..shuffle(rng);
      List<String> roundAssets = pool.take(count).toList();
      String target = roundAssets[rng.nextInt(count)];

      rounds.add(MemoryRound(
        itemCount: count,
        memoryDurationMs: time,
        assets: roundAssets,
        targetAsset: target,
      ));
    }
    return rounds;
  }

  void _setupCardControllers() {
    for (var controller in _cardFlipControllers) {
      controller.dispose();
    }
    _cardFlipControllers = List.generate(
      _currentRound.itemCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _initRoundState() {
    _mistakesInRound = 0;
    _lastMistakeIndex = -1;
    _isProcessingTap = false;
    _celebrationController.reset();
    _timerController.reset();
    _setupCardControllers();
    
    setState(() {
      _currentPhase = MemoryPhase.preparing;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMemorySequence();
    });
  }

  void _startMemorySequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    setState(() {
      _currentPhase = MemoryPhase.memorizing;
    });

    _playInstruction(_currentInstruction);

    _timerController.duration = Duration(milliseconds: _currentRound.memoryDurationMs);
    await _timerController.forward(from: 0.0);
    if (!mounted) return;

    setState(() {
      _currentPhase = MemoryPhase.hiding;
    });
    
    // Flip all cards to face down (value -> 1)
    List<Future> flipFutures = [];
    for (int i = 0; i < _cardFlipControllers.length; i++) {
      flipFutures.add(
        Future.delayed(Duration(milliseconds: i * 50), () {
          if (mounted) _cardFlipControllers[i].forward();
        })
      );
    }
    
    await Future.wait(flipFutures);
    if (!mounted) return;

    setState(() {
      _currentPhase = MemoryPhase.recall;
    });

    _playInstruction('මේ පින්තූරය තිබූ තැන තෝරන්න');
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _roundTransitionController.dispose();
    _wrongShakeController.dispose();
    _timerController.dispose();
    _speakerBounceController.dispose();
    for (var controller in _cardFlipControllers) {
      controller.dispose();
    }

    _audioPlayer.dispose();
    super.dispose();
  }


  // ── Game logic ──

  MemoryRound get _currentRound => _rounds[_currentRoundIndex];

  void _onCardTapped(int index) {
    if (_currentPhase != MemoryPhase.recall || _isProcessingTap) return;

    String tappedAsset = _currentRound.assets[index];

    if (tappedAsset == _currentRound.targetAsset) {
      // Correct! Flip card back up (reverse controller)
      _isProcessingTap = true;
      _cardFlipControllers[index].reverse();
      
      SoundUtils.playFeedback('audio/correct.mp3');
      final rng = Random();
      _currentEncouragement = _encourageMessages[rng.nextInt(_encourageMessages.length)];
      
      setState(() {
        _currentPhase = MemoryPhase.success;
      });
      _celebrationController.forward();

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        _nextRound();
      });
    } else {
      // Wrong!
      _isProcessingTap = true;
      SoundUtils.playFeedback('audio/wrong.mp3');
      context.findAncestorStateOfType<TelemetryWrapperState>()?.recordMisclick();
      
      // Briefly flip to show they got it wrong, then flip back
      _cardFlipControllers[index].reverse().then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _currentPhase == MemoryPhase.recall) {
             _cardFlipControllers[index].forward().then((_) {
               if (mounted) setState(() { _isProcessingTap = false; });
             });
          }
        });
      });

      setState(() {
        _lastMistakeIndex = index;
        _mistakesInRound++;
      });
      _wrongShakeController.forward(from: 0).then((_) {
        if (mounted) setState(() { _lastMistakeIndex = -1; });
      });
    }
  }

  void _nextRound() {
    context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(100);

    if (_currentRoundIndex < _rounds.length - 1) {
      _roundTransitionController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentRoundIndex++;
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
        _initRoundState();
        _roundTransitionController.forward();
      });
    } else {
      // Activity complete!
      ProgressService().clearActivityState(
        widget.activityNode.skillId,
        widget.activityNode.id,
      );
      ProgressService().saveActivityScore(
        widget.activityNode.skillId,
        widget.activityNode.id,
        100,
      );
      setState(() {
          _activityComplete = true;
          final sId = widget.activityNode?.skillId ?? '';
          final aId = widget.activityNode?.id ?? '';
          if (sId.isNotEmpty && aId.isNotEmpty) {
            ProgressService().saveActivityScore(sId, aId, 100);
            ProgressService().clearActivityState(sId, aId);
          }
        });
      _celebrationController.forward();
    }
  }

  void _finishActivity() {
    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    if (wrapper != null) {
      wrapper.completeActivity(context);
    } else {
      Navigator.pop(context);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_rounds.isEmpty) {
      return const Scaffold(body: Center(child: AppLoadingIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Beautiful Blurred Background ──
          const Positioned.fill(
            child: PatternBackground(imagePath: 'assets/images/backgrounds/act2_bg.jpg'),
          ),

          // ── Main Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _roundFadeAnimation,
              child: Column(
                children: [
                  _buildTopHUD(),
                  const SizedBox(height: 12),
                  _buildInstructionCard(),
                  const SizedBox(height: 12),
                  _buildTimerBar(),
                  const SizedBox(height: 4),
                  _buildGameArea(),
                  const SizedBox(height: 12),

                ],
              ),
            ),
          ),

          // ── Celebration Overlay ──
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90D9).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF4A90D9), size: 24),
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

                    Flexible(
                      child: Text(
                        widget.activityNode.title.isEmpty ? 'මතක අභියෝගය' : widget.activityNode.title,
                        style: AppTypography.heading(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3E3E3E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildProgressDots(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_currentRoundIndex + 1}/${_rounds.length}',
              style: AppTypography.body(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A90D9),
              ),
            ),
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
          final isCompleted = lineIndex < _currentRoundIndex;
          return Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isCompleted ? const Color(0xFF6DBE6D) : const Color(0xFFE0E0E0),
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
                  ? Border.all(color: const Color(0xFFF9C623).withValues(alpha: 0.3), width: 2)
                  : null,
            ),
          );
        }
      }),
    );
  }

  // ── Instruction Card ──
  Widget _buildInstructionCard() {
    final bool isRecall = _currentPhase == MemoryPhase.recall || _currentPhase == MemoryPhase.success;
    final String text = isRecall ? 'මේ පින්තූරය තිබූ තැන තෝරන්න' : _currentInstruction;
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: 0.0,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: GestureDetector(
        key: ValueKey(isRecall),
        onTap: () {
          context.findAncestorStateOfType<TelemetryWrapperState>()?.logAudioReplay();
          _playInstruction(text);
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
              if (isRecall) ...[
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Image.asset('assets/images/activity_icons/${_currentRound.targetAsset}'),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(text, style: AppTypography.sinhala(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.center),
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
      ),
    );
  }

  // ── Timer Bar ──
  Widget _buildTimerBar() {
    // Only show during preparation or memorization
    if (_currentPhase != MemoryPhase.preparing && _currentPhase != MemoryPhase.memorizing) {
      return const SizedBox(height: 16);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedBuilder(
        animation: _timerController,
        builder: (context, child) {
          final progress = (1.0 - _timerController.value).clamp(0.0, 1.0);
          
          // Smooth color transition based on time remaining
          Color barColor = const Color(0xFF6DBE6D); // Green
          if (progress < 0.25) {
            barColor = const Color(0xFFFF4B4B); // Red
          } else if (progress < 0.5) {
            barColor = const Color(0xFFF9C623); // Yellow
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
                )
              ],
              border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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

  Widget _buildGameArea() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: List.generate(_currentRound.itemCount, (index) {
                      final asset = _currentRound.assets[index];
                      return _buildCardWidget(index, asset);
                    }),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardWidget(int index, String asset) {
    bool isTarget = (asset == _currentRound.targetAsset);
    final flipController = _cardFlipControllers[index];

    // Shake effect for wrong tap
    double shakeX = 0;
    if (_lastMistakeIndex == index && _wrongShakeController.isAnimating) {
      shakeX = _wrongShakeAnimation.value;
    }

    bool isCorrect = _currentPhase == MemoryPhase.success && isTarget;
    bool isWrong = _lastMistakeIndex == index;

    Color borderColor = const Color(0xFF4A90D9).withValues(alpha: 0.3);
    Color bgColor = Colors.white;
    double borderWidth = 2.0;

    if (isCorrect) {
      borderColor = const Color(0xFF6DBE6D);
      bgColor = const Color(0xFF6DBE6D).withValues(alpha: 0.15);
      borderWidth = 4.0;
    } else if (isWrong) {
      borderColor = const Color(0xFFE87C6D);
      bgColor = const Color(0xFFE87C6D).withValues(alpha: 0.15);
      borderWidth = 4.0;
    }

    double screenWidth = MediaQuery.of(context).size.width;
    int itemsPerRow = _currentRound.itemCount <= 4 ? 2 : 3;
    double cardWidth = (screenWidth - 32 - (16 * (itemsPerRow + 1))) / itemsPerRow;
    cardWidth = cardWidth.clamp(80.0, 140.0);
    double cardHeight = cardWidth * 1.2;

    return AnimatedBuilder(
      animation: Listenable.merge([
        flipController,
        _wrongShakeController,
        _celebrationController,
      ]),
      builder: (context, child) {
        final flipValue = flipController.value;
        bool isFaceUp = flipValue < 0.5;

        double scale = 1.0;
        if (_currentPhase == MemoryPhase.success && isTarget) {
          scale = 1.0 + (_celebrationScale.value * 0.2);
        }

        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: () => _onCardTapped(index),
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(flipValue * pi),
                  alignment: Alignment.center,
                  child: isFaceUp
                      ? _buildCardFront(asset, cardWidth, cardHeight, isTarget, borderColor, borderWidth, bgColor, isCorrect, isWrong)
                      : Transform(
                          transform: Matrix4.identity()..rotateY(pi),
                          alignment: Alignment.center,
                          child: _buildCardBack(cardWidth, cardHeight),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardFront(String asset, double width, double height, bool isTarget, Color borderColor, double borderWidth, Color bgColor, bool isCorrect, bool isWrong) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          if (isCorrect)
            BoxShadow(
              color: const Color(0xFF6DBE6D).withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else if (isWrong)
            BoxShadow(
              color: const Color(0xFFE87C6D).withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: const Color(0xFF4A90D9).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset('assets/images/activity_icons/$asset'),
          ),
          if (_currentPhase == MemoryPhase.success && isTarget)
            Opacity(
              opacity: 1.0 - _celebrationScale.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _celebrationScale.value * 0.8, // Scale down slightly as arc is wide
                child: Builder(
                  builder: (context) {
                    final angles = [-0.5, -0.25, 0.0, 0.25, 0.5];
                    final dy = [25.0, 8.0, 0.0, 8.0, 25.0];
                    final sizes = [42.0, 54.0, 68.0, 54.0, 42.0];

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Transform.translate(
                          offset: Offset(0, dy[index] - 15),
                          child: Transform.rotate(
                            angle: angles[index],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Icon(
                                Icons.star_rounded,
                                color: const Color(0xFFFFD700),
                                size: sizes[index],
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                                    blurRadius: 12,
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  }
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardBack(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 3,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Magical fairy dust and bokeh pattern
          CustomPaint(
            size: Size(width, height),
            painter: _CardPatternPainter(),
          ),
          // Premium Glowing Centerpiece
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFDF00), Color(0xFFF9A825)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFDF00).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  // ── Mascot Area ──
  Widget _buildMascotArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Image.asset(
            _currentMascot,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const SizedBox(width: 60, height: 60),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90D9).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Text(
                _activityComplete
                    ? 'හොඳයි! 🎉'
                    : _currentPhase == MemoryPhase.success
                        ? 'සුපිරියි! ✨'
                        : _currentEncouragement,
                style: AppTypography.sinhala(
                  fontSize: 15,
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

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Draw soft, playful circles (bokeh effect)
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.15), 10, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 16, paint);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.75), 18, paint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.85), 8, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.6), 5, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.45), 6, paint);
    
    // Draw magical sparkling stars
    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
      
    _drawSparkle(canvas, Offset(size.width * 0.5, size.height * 0.12), 6, starPaint);
    _drawSparkle(canvas, Offset(size.width * 0.85, size.height * 0.7), 8, starPaint);
    _drawSparkle(canvas, Offset(size.width * 0.18, size.height * 0.85), 5, starPaint);
    _drawSparkle(canvas, Offset(size.width * 0.8, size.height * 0.45), 4, starPaint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
