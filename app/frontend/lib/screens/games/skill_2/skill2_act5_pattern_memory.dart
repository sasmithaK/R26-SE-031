import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/telemetry_wrapper.dart';
import '../../../../models/curriculum_models.dart';
import '../shared_templates/widgets/shared_game_layout.dart';
import '../../../../services/progress_service.dart';
import '../shared_widgets/shared_celebration_popup.dart';

/// Activity 3: රටාව මතක තබා ගනිමු (Remember the Pattern)
/// Template: pattern_memory_game
class Skill2Act5PatternMemory extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill2Act5PatternMemory({super.key, this.activityNode, this.isRemedial = false, this.studentData});

  @override
  State<Skill2Act5PatternMemory> createState() => _Skill2Act5PatternMemoryState();
}

class _Skill2Act5PatternMemoryState extends State<Skill2Act5PatternMemory> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMemorizing = true;
  int _countdown = 3;
  Timer? _timer;
  late AnimationController _timerController;

  final List<String> _userSequence = [];
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;
  
  String? _wrongTappedOption;
  String? _correctTappedOption;

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
    _timerController = AnimationController(vsync: this);
    _startMemorizeTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _timerController.dispose();
    super.dispose();
  }

  List<dynamic> get _rounds {
    var r = widget.activityNode?.rounds ?? [];
    return r.length > 5 ? r.sublist(0, 5) : r;
  }

  void _startMemorizeTimer() {
    final rounds = _rounds;
    if (rounds.isEmpty) return;

    final currentRound = rounds[_currentRoundIndex];
    final showSeconds = (currentRound['show_seconds'] as int?) ?? 4;

    setState(() {
      _isMemorizing = true;
      _countdown = showSeconds;
      _userSequence.clear();
      _isCorrect = false;
    });
    
    _timerController.duration = Duration(seconds: showSeconds);
    _timerController.forward(from: 0.0);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isMemorizing = false;
        });
      }
    });
  }

  void _addItemToUserSequence(String item, List<String> targetPattern, int totalRounds) async {
    if (_isCorrect || _isMemorizing || _wrongTappedOption != null) return;

    setState(() {
      _userSequence.add(item);
    });

    // Check if user sequence matches target pattern so far
    final currentIndex = _userSequence.length - 1;
    if (_userSequence[currentIndex] != targetPattern[currentIndex]) {
      // Wrong item picked
      setState(() {
        _wrongTappedOption = item;
      });
      SoundUtils.playFeedback('audio/wrong.mp3');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _wrongTappedOption = null;
            _userSequence.clear();
          });
        }
      });
      return;
    }

    // Correct item picked
    setState(() {
      _correctTappedOption = item;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          if (_correctTappedOption == item) {
            _correctTappedOption = null;
          }
        });
      }
    });

    // Check if pattern completed
    if (_userSequence.length == targetPattern.length) {
      context.findAncestorStateOfType<TelemetryWrapperState>()?.completeRound(100);
      setState(() {
        _isCorrect = true;
      });
      SoundUtils.playFeedback('audio/correct.mp3');

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        if (_currentRoundIndex < totalRounds - 1) {
          _currentRoundIndex++;
              final sId = widget.activityNode?.skillId ?? '';
              final aId = widget.activityNode?.id ?? '';
              if (sId.isNotEmpty && aId.isNotEmpty) {
                int progress = ((_currentRoundIndex / (widget.activityNode?.rounds.length ?? 1)) * 100).toInt();
                ProgressService().saveActivityScore(sId, aId, progress);
                ProgressService().saveActivityState(sId, aId, _currentRoundIndex);
              }
          _startMemorizeTimer();
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
  }

  @override
  Widget build(BuildContext context) {
    final rounds = _rounds;
    if (rounds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('රටාව මතක තබා ගනිමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    final currentRound = rounds[_currentRoundIndex];
    final titleText = widget.activityNode?.title ?? 'රටාව මතක තබා ගනිමු';
    final targetPattern = (currentRound['pattern'] as List?)?.map((e) => e.toString()).toList() ?? ['🔴', '🔵'];
    var options = (currentRound['options'] as List?)?.map((e) => e.toString()).toList() ?? ['🔴', '🔵', '🟢'];

    if (widget.isRemedial && options.length > 2) {
      // Reduce distractors: Keep only items in the target pattern + 1 distractor (if any)
      final requiredItems = targetPattern.toSet();
      final distractors = options.where((o) => !requiredItems.contains(o)).toList();
      options = requiredItems.toList();
      if (distractors.isNotEmpty) {
        options.add(distractors.first);
      }
      options.shuffle();
    }

    double itemSize;
    double spacing;
    double fontSize;
    final total = options.length;
    final bool hasLongText = options.any((opt) => opt.toString().length > 4 || opt.toString().contains(' '));

    if (total <= 2) {
      itemSize = 150.0;
      spacing = 24.0;
      fontSize = 80.0;
    } else if (total <= 4) {
      itemSize = 120.0;
      spacing = 16.0;
      fontSize = 64.0;
    } else if (total <= 6) {
      itemSize = 100.0; 
      spacing = 12.0;
      fontSize = 56.0;
    } else {
      itemSize = 80.0; 
      spacing = 8.0;
      fontSize = 44.0;
    }

    double topSlotSize = 120.0;
    double topFontSize = 72.0;
    double topSlotShrinkSize = 80.0;
    double topFontShrinkSize = 48.0;

    if (targetPattern.length >= 4) {
      topSlotSize = 70.0;
      topFontSize = 40.0;
      topSlotShrinkSize = 60.0;
      topFontShrinkSize = 32.0;
    } else if (targetPattern.length == 3) {
      topSlotSize = 95.0;
      topFontSize = 56.0;
      topSlotShrinkSize = 75.0;
      topFontShrinkSize = 44.0;
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
                  children: [
                    // Instruction Banner
                    _buildInstructionCard(
                      _isMemorizing ? 'රටාව මතක තබා ගන්න!' : 'රටාව නැවත සකසන්න'
                    ),
                    const SizedBox(height: 8),
                    
                    // Timer Bar
                    _buildTimerBar(),
                    const SizedBox(height: 16),

                    // Target Pattern View / Recall Slots (Premium Wooden Board)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5AB), // Light wooden board
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.brown.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                          const BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFD4B872), width: 4),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: List.generate(targetPattern.length, (i) {
                          final itemToShow = _isMemorizing
                              ? targetPattern[i]
                              : (i < _userSequence.length ? _userSequence[i] : '?');
                          final isFilled = _isMemorizing || i < _userSequence.length;
                          final isCurrentWrong = (_wrongTappedOption != null) && (i == _userSequence.length - 1);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isMemorizing ? topSlotSize : topSlotShrinkSize,
                            height: _isMemorizing ? topSlotSize : topSlotShrinkSize,
                            decoration: BoxDecoration(
                              color: isCurrentWrong 
                                  ? const Color(0xFFE87C6D) 
                                  : (isFilled 
                                      ? (_isMemorizing ? Colors.white : const Color(0xFF6DBE6D)) 
                                      : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrentWrong 
                                    ? const Color(0xFFE87C6D) 
                                    : (isFilled 
                                        ? (_isMemorizing ? AppColors.warmAmber.withValues(alpha: 0.4) : const Color(0xFF6DBE6D)) 
                                        : Colors.black.withValues(alpha: 0.1)),
                                width: 2.0,
                              ),
                              boxShadow: (isFilled && isCurrentWrong)
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFE87C6D).withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                itemToShow,
                                style: TextStyle(
                                  fontSize: _isMemorizing ? topFontSize : topFontShrinkSize,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                  color: isCurrentWrong 
                                      ? Colors.white 
                                      : (isFilled 
                                          ? (_isMemorizing ? AppColors.textPrimary : Colors.white) 
                                          : Colors.black26),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Recall Candidate Palette (Disabled while memorizing)
                    if (!_isMemorizing) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                              ),
                              child: Wrap(
                          spacing: 16.0,
                          runSpacing: 16.0,
                          alignment: WrapAlignment.center,
                          children: options.map((opt) {
                            final isWrong = _wrongTappedOption == opt;
                            final isCorrect = _correctTappedOption == opt;
                            final isPressed = isWrong || isCorrect;
                            
                            Color tileColor = Colors.white;
                            Color borderColor = Colors.transparent;
                            Color textColor = AppColors.textPrimary;
                            double borderWidth = isPressed ? 4.0 : 1.0;

                            if (isCorrect) {
                              tileColor = const Color(0xFF6DBE6D).withValues(alpha: 0.15);
                              borderColor = const Color(0xFF6DBE6D);
                              textColor = const Color(0xFF6DBE6D);
                            } else if (isWrong) {
                              tileColor = const Color(0xFFE87C6D).withValues(alpha: 0.15);
                              borderColor = const Color(0xFFE87C6D);
                              textColor = const Color(0xFFE87C6D);
                            }

                            return GestureDetector(
                              onTap: () => _addItemToUserSequence(opt, targetPattern, rounds.length),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: EdgeInsets.all(spacing / 2),
                                width: hasLongText ? null : itemSize,
                                height: hasLongText ? null : itemSize,
                                padding: hasLongText ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16) : null,
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isPressed ? borderColor : const Color(0xFFE2E8F0), 
                                    width: borderWidth
                                  ),
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
                                    else if (!isPressed)
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    opt, 
                                    style: TextStyle(
                                      fontSize: hasLongText ? 40.0 : fontSize, 
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                      color: textColor
                                    ), 
                                    textAlign: TextAlign.center
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                    ],
                    const SizedBox(height: 24),
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
      onTap: () async {
        context.findAncestorStateOfType<TelemetryWrapperState>()?.logAudioReplay();
        if (widget.activityNode?.audioUrl != null && widget.activityNode!.audioUrl.isNotEmpty) {
          await _audioPlayer.play(UrlSource(widget.activityNode!.audioUrl));
        }
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
                style: AppTypography.sinhala(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                  BoxShadow(color: AppColors.warmAmber.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))
                ]
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
            ),
          ],
        ),
      ),
    );
  }
        

  Widget _buildTimerBar() {
    if (!_isMemorizing) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedBuilder(
        animation: _timerController,
        builder: (context, child) {
          final progress = (1.0 - _timerController.value).clamp(0.0, 1.0);
          
          Color barColor = const Color(0xFF6DBE6D);
          if (progress < 0.25) {
            barColor = const Color(0xFFFF4B4B);
          } else if (progress < 0.5) {
            barColor = const Color(0xFFF9C623);
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
                duration: const Duration(milliseconds: 100),
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
}
