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
import 'logic/hidden_search_generator.dart';
import 'widgets/pattern_background.dart';
import '../shared_widgets/shared_celebration_popup.dart';

// ──────────────────────────────────────────────────────────────
// Activity 01: Picture Hunt
// A polished, card-grid visual-search game for Grade 1 children
// ──────────────────────────────────────────────────────────────

class VisualAct1HiddenSearch extends StatefulWidget {
  final ActivityNode activityNode;
  final Map<String, dynamic>? studentData;

  const VisualAct1HiddenSearch({Key? key, required this.activityNode, this.studentData})
      : super(key: key);

  @override
  _VisualAct1HiddenSearchState createState() =>
      _VisualAct1HiddenSearchState();
}

class _VisualAct1HiddenSearchState extends State<VisualAct1HiddenSearch>
    with TickerProviderStateMixin {
  String _lastSpokenInstruction = '';
  // ── Game state ──
  int _currentRoundIndex = 0;
  late HiddenSearchGameData _gameData;
  List<_GameItem> _items = [];
  int _foundCount = 0;
  int _targetCount = 0;
  bool _roundComplete = false;
  bool _activityComplete = false;
  bool _showHint = false;
  int _stars = 0;

  // ── Audio ──
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Animation controllers ──
  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;
  late AnimationController _roundTransitionController;
  late Animation<double> _roundFadeAnimation;
  late AnimationController _foundCountBounceController;
  late Animation<double> _foundCountBounce;
  Timer? _hintTimer;

  // ── Speaker & Target Pulse ──
  late AnimationController _speakerBounceController;
  late Animation<double> _speakerBounceAnimation;
  late AnimationController _targetPulseController;
  late Animation<double> _targetPulseAnimation;

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

  @override
  void initState() {
    super.initState();
    _gameData = HiddenSearchGenerator.generateGame();
    _currentRoundIndex = ProgressService().getActivityState(
      widget.activityNode.skillId,
      widget.activityNode.id,
    );
    if (_currentRoundIndex >= _gameData.rounds.length) _currentRoundIndex = 0;

    // Pick a random mascot for this session
    final rng = Random();
    _currentMascot = _mascots[rng.nextInt(_mascots.length)];
    _currentEncouragement = _encourageMessages[rng.nextInt(_encourageMessages.length)];

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _celebrationScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );

    _roundTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _roundFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _roundTransitionController, curve: Curves.easeOut),
    );

    _foundCountBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _foundCountBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _foundCountBounceController,
      curve: Curves.easeInOut,
    ));

    // Speaker bounce animation
    _speakerBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _speakerBounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _speakerBounceController, curve: Curves.elasticOut),
    );

    // Target image pulse animation
    _targetPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _targetPulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _targetPulseController, curve: Curves.easeInOut),
    );

    _initRound();
    _roundTransitionController.forward();

    // Auto-play instruction on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playInstruction(autoPlay: true);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _celebrationController.dispose();
    _roundTransitionController.dispose();
    _foundCountBounceController.dispose();
    _speakerBounceController.dispose();
    _targetPulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }


  // ── Round initialization ──
  void _initRound() {
    if (_currentRoundIndex >= _gameData.rounds.length) return;
    final round = _gameData.rounds[_currentRoundIndex];

    _targetCount = round.targetCount;
    _foundCount = 0;
    _roundComplete = false;
    _showHint = false;
    _items = [];

    // Update encouragement
    final rng = Random();
    _currentEncouragement = _encourageMessages[rng.nextInt(_encourageMessages.length)];

    // Populate _items from generator output
    for (var generatedItem in round.items) {
      _items.add(_GameItem(
        path: 'assets/images/activity_icons/${generatedItem.imagePath}',
        isTarget: generatedItem.isTarget,
        isFlipped: generatedItem.isFlipped,
        colorHue: generatedItem.colorHue,
      ));
    }

    _resetHintTimer();
    setState(() {});
  }

  void _resetHintTimer() {
    _hintTimer?.cancel();
    // Hint feature disabled per user request
  }

  // ── Tap handlers ──
  void _onItemTapped(_GameItem item) {
    if (_roundComplete || item.isFound) return;

    _resetHintTimer();
    setState(() {
      _showHint = false;
    });

    if (item.isTarget) {
      SoundUtils.playFeedback('audio/correct.mp3');
      setState(() {
        item.isFound = true;
        _foundCount++;
        _stars++;
      });
      _foundCountBounceController.forward(from: 0);

      if (_foundCount == _targetCount) {
        _roundComplete = true;
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (!mounted) return;
          _nextRound();
        });
      }
    } else {
      SoundUtils.playFeedback('audio/wrong.mp3');
      setState(() {
        item.showWrongFeedback = true;
      });
      context
          .findAncestorStateOfType<TelemetryWrapperState>()
          ?.recordMisclick();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          item.showWrongFeedback = false;
        });
      });
    }
  }

  void _nextRound() {
    if (!mounted) return;
    context
        .findAncestorStateOfType<TelemetryWrapperState>()
        ?.completeRound(100);

    if (_currentRoundIndex < _gameData.rounds.length - 1) {
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
          ((_currentRoundIndex / _gameData.rounds.length) * 100).toInt(),
        );
        _roundTransitionController.forward();
        _playInstruction(autoPlay: true);
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
    final wrapper =
        context.findAncestorStateOfType<TelemetryWrapperState>();
    if (wrapper != null) {
      wrapper.completeActivity(context);
    } else {
      Navigator.pop(context);
    }
  }

  /// Play the instruction aloud via TTS and trigger speaker bounce
  void _playInstruction({bool autoPlay = false}) {
    if (_gameData.rounds.isEmpty) return;
    final round = _gameData.rounds[_currentRoundIndex];
    
    if (autoPlay && _lastSpokenInstruction == round.instructionText) {
      return;
    }
    _lastSpokenInstruction = round.instructionText;
    TtsService().speak(round.instructionText, folder: 'skill_1');
    _speakerBounceController.forward().then((_) {
      _speakerBounceController.reverse();
    });
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    if (_gameData.rounds.isEmpty) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator()),
      );
    }

    final round = _gameData.rounds[_currentRoundIndex];
    final String title = round.instructionText;
    final String targetPath = 'assets/images/activity_icons/${round.targetPath}';
    final String instruction = round.instructionText;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background Layer ──
          const Positioned.fill(
            child: PatternBackground(imagePath: 'assets/images/backgrounds/act1_bg.jpg'),
          ),

          // ── Main Content ──
          SafeArea(
            child: Column(
              children: [
                  _buildTopHUD(),
                  const SizedBox(height: 8),
                  _buildInstructionCard(instruction, targetPath),
                  const SizedBox(height: 6),
                  _buildFoundCounter(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FadeTransition(
                      opacity: _roundFadeAnimation,
                      child: Center(child: _buildCardGrid()),
                    ),
                  ),

                ],
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
          // Back button
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

          // Center: Title & Progress
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.activityNode.title.isEmpty ? 'Picture Hunt' : widget.activityNode.title,
                          style: AppTypography.heading(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3E3E3E),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildProgressDots(),
              ],
            ),
          ),

          // Right: Round counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_currentRoundIndex + 1}/${_gameData.rounds.length}',
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

  // ── Progress Dots ──
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_gameData.rounds.length * 2 - 1, (index) {
        if (index % 2 == 1) {
          // Line segment
          final lineIndex = index ~/ 2;
          final isCompleted = lineIndex < _currentRoundIndex;
          return Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isCompleted
                  ? const Color(0xFF6DBE6D)
                  : const Color(0xFFE0E0E0),
            ),
          );
        } else {
          // Dot
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
  Widget _buildInstructionCard(String instruction, String targetPath) {
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
            // Target image (prominent, if available)
            if (targetPath.isNotEmpty) ...[
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.warmAmber.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Image.asset(
                  targetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.image_outlined,
                    color: AppColors.warmAmber,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Instruction text
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

            // Speaker button — clearly visible circular amber button
            ScaleTransition(
              scale: _speakerBounceAnimation,
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Found Counter ──
  Widget _buildFoundCounter() {
    return AnimatedBuilder(
      animation: _foundCountBounce,
      builder: (context, child) {
        return Transform.scale(
          scale: _foundCountBounceController.isAnimating
              ? _foundCountBounce.value
              : 1.0,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _foundCount == _targetCount
              ? const Color(0xFF6DBE6D).withValues(alpha: 0.15)
              : const Color(0xFFF9C623).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _foundCount == _targetCount
                ? const Color(0xFF6DBE6D).withValues(alpha: 0.3)
                : const Color(0xFFF9C623).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _foundCount == _targetCount
                  ? Icons.check_circle_rounded
                  : Icons.search_rounded,
              color: _foundCount == _targetCount
                  ? const Color(0xFF6DBE6D)
                  : const Color(0xFFE8A54B),
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$_foundCount / $_targetCount සොයා ගත්තා',
                  style: AppTypography.sinhala(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _foundCount == _targetCount
                        ? const Color(0xFF4E9E4E)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card Grid ──
  Widget _buildCardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = _items.length;
        if (total == 0) return const SizedBox();

        // Target ideal layout (force slightly larger margins if few items)
        double hPadding = total <= 6 ? 22.0 : 12.0;
        double spacing = total <= 6 ? 16.0 : 10.0;

        double maxItemSize = 0.0;
        
        // Find best layout (cols/rows) that maximizes item size while fitting entirely within screen
        for (int cols = 1; cols <= total; cols++) {
          int rows = (total / cols).ceil();
          
          double availableWidth = constraints.maxWidth - (hPadding * 2);
          double availableHeight = constraints.maxHeight - 24; // Some vertical padding

          double widthPerItem = (availableWidth - (cols - 1) * spacing) / cols;
          double heightPerItem = (availableHeight - (rows - 1) * spacing) / rows;
          
          double currentSize = min(widthPerItem, heightPerItem);
          
          // Add a penalty for extremely wide single-row layouts if not necessary
          if (cols > rows + 2) {
             currentSize *= 0.8; 
          }

          if (currentSize > maxItemSize) {
            maxItemSize = currentSize;
          }
        }
        
        // Cap the maximum size so they don't get comically huge on tablets or early rounds
        if (maxItemSize > 160.0) maxItemSize = 160.0;

        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: hPadding),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(_items.length, (index) {
                  return SizedBox(
                    width: maxItemSize,
                    height: maxItemSize,
                    child: _PictureCard(
                      key: ValueKey('${_currentRoundIndex}_${_items[index].path}_$index'),
                      item: _items[index],
                      onTap: () => _onItemTapped(_items[index]),
                      showHint: _showHint && _items[index].isTarget && !_items[index].isFound,
                      animationDelay: index * 0.05,
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      }
    );
  }

  // ── Mascot Area ──
  Widget _buildMascotArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Mascot image
          Image.asset(
            _currentMascot,
            width: 50,
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const SizedBox(width: 50, height: 50),
          ),
          const SizedBox(width: 10),
          // Speech bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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

  Widget _buildStar(double size) {
    return Icon(
      Icons.star_rounded,
      size: size,
      color: const Color(0xFFF9C623),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _GameItem — Data model for each object on the game screen
// ═══════════════════════════════════════════════════════════════
class _GameItem {
  final String path;
  final bool isTarget;
  final bool isFlipped;
  final double? colorHue;
  bool isFound;
  bool showWrongFeedback;

  _GameItem({
    required this.path,
    required this.isTarget,
    this.isFlipped = false,
    this.colorHue,
    this.isFound = false,
    this.showWrongFeedback = false,
  });
}

// ═══════════════════════════════════════════════════════════════
// _PictureCard — A tappable card in the grid with animations
// ═══════════════════════════════════════════════════════════════
class _PictureCard extends StatefulWidget {
  final _GameItem item;
  final VoidCallback onTap;
  final bool showHint;
  final double animationDelay;

  const _PictureCard({
    Key? key,
    required this.item,
    required this.onTap,
    this.showHint = false,
    this.animationDelay = 0,
  }) : super(key: key);

  @override
  _PictureCardState createState() => _PictureCardState();
}

class _PictureCardState extends State<_PictureCard>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _entryScale;
  late Animation<double> _entryOpacity;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late AnimationController _hintController;
  late Animation<double> _hintAnimation;

  late AnimationController _tapController;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();

    // Pop-in entry
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );
    Future.delayed(
      Duration(milliseconds: (widget.animationDelay * 1000).toInt()),
      () {
        if (mounted) _entryController.forward();
      },
    );

    // Shake for wrong
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: -2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
    ]).animate(_shakeController);

    // Hint subtle pulse
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _hintAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );

    // Tap scale
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _tapScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_PictureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.showWrongFeedback && !oldWidget.item.showWrongFeedback) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shakeController.dispose();
    _hintController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _tapController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _tapController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _tapController.reverse();
  }

  List<double> _getHueRotationMatrix(double degrees) {
    double radians = degrees * pi / 180.0;
    double c = cos(radians);
    double s = sin(radians);
    return [
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0,
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
      0,                             0,                             0,                             1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryScale,
        _entryOpacity,
        _shakeAnimation,
        _hintAnimation,
        _tapScale,
      ]),
      builder: (context, child) {
        final entryScale = _entryController.isAnimating || _entryController.isCompleted
            ? _entryScale.value
            : 0.0;
        final shakeOffset =
            _shakeController.isAnimating ? _shakeAnimation.value : 0.0;
        final hintScale = widget.showHint ? _hintAnimation.value : 1.0;
        final tapScale = _tapController.isAnimating || _tapController.isCompleted
            ? _tapScale.value
            : 1.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Opacity(
            opacity: _entryOpacity.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: entryScale * hintScale * tapScale,
              child: child,
            ),
          ),
        );
      },
      child: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    final isFound = widget.item.isFound;
    final isWrong = widget.item.showWrongFeedback;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isFound
              ? const Color(0xFF6DBE6D).withValues(alpha: 0.15)
              : isWrong
                  ? const Color(0xFFE87C6D).withValues(alpha: 0.15)
                  : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFound
                ? const Color(0xFF6DBE6D)
                : isWrong
                    ? const Color(0xFFE87C6D)
                    : const Color(0xFFE5E7EB),
            width: isFound || isWrong ? 4.0 : 1.5,
          ),
          boxShadow: [
            if (isFound)
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
                color: const Color(0xFF4A90D9).withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── The picture ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0, // Always fully visible
                child: Builder(builder: (context) {
                  Widget img = Image.asset(
                    widget.item.path,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFFBBBBBB),
                      size: 40,
                    ),
                  );
                  if (widget.item.colorHue != null) {
                    img = ColorFiltered(
                      colorFilter: ColorFilter.matrix(_getHueRotationMatrix(widget.item.colorHue!)),
                      child: img,
                    );
                  }
                  if (widget.item.isFlipped) {
                    img = Transform.flip(flipX: true, child: img);
                  }
                  return img;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
