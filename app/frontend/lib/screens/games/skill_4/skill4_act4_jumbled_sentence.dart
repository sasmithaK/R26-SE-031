import 'dart:math';
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

class PlacedWord {
  final String word;
  final int poolIndex;
  PlacedWord(this.word, this.poolIndex);
}

class Skill4Act4JumbledSentence extends StatefulWidget {
  final ActivityNode? activityNode;
  final bool isRemedial;
  final Map<String, dynamic>? studentData;
  const Skill4Act4JumbledSentence({super.key, this.activityNode, this.isRemedial = false, this.studentData});

  @override
  State<Skill4Act4JumbledSentence> createState() => _Skill4Act4JumbledSentenceState();
}

class _Skill4Act4JumbledSentenceState extends State<Skill4Act4JumbledSentence> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;

  List<PlacedWord?> _filledSlots = [];
  List<String?> _poolWords = [];
  bool _isChecking = false;
  bool _showError = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _initRound();
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

    final currentRound = rounds[_currentRoundIndex];
    final scrambledList = (currentRound['scrambled_words'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    setState(() {
      _poolWords = List.from(scrambledList);
      _filledSlots = List.filled(scrambledList.length, null);
      _isCorrect = false;
      _isChecking = false;
      _showError = false;
    });
  }

  void _onPoolWordTapped(int poolIndex) async {
    if (_isChecking || _poolWords[poolIndex] == null) return;

    // Find first empty slot
    int emptySlotIndex = _filledSlots.indexWhere((s) => s == null);
    if (emptySlotIndex != -1) {
      final word = _poolWords[poolIndex]!;
      setState(() {
        _filledSlots[emptySlotIndex] = PlacedWord(word, poolIndex);
        _poolWords[poolIndex] = null;
        _showError = false;
      });
      
      // Speak the word
      TtsService().speak(word);
      
      // Check if all slots are filled
      if (!_filledSlots.contains(null)) {
        _validateAnswer();
      }
    }
  }

  void _onSlotTapped(int slotIndex) {
    if (_isChecking || _filledSlots[slotIndex] == null) return;

    setState(() {
      final placed = _filledSlots[slotIndex]!;
      _poolWords[placed.poolIndex] = placed.word;
      _filledSlots[slotIndex] = null;
      _showError = false;
    });
  }

  void _validateAnswer() async {
    setState(() {
      _isChecking = true;
    });

    final rounds = widget.activityNode?.rounds ?? [];
    final currentRound = rounds[_currentRoundIndex];
    final correctSentence = currentRound['correct_sentence']?.toString() ?? "";
    
    // Join words with a space and append full stop
    final formedSentence = _filledSlots.map((e) => e!.word).join(" ") + ".";

    // Check if it matches exactly, or ignoring leading/trailing whitespace
    if (formedSentence.trim() == correctSentence.trim()) {
      // Correct
      setState(() {
        _isCorrect = true;
      });
      context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(100);
      SoundUtils.playFeedback('audio/correct.mp3');

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        if (_currentRoundIndex < rounds.length - 1) {
          _currentRoundIndex++;
              final sId = widget.activityNode?.skillId ?? '';
              final aId = widget.activityNode?.id ?? '';
              if (sId.isNotEmpty && aId.isNotEmpty) {
                int progress = ((_currentRoundIndex / (widget.activityNode?.rounds.length ?? 1)) * 100).toInt();
                ProgressService().saveActivityScore(sId, aId, progress);
                ProgressService().saveActivityState(sId, aId, _currentRoundIndex);
              }
          _initRound();
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
      context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(0);
      SoundUtils.playFeedback('audio/wrong.mp3');
      
      setState(() {
        _showError = true;
      });
      
      _shakeController.forward().then((_) {
        _shakeController.reverse();
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        // Return all words to pool
        setState(() {
          for (int i = 0; i < _filledSlots.length; i++) {
            if (_filledSlots[i] != null) {
              _poolWords[_filledSlots[i]!.poolIndex] = _filledSlots[i]!.word;
              _filledSlots[i] = null;
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
        appBar: AppBar(title: const Text('වාක්‍යය සකසමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }
    
    if (rounds.length > 5) {
      rounds = rounds.sublist(0, 5);
    }

    final currentRound = rounds[_currentRoundIndex];
    final titleText = widget.activityNode?.title ?? 'වාක්‍යය සකසමු';
    final promptText = currentRound['prompt']?.toString() ?? 'පින්තූරයට අදාළ වාක්‍යය සාදන්න';
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
                  _buildInstructionCard(promptText),
                  const Spacer(flex: 1),

                  // Flashcard Container with Image & Answer Slots
                  Expanded(
                    flex: 8,
                    child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      border: Border.all(color: AppColors.borderLight, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top: Image
                        Container(
                          width: 210,
                          constraints: const BoxConstraints(maxHeight: 170),
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
                            child: imageUrl != null
                                ? Image.asset(imageUrl, fit: BoxFit.cover)
                                : Center(child: Text(emoji ?? '🧩', style: const TextStyle(fontSize: 60))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Bottom: Answer Slots (Sentence)
                        Flexible(
                          child: AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(sin(_shakeAnimation.value * pi) * 10, 0),
                                child: child,
                              );
                            },
                            child: _isCorrect
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.gentleGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.gentleGreen, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    _filledSlots.map((s) => s!.word).join(" ") + ".",
                                    style: AppTypography.sinhala(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_filledSlots.length, (index) {
                                    final slot = _filledSlots[index];
                                    final isFilled = slot != null;
                                    return GestureDetector(
                                      onTap: () => _onSlotTapped(index),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        constraints: const BoxConstraints(minWidth: 120, minHeight: 60),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        margin: EdgeInsets.only(right: index == _filledSlots.length - 1 ? 0 : 12),
                                        decoration: BoxDecoration(
                                          color: _showError
                                              ? AppColors.softCoral.withValues(alpha: 0.2)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _showError
                                                ? AppColors.softCoral
                                                : isFilled ? AppColors.calmBlue : const Color(0xFF64B5F6),
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                        ),
                                        child: Center(
                                          child: isFilled 
                                            ? Text(
                                                slot.word,
                                                style: AppTypography.sinhala(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.help_outline_rounded,
                                                size: 28,
                                                color: Color(0xFF90CAF9),
                                              ),
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
                  ),

                  const Spacer(flex: 2),

                  // Scrambled Word Pool
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 24, bottom: 20, left: 16, right: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Builder(
                          builder: (context) {
                            final availableWords = _poolWords.asMap().entries.where((e) => e.value != null).toList();
                            final isSmall = availableWords.length > 2;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < availableWords.length; i += 2)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: availableWords.sublist(i, (i + 2 < availableWords.length) ? i + 2 : availableWords.length).map((entry) {
                                        int index = entry.key;
                                        final word = entry.value;
                                        return GestureDetector(
                                          onTap: () => _onPoolWordTapped(index),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                            padding: isSmall
                                                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                                                : const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(
                                                color: const Color(0xFFE5E7EB),
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF4A90D9).withValues(alpha: 0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              word ?? '',
                                              style: AppTypography.sinhala(
                                                fontSize: isSmall ? 24 : 32,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
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
        context.findAncestorStateOfType<TelemetryWrapperState>()?.logAudioReplay();
        TtsService().speak(instruction);
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
