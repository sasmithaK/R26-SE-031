import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/telemetry_wrapper.dart';
import '../../../models/curriculum_models.dart';
import '../../../services/tts_service.dart';
import '../shared_templates/widgets/shared_game_layout.dart';
import '../../../services/progress_service.dart';
import '../../../adaptive/adapters/sequence_scaffold_adapter.dart';
import '../../../adaptive/models/adaptive_scaffold_models.dart';
import '../../../adaptive/sequence_progression.dart';

class PlacedLetter {
  final String letter;
  final int poolIndex;
  PlacedLetter(this.letter, this.poolIndex);
}

class Skill3Act5JumbledWord extends StatefulWidget {
  final ActivityNode? activityNode;
  final bool isRemedial;
  final Map<String, dynamic>? studentData;
  const Skill3Act5JumbledWord({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill3Act5JumbledWord> createState() => _Skill3Act5JumbledWordState();
}

class _Skill3Act5JumbledWordState extends State<Skill3Act5JumbledWord>
    with SingleTickerProviderStateMixin, SequenceScaffoldAdapter {
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCorrect = false;
  bool _activityComplete = false;
  Map<String, dynamic>? _completedRoundSnapshot;
  int _currentRoundIndex = 0;

  List<PlacedLetter?> _filledSlots = [];
  List<String?> _poolLetters = [];
  List<int> _correctPoolOrder = const <int>[];
  final Set<int> _lockedSlotIndices = <int>{};
  bool _isChecking = false;
  bool _showError = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  Future<void> handleAdaptiveSequenceSemanticScaffold(
    ScaffoldCommand command,
  ) async {
    if (command.type == ScaffoldActionType.replayInstruction) {
      _playCurrentInstruction();
    }
  }

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
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 24,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

    _initRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrentInstruction(autoPlay: true);
    });
  }

  void _playCurrentInstruction({bool autoPlay = false}) {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) return;
    final currentRound = adaptiveSequenceRoundData(
      activity: widget.activityNode,
      roundIndex: _currentRoundIndex,
    );
    final instructionText =
        currentRound['prompt']?.toString() ?? 'පින්තූරයට අදාළ වචනය සාදන්න';
    String spokenInstruction = instructionText
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
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _initRound() {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) return;

    final currentRound = adaptiveSequenceRoundData(
      activity: widget.activityNode,
      roundIndex: _currentRoundIndex,
    );
    final scrambledList =
        (currentRound['scrambled_letters'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final correctWord = currentRound['correct_word']?.toString() ?? '';
    _correctPoolOrder = resolveSequencePoolOrder(
      poolTokens: scrambledList,
      target: correctWord,
    );
    final correctSequence = _correctPoolOrder
        .map((poolIndex) => scrambledList[poolIndex])
        .toList();
    configureAdaptiveSequence(
      activity: widget.activityNode,
      roundIndex: _currentRoundIndex,
      poolTokens: scrambledList,
      correctSequence: correctSequence,
    );

    setState(() {
      _completedRoundSnapshot = null;
      _poolLetters = List.from(scrambledList);
      _filledSlots = List.filled(scrambledList.length, null);
      _lockedSlotIndices.clear();
      _isCorrect = false;
      _isChecking = false;
      _showError = false;
    });
  }

  void _onPoolLetterTapped(int poolIndex) async {
    if (_isChecking || _poolLetters[poolIndex] == null) return;
    context.findAncestorStateOfType<TelemetryWrapperState>()?.markAnswer();

    // Find first empty slot
    int emptySlotIndex = _filledSlots.indexWhere((s) => s == null);
    if (emptySlotIndex != -1) {
      final letter = _poolLetters[poolIndex]!;
      setState(() {
        _filledSlots[emptySlotIndex] = PlacedLetter(letter, poolIndex);
        _poolLetters[poolIndex] = null;
        adaptiveHintedTokenIndices.remove(poolIndex);
        _showError = false;
      });

      // Do not speak the letter to prevent overlapping with success audio

      // Check if all slots are filled
      if (!_filledSlots.contains(null)) {
        _validateAnswer();
      }
    }
  }

  void _onSlotTapped(int slotIndex) {
    if (_isChecking ||
        _filledSlots[slotIndex] == null ||
        _lockedSlotIndices.contains(slotIndex)) {
      return;
    }

    // Moving an already placed unit back to the pool is a correction
    context.findAncestorStateOfType<TelemetryWrapperState>()?.logCorrection();

    setState(() {
      final placed = _filledSlots[slotIndex]!;
      _poolLetters[placed.poolIndex] = placed.letter;
      _filledSlots[slotIndex] = null;
      _showError = false;
    });
  }

  void _validateAnswer() async {
    setState(() {
      _isChecking = true;
    });

    final currentRound = adaptiveSequenceRoundData(
      activity: widget.activityNode,
      roundIndex: _currentRoundIndex,
    );
    final correctWord = currentRound['correct_word']?.toString() ?? "";

    final formedWord = _filledSlots.map((e) => e!.letter).join("");

    if (formedWord == correctWord) {
      // Correct
      setState(() {
        _completedRoundSnapshot = Map<String, dynamic>.from(currentRound);
        _isCorrect = true;
      });
      final transition = await completeAdaptiveSequenceTask(
        100,
        roundIndex: _currentRoundIndex,
        selectedAnswers: _filledSlots.map((e) => e!.letter).toList(),
      );
      SoundUtils.playFeedback('audio/correct.mp3');

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        if (transition != null && !transition.isComplete) {
          _currentRoundIndex = transition.roundIndex;
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
          _initRound();
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
      // Incorrect
      final selectedPoolIndices = _filledSlots
          .map((entry) => entry!.poolIndex)
          .toList();
      final progressiveScaffold = _filledSlots.length >= 3;
      final correctTokens = _correctPoolOrder
          .map(
            (poolIndex) => _poolLetters.length > poolIndex
                ? (currentRound['scrambled_letters'] as List)[poolIndex]
                      .toString()
                : '',
          )
          .toList();
      final correctPrefixLength = progressiveScaffold
          ? matchingSequencePrefixLength(
              placedTokens: _filledSlots.map((entry) => entry?.letter).toList(),
              correctTokens: correctTokens,
            )
          : 0;
      unawaited(
        requestSequenceScaffold(
          selectedPoolIndices: selectedPoolIndices,
          correctPosition: correctPrefixLength,
        ),
      );
      SoundUtils.playFeedback('audio/wrong.mp3');

      setState(() {
        _showError = true;
      });

      _shakeController.forward().then((_) {
        _shakeController.reverse();
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        // For three-unit and longer tasks, preserve only the consecutive
        // correct prefix. Return the remaining tokens to the pool so the next
        // required token can be highlighted without rebuilding the layout.
        setState(() {
          for (int i = 0; i < _filledSlots.length; i++) {
            if (progressiveScaffold && i < correctPrefixLength) {
              _lockedSlotIndices.add(i);
            } else if (_filledSlots[i] != null) {
              _poolLetters[_filledSlots[i]!.poolIndex] =
                  _filledSlots[i]!.letter;
              _filledSlots[i] = null;
              _lockedSlotIndices.remove(i);
            }
          }
          _showError = false;
          _isChecking = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('අකුරු පිළිවෙලට සකසමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    if (rounds.length > 5) {
      rounds = rounds.sublist(0, 5);
    }

    final currentRound =
        _completedRoundSnapshot ??
        adaptiveSequenceRoundData(
          activity: widget.activityNode,
          roundIndex: _currentRoundIndex,
        );
    final titleText = widget.activityNode?.title ?? 'අකුරු පිළිවෙලට සකසමු';
    final promptText =
        currentRound['prompt']?.toString() ?? 'පින්තූරයට අදාළ වචනය සාදන්න';
    final emoji = currentRound['emoji']?.toString();
    final imageUrl = currentRound['image_url']?.toString();

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
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildInstructionCard(promptText),
                  const Spacer(flex: 1),

                  // Flashcard Container with Image & Answer Slots
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowMedium,
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top: Image
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.warmAmber.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 16,
                                spreadRadius: 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: imageUrl != null
                                ? Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Image.asset(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Text(
                                    emoji ?? '🧩',
                                    style: const TextStyle(fontSize: 60),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Bottom: Answer Slots
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                sin(_shakeAnimation.value * pi) * 10,
                                0,
                              ),
                              child: child,
                            );
                          },
                          child: Wrap(
                            key: ValueKey('slots_$adaptiveSequenceItemId'),
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: List.generate(_filledSlots.length, (
                              index,
                            ) {
                              final slot = _filledSlots[index];
                              final isFilled = slot != null;
                              final isLocked = _lockedSlotIndices.contains(
                                index,
                              );
                              return GestureDetector(
                                onTap: isLocked
                                    ? null
                                    : () => _onSlotTapped(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: _isCorrect
                                        ? AppColors.gentleGreen.withValues(
                                            alpha: 0.2,
                                          )
                                        : isLocked
                                        ? AppColors.gentleGreen.withValues(
                                            alpha: 0.18,
                                          )
                                        : _showError
                                        ? AppColors.softCoral.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _isCorrect
                                          ? AppColors.gentleGreen
                                          : isLocked
                                          ? AppColors.gentleGreen
                                          : _showError
                                          ? AppColors.softCoral
                                          : isFilled
                                          ? AppColors.calmBlue
                                          : const Color(0xFF64B5F6),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: isFilled
                                        ? Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                slot.letter,
                                                style: AppTypography.sinhala(
                                                  fontSize: 40,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              if (isLocked)
                                                const Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 18,
                                                    color:
                                                        AppColors.gentleGreen,
                                                  ),
                                                ),
                                            ],
                                          )
                                        : const Icon(
                                            Icons.help_outline_rounded,
                                            size: 32,
                                            color: Color(0xFF90CAF9),
                                          ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Scrambled Letter Pool (Bigger)
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                          top: 36,
                          bottom: 20,
                          left: 16,
                          right: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Builder(
                          builder: (context) {
                            final availableLetters = _poolLetters
                                .asMap()
                                .entries
                                .where((entry) => entry.value != null)
                                .toList();
                            return Wrap(
                              key: ValueKey('pool_$adaptiveSequenceItemId'),
                              spacing: 24,
                              runSpacing: 24,
                              alignment: WrapAlignment.center,
                              children: availableLetters.map((entry) {
                                final index = entry.key;
                                final letter = entry.value!;
                                final isHinted = isAdaptiveTokenHinted(index);
                                return GestureDetector(
                                  key: ValueKey(adaptiveTokenId(index)),
                                  onTap: () => _onPoolLetterTapped(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                    width: 90,
                                    height: 90,
                                    margin: const EdgeInsets.all(4.0),
                                    decoration: BoxDecoration(
                                      color: isHinted
                                          ? AppColors.warmAmberLight
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isHinted
                                            ? AppColors.warmAmber
                                            : const Color(0xFFE5E7EB),
                                        width: isHinted ? 4 : 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF4A90D9,
                                          ).withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            letter,
                                            maxLines: 1,
                                            style: AppTypography.sinhala(
                                              fontSize: 46,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
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
      onTap: () {
        context
            .findAncestorStateOfType<TelemetryWrapperState>()
            ?.logAudioReplay();
        TtsService().speak(instruction, folder: 'skill_3');
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
