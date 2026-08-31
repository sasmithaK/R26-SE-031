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

class Skill2Act3Audio extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  
  const Skill2Act3Audio({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill2Act3Audio> createState() => _Skill2Act3AudioState();
}

class _Skill2Act3AudioState extends State<Skill2Act3Audio> {
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentRoundIndex = 0;
  bool _isRoundComplete = false;
  bool _activityComplete = false;

  late List<String> _options;
  int _correctIndex = 0;
  String _promptText = '';
  String _currentItemId = '';
  
  Set<int> _wrongIndices = {};
  Set<int> _removedIndices = {};
  int? _highlightedIndex;
  String? _currentVariantId;

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
    _setupRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudioPrompt(autoPlay: true);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupRound() {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isNotEmpty && _currentRoundIndex < rounds.length) {
      final currentRound = rounds[_currentRoundIndex];
      _currentItemId = currentRound['item_id']?.toString() ?? 'S2A3R0${_currentRoundIndex + 1}';
      
      Map<String, dynamic> roundData = currentRound;
      
      // If a variant is selected by C4, load its data instead
      if (_currentVariantId != null && currentRound.containsKey('adaptive_variants')) {
        final variants = currentRound['adaptive_variants'] as List<dynamic>? ?? [];
        final variant = variants.firstWhere((v) => v['variant_id'] == _currentVariantId, orElse: () => null);
        if (variant != null && variant.containsKey('content')) {
          roundData = variant['content'] as Map<String, dynamic>;
          _currentItemId = variant['item_id']?.toString() ?? roundData['item_id']?.toString() ?? '';
        }
      }
      
      _promptText = roundData['prompt']?.toString() ?? 'ශබ්දයට සවන්දී අකුර තෝරන්න';
      _options = (roundData['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      
      final correctOption = roundData['correctOption']?.toString() ?? '';
      _correctIndex = _options.indexOf(correctOption);
      if (_correctIndex == -1) _correctIndex = 0;
    } else {
      _options = [];
    }

    _wrongIndices.clear();
    _removedIndices.clear();
    _highlightedIndex = null;
    _isRoundComplete = false;
  }
  
  void _transitionToNextRound(Map<String, dynamic>? c4Result) {
    final rounds = widget.activityNode?.rounds ?? [];
    
    int? nextIdx;
    if (c4Result != null && c4Result.containsKey('next_action')) {
      final nextAction = c4Result['next_action'];
      
      if (nextAction['decision'] == 'CURRICULUM_COMPLETE' || nextAction['decision'] == 'ACTIVITY_COMPLETE') {
        setState(() {
          _activityComplete = true;
        });
        final sId = widget.activityNode?.skillId ?? '';
        final aId = widget.activityNode?.id ?? '';
        if (sId.isNotEmpty && aId.isNotEmpty) {
          ProgressService().saveActivityScore(sId, aId, 100);
          ProgressService().clearActivityState(sId, aId);
        }
        return;
      }

      if (nextAction['next_item'] != null) {
        String nextItem = nextAction['next_item'];
        if (nextItem.contains('V')) {
          _currentVariantId = nextItem.split('V').last;
          _currentVariantId = 'V$_currentVariantId';
        } else {
          _currentVariantId = null;
        }
        
        final match = RegExp(r'R(\d+)').firstMatch(nextItem);
        if (match != null) {
          nextIdx = int.parse(match.group(1)!) - 1;
        }
      }
    }
    
    setState(() {
      _currentRoundIndex = nextIdx ?? (_currentRoundIndex + 1);
      if (_currentRoundIndex >= rounds.length) {
        _activityComplete = true;
      } else {
        _setupRound();
      }
    });
    
    if (!_activityComplete) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _playAudioPrompt(autoPlay: true);
      });
    }
  }

  void _playAudioPrompt({bool autoPlay = false}) {
    String spokenInstruction = _promptText;
    
    if (_promptText.contains("ශබ්දයට සවන් දී අකුර තෝරන්න")) {
      final correctLetter = _options.isNotEmpty && _correctIndex >= 0 && _correctIndex < _options.length 
          ? _options[_correctIndex] 
          : '';
      if (correctLetter.isNotEmpty) {
        spokenInstruction = "ශබ්දයට සවන් දී $correctLetterයන්න තෝරන්න";
      }
    } else {
      spokenInstruction = _promptText
          .replaceAll('මා', 'ම')
          .replaceAllMapped(
            RegExp(r"'?(.)'? අකුර"),
            (match) => '${match.group(1)}, අකුර',
          )
          .replaceAllMapped(
            RegExp(r"'?(.)'? පින්තූරය"),
            (match) => '${match.group(1)}, පින්තූරය',
          )
          .replaceAllMapped(
            RegExp(r"'?(.)'? තෝරන්න"),
            (match) => '${match.group(1)}යන්න තෝරන්න',
          );
    }
    
    if (autoPlay && _lastSpokenInstruction == spokenInstruction) {
      return;
    }
    _lastSpokenInstruction = spokenInstruction;
    TtsService().speak(spokenInstruction, folder: 'skill_2');
  }

  void _checkAnswer(int index) async {
    if (_isRoundComplete || _removedIndices.contains(index)) return;

    final bool isRight = (index == _correctIndex);
    
    if (isRight) {
      setState(() {
        _isRoundComplete = true;
      });
      SoundUtils.playFeedback('audio/correct.mp3');
      
      final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
      if (wrapper != null) {
        final result = await wrapper.completeAdaptiveRound(100, currentRoundIndex: _currentRoundIndex, itemId: _currentItemId);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) _transitionToNextRound(result);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) _transitionToNextRound(null);
        });
      }
    } else {
      SoundUtils.playFeedback('audio/wrong.mp3');
      setState(() {
        _wrongIndices.add(index);
      });
      
      final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
      if (wrapper != null) {
        final result = await wrapper.registerAdaptiveWrongAttempt(
          currentRoundIndex: _currentRoundIndex,
          itemId: _currentItemId,
          extraTelemetry: {"incorrect_option_ids": ['opt_$index']}
        );
        
        if (result != null && result.containsKey('next_action')) {
          final action = result['next_action'];
          setState(() {
            if (action['remove_option_ids'] != null) {
              final removeIds = action['remove_option_ids'] as List;
              for (var id in removeIds) {
                final idx = int.tryParse(id.toString().replaceAll('opt_', ''));
                if (idx != null) _removedIndices.add(idx);
              }
            }
            if (action['highlight_correct'] == true) {
              _highlightedIndex = _correctIndex;
            }
          });
        }
      }
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _wrongIndices.remove(index);
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
        appBar: AppBar(title: const Text('අකුර අසා හඳුනා ගනිමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    final titleText = widget.activityNode?.title ?? 'අකුර අසා හඳුනා ගනිමු';

    double itemSize;
    double spacing;
    double fontSize;
    final total = _options.length;
    final bool hasLongText = _options.any(
      (opt) => opt.length > 4 || opt.contains(' '),
    );

    if (total <= 2) {
      itemSize = 180.0;
      spacing = 32.0;
      fontSize = 84.0;
    } else if (total <= 5) {
      itemSize = 150.0;
      spacing = 24.0;
      fontSize = 72.0;
    } else if (total <= 6) {
      itemSize = 120.0;
      spacing = 16.0;
      fontSize = 56.0;
    } else {
      itemSize = 90.0;
      spacing = 12.0;
      fontSize = 44.0;
    }

    return SharedGameLayout(
      studentData: widget.studentData,
      activityTitle: widget.activityNode?.title ?? '',
      title: titleText,
      currentRoundIndex: _currentRoundIndex,
      totalRounds: rounds.length,
      isRoundComplete: _isRoundComplete,
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
            _buildInstructionCard(_promptText),
            const SizedBox(height: 64),
            Flexible(
              fit: FlexFit.loose,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      alignment: WrapAlignment.center,
                      children: List.generate(_options.length, (index) {
                        if (_removedIndices.contains(index)) {
                           return SizedBox(width: itemSize, height: itemSize);
                        }
                        
                        final isWrong = _wrongIndices.contains(index);
                        final isRight = _isRoundComplete && index == _correctIndex;
                        final isHighlighted = _highlightedIndex == index;

                        return _FloatingLetterCard(
                          key: ValueKey('${_currentItemId}_$index'),
                          index: index,
                          child: GestureDetector(
                            onTap: () => _checkAnswer(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: hasLongText ? null : itemSize,
                              height: hasLongText ? null : itemSize,
                              padding: hasLongText
                                  ? const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    )
                                  : null,
                              decoration: BoxDecoration(
                                color: isRight || isHighlighted
                                    ? const Color(0xFF6DBE6D).withValues(alpha: 0.15)
                                    : isWrong
                                    ? const Color(0xFFE87C6D).withValues(alpha: 0.15)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isRight || isHighlighted
                                      ? const Color(0xFF6DBE6D)
                                      : isWrong
                                      ? const Color(0xFFE87C6D)
                                      : AppColors.borderLight,
                                  width: (isRight || isWrong || isHighlighted) ? 4.0 : 3.0,
                                ),
                                boxShadow: [
                                  if (isRight || isHighlighted)
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
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _options[index],
                                  style: TextStyle(
                                    fontSize: hasLongText ? 24.0 : fontSize,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
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
          ],
        ),
      ),
    );
  }
}

class _FloatingLetterCard extends StatefulWidget {
  final Widget child;
  final int index;
  const _FloatingLetterCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<_FloatingLetterCard> createState() => _FloatingLetterCardState();
}

class _FloatingLetterCardState extends State<_FloatingLetterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500 + (widget.index * 150)),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
