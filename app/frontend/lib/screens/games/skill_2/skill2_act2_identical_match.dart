import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/telemetry_wrapper.dart';
import '../../../../models/curriculum_models.dart';
import '../shared_templates/widgets/shared_game_layout.dart';
import '../../../../services/progress_service.dart';
import '../shared_widgets/shared_celebration_popup.dart';
import '../../../../services/tts_service.dart';

/// Activity 2: එක සමාන අකුරු (Matching Similar Letters)
class Skill2Act2IdenticalMatch extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill2Act2IdenticalMatch({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill2Act2IdenticalMatch> createState() =>
      _Skill2Act2IdenticalMatchState();
}

class _Skill2Act2IdenticalMatchState extends State<Skill2Act2IdenticalMatch> {
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> _topLetters = [];
  List<String> _bottomLetters = [];
  String? _selectedTopLetter;
  String? _tappedBottomLetter;
  bool _isBottomLetterCorrect = false;
  final Set<String> _matchedLetters = {};

  bool _isProcessing = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;
  String? _currentVariantId;
  Set<String> _removedOptions = {};
  String? _highlightedOption;

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
    _initRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrentInstruction(autoPlay: true);
    });
  }

  void _initRound() {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isNotEmpty && _currentRoundIndex < rounds.length) {
      final currentRound = rounds[_currentRoundIndex];
      
      List<dynamic> lettersList = [];
      if (currentRound is Map && currentRound.containsKey('content')) {
        if (_currentVariantId != null) {
          final variants = currentRound['adaptive_variants'] as List<dynamic>? ?? [];
          final variant = variants.firstWhere((v) => v['variant_id'] == _currentVariantId, orElse: () => null);
          if (variant != null && variant['content'] != null) {
            lettersList = variant['content']['letters'] ?? [];
          } else {
             lettersList = currentRound['content']['letters'] ?? [];
          }
        } else {
           lettersList = currentRound['content']['letters'] ?? [];
        }
      } else if (currentRound is Map) {
         lettersList = currentRound['letters'] ?? [];
      }

      _topLetters = List<String>.from(lettersList);
      _bottomLetters = List<String>.from(_topLetters)..shuffle();
      _selectedTopLetter = null;
      _tappedBottomLetter = null;
      _isBottomLetterCorrect = false;
      _matchedLetters.clear();
      _removedOptions.clear();
      _highlightedOption = null;
      _isProcessing = false;
    }
  }

  void _playCurrentInstruction({bool autoPlay = false}) {
    final promptText =
        widget.activityNode?.description ?? "එක සමාන අකුරු යුගල තෝරන්න.";
    String spokenInstruction = promptText
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
    TtsService().speak(spokenInstruction, folder: 'skill_2');
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudioPrompt() async {
    final promptAudio = widget.activityNode?.audioUrl ?? '';
    if (promptAudio.isNotEmpty) {
      await _audioPlayer.play(AssetSource(promptAudio));
    }
  }

  void _onTopLetterTapped(String letter) {
    if (_isProcessing ||
        _matchedLetters.contains(letter) ||
        _selectedTopLetter != null)
      return;

    setState(() {
      _selectedTopLetter = letter;
    });
  }

  void _transitionToNextRound(Map<String, dynamic>? c4Result) {
    final totalRounds = widget.activityNode?.rounds.length ?? 1;
    
    if (c4Result != null && c4Result.containsKey('next_action')) {
      final nextAction = c4Result['next_action'];
      if (nextAction['decision'] == 'CURRICULUM_COMPLETE' || nextAction['decision'] == 'ACTIVITY_COMPLETE') {
         setState(() {
           _activityComplete = true;
           final sId = widget.activityNode?.skillId ?? '';
           final aId = widget.activityNode?.id ?? '';
           if (sId.isNotEmpty && aId.isNotEmpty) {
             ProgressService().saveActivityScore(sId, aId, 100);
             ProgressService().clearActivityState(sId, aId);
           }
         });
         return;
      }
      final nextItem = nextAction['next_item']?.toString() ?? "";
      final regex = RegExp(r'^S(\d+)A(\d+)R(\d+)(V\d+)?$', caseSensitive: false);
      final match = regex.firstMatch(nextItem);
      
      if (match != null) {
         final pRound = int.tryParse(match.group(3) ?? '');
         final pVariant = match.group(4);
         
         if (pRound != null) {
            _currentRoundIndex = pRound - 1;
            _currentVariantId = pVariant;
         }
      }
    } else {
       if (_currentRoundIndex < totalRounds - 1) {
           _currentRoundIndex++;
           _currentVariantId = null;
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
           return;
       }
    }
    
    if (_currentRoundIndex < totalRounds) {
      setState(() {
        final sId = widget.activityNode?.skillId ?? '';
        final aId = widget.activityNode?.id ?? '';
        if (sId.isNotEmpty && aId.isNotEmpty) {
          int progress = (((_currentRoundIndex) / totalRounds) * 100).toInt();
          ProgressService().saveActivityScore(sId, aId, progress);
          ProgressService().saveActivityState(sId, aId, _currentRoundIndex);
        }
        _initRound();
        _playCurrentInstruction(autoPlay: true);
      });
    }
  }

  Future<void> _handleRoundComplete(int score, {Map<String, dynamic>? forceNextIdx}) async {
    final result = forceNextIdx ?? await context.findAncestorStateOfType<TelemetryWrapperState>()?.completeAdaptiveRound(score);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _transitionToNextRound(result);
    });
  }

  Future<void> _onBottomLetterTapped(String letter) async {
    if (_isProcessing || _selectedTopLetter == null || _matchedLetters.contains(letter)) return;

    setState(() {
      _isProcessing = true;
      _tappedBottomLetter = letter;
    });

    if (letter == _selectedTopLetter) {
      // Match Correct!
      setState(() {
        _isBottomLetterCorrect = true;
      });
      SoundUtils.playFeedback('audio/correct.mp3');

      // Brief delay to show green color before hiding
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _matchedLetters.add(letter);
            _selectedTopLetter = null;
            _tappedBottomLetter = null;
            _isProcessing = false;
          });

          // Check if round is complete
          if (_matchedLetters.length == (_topLetters.length - _removedOptions.length)) {
            _handleRoundComplete(100);
          }
        }
      });
    } else {
      // Match Incorrect
      setState(() {
        _isBottomLetterCorrect = false;
      });
      SoundUtils.playFeedback('audio/wrong.mp3');

      final extraTelemetry = {
         "original_options_count": _bottomLetters.length,
         "current_pair_id": _selectedTopLetter,
         "incorrect_option_ids": _bottomLetters
             .where((l) => l != _selectedTopLetter && !_removedOptions.contains(l))
             .toList()
      };

      final scaffoldResult = await context.findAncestorStateOfType<TelemetryWrapperState>()?.registerAdaptiveWrongAttempt(
         extraTelemetry: extraTelemetry
      );

      if (scaffoldResult != null && scaffoldResult.containsKey('next_action') && scaffoldResult['next_action']['decision'] == 'TERMINATE') {
         _handleRoundComplete(0, forceNextIdx: scaffoldResult);
      } else if (scaffoldResult != null && scaffoldResult.containsKey('next_action')) {
        final action = scaffoldResult['next_action'];
        
        setState(() {
            if (action['remove_option_ids'] != null) {
               List<dynamic> toRemove = action['remove_option_ids'];
               for (var opt in toRemove) {
                   _removedOptions.add(opt.toString());
               }
            }
            
            if (action['highlight_correct'] == true) {
               _highlightedOption = _selectedTopLetter;
            }
        });
      }

      // Briefly show error state, but KEEP the top selection locked!
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _tappedBottomLetter = null;
            _isProcessing = false;
          });
        }
      });
    }
  }

  Widget _buildTopBox() {
    final int letterCount = _topLetters.where((l) => !_removedOptions.contains(l)).length - _matchedLetters.length;
    final double baseTileSize = letterCount <= 2
        ? 120.0
        : (letterCount == 3 ? 95.0 : 75.0);
    final double activeTileSize = letterCount <= 2
        ? 140.0
        : (letterCount == 3 ? 110.0 : 90.0);
    final double inactiveTileSize = letterCount <= 2
        ? 80.0
        : (letterCount == 3 ? 70.0 : 60.0);

    final double baseFontSize = letterCount <= 2
        ? 56.0
        : (letterCount == 3 ? 48.0 : 36.0);
    final double activeFontSize = letterCount <= 2
        ? 64.0
        : (letterCount == 3 ? 56.0 : 44.0);
    final double inactiveFontSize = letterCount <= 2
        ? 40.0
        : (letterCount == 3 ? 32.0 : 26.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF4F7FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: _topLetters
                .where((letter) => !_matchedLetters.contains(letter) && !_removedOptions.contains(letter))
                .map((letter) {
                  final isSelected = _selectedTopLetter == letter;
                  final isOtherSelected =
                      _selectedTopLetter != null && !isSelected;

                  bool isCorrectlyMatched =
                      isSelected &&
                      _tappedBottomLetter != null &&
                      _isBottomLetterCorrect;
                  bool isWronglyMatched =
                      isSelected &&
                      _tappedBottomLetter != null &&
                      !_isBottomLetterCorrect;

                  Color tileColor = isCorrectlyMatched
                      ? const Color(0xFF6DBE6D).withValues(alpha: 0.15)
                      : (isWronglyMatched
                            ? const Color(0xFFE87C6D).withValues(alpha: 0.15)
                            : (isSelected
                                  ? const Color(0xFF4A90E2)
                                  : Colors.white));

                  Color borderColor = isCorrectlyMatched
                      ? const Color(0xFF6DBE6D)
                      : (isWronglyMatched
                            ? const Color(0xFFE87C6D)
                            : (isSelected
                                  ? const Color(0xFF4A90E2)
                                  : const Color(0xFFE2E8F0)));

                  double borderWidth = (isCorrectlyMatched || isWronglyMatched)
                      ? 4.0
                      : (isSelected ? 4.0 : 2.0);

                  return GestureDetector(
                        onTap: () => _onTopLetterTapped(letter),
                        child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      width: isSelected
                          ? activeTileSize
                          : (isOtherSelected ? inactiveTileSize : baseTileSize),
                      height: isSelected
                          ? activeTileSize
                          : (isOtherSelected ? inactiveTileSize : baseTileSize),
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(
                          isSelected ? 24 : 16,
                        ),
                        boxShadow: [
                          if (isCorrectlyMatched)
                            BoxShadow(
                              color: const Color(
                                0xFF6DBE6D,
                              ).withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          else if (isWronglyMatched)
                            BoxShadow(
                              color: const Color(
                                0xFFE87C6D,
                              ).withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          else if (!isOtherSelected)
                            BoxShadow(
                              color:
                                  (isSelected
                                          ? const Color(0xFF4A90E2)
                                          : Colors.black)
                                      .withValues(alpha: 0.12),
                              blurRadius: isSelected ? 16 : 8,
                              offset: Offset(0, isSelected ? 8 : 4),
                            ),
                        ],
                        border: Border.all(
                          color: borderColor,
                          width: borderWidth,
                        ),
                      ),
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isOtherSelected ? 0.3 : 1.0,
                          child: Text(
                            letter,
                            style: AppTypography.sinhala(
                              fontSize: isSelected
                                  ? activeFontSize
                                  : (isOtherSelected
                                        ? inactiveFontSize
                                        : baseFontSize),
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF333333),
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
            })
            .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBox() {
    final bool isActive = _selectedTopLetter != null;
    final int letterCount = _topLetters.where((l) => !_removedOptions.contains(l)).length - _matchedLetters.length;
    final double baseTileSize = letterCount <= 2
        ? 120.0
        : (letterCount == 3 ? 95.0 : 75.0);
    final double baseFontSize = letterCount <= 2
        ? 56.0
        : (letterCount == 3 ? 48.0 : 36.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFFF8FAFC),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Colors.white, Color(0xFFF0F5FA)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isActive
                ? const Color(0xFF4A90E2).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: isActive ? 3 : 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isActive
                      ? const Color(0xFF4A90E2)
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  "සමාන අකුර හොයන්න",
                  style: AppTypography.sinhala(
                    fontSize: 16,
                    color: isActive
                        ? const Color(0xFF4A90E2)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _bottomLetters
                  .where((letter) => !_matchedLetters.contains(letter) && !_removedOptions.contains(letter))
                  .map((letter) {
                    final isTapped = _tappedBottomLetter == letter;

                    Color boxColor = isActive
                        ? Colors.white
                        : const Color(0xFFF1F5F9);
                    Color borderColor = isActive
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0);
                    Color textColor = isActive
                        ? const Color(0xFF4A90E2)
                        : AppColors.textSecondary;

                    double borderWidth = isTapped ? 4.0 : 1.0;
                    List<BoxShadow> glowShadows = [];

                    if (isTapped) {
                      if (_isBottomLetterCorrect) {
                        boxColor = const Color(
                          0xFF6DBE6D,
                        ).withValues(alpha: 0.15);
                        borderColor = const Color(0xFF6DBE6D);
                        textColor = const Color(0xFF6DBE6D);
                        glowShadows = [
                          BoxShadow(
                            color: const Color(
                              0xFF6DBE6D,
                            ).withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ];
                      } else {
                        boxColor = const Color(
                          0xFFE87C6D,
                        ).withValues(alpha: 0.15);
                        borderColor = const Color(0xFFE87C6D);
                        textColor = const Color(0xFFE87C6D);
                        glowShadows = [
                          BoxShadow(
                            color: const Color(
                              0xFFE87C6D,
                            ).withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ];
                      }
                    } else if (isActive) {
                      glowShadows = [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ];
                    }

                    if (_highlightedOption == letter) {
                       boxColor = Colors.yellow.shade100;
                       borderColor = Colors.orange;
                       borderWidth = 4.0;
                    }
                    
                    return GestureDetector(
                          onTap: isActive
                              ? () => _onBottomLetterTapped(letter)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: baseTileSize,
                            height: baseTileSize,
                            decoration: BoxDecoration(
                              color: boxColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: glowShadows,
                              border: Border.all(
                                color: borderColor,
                                width: borderWidth,
                              ),
                            ),
                        child: Center(
                          child: Text(
                            letter,
                            style: AppTypography.sinhala(
                              fontSize: baseFontSize,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            "No rounds found for Activity 2.",
            style: AppTypography.sinhala(),
          ),
        ),
      );
    }

    final promptText =
        widget.activityNode?.description ?? "එක සමාන අකුරු යුගල තෝරන්න.";

    return SharedGameLayout(
      studentData: widget.studentData,
      activityTitle: widget.activityNode?.title ?? '',
      title: widget.activityNode?.title ?? "එක සමාන අකුරු",
      currentRoundIndex: _currentRoundIndex,
      totalRounds: rounds.length,
      isRoundComplete:
          _matchedLetters.length == _topLetters.length &&
          _topLetters.isNotEmpty,
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
            // Standardized Instruction Card
            _buildInstructionCard(promptText),
            const SizedBox(height: 12),
            const SizedBox(height: 12),

            Expanded(
              child: Column(
                children: [
                  // Top Box (Selection)
                  Expanded(child: _buildTopBox()),

                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _selectedTopLetter != null ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "පහළින් සමාන අකුර තෝරන්න",
                        style: AppTypography.sinhala(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4A90E2),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Bottom Box (Matching)
                  Expanded(child: _buildBottomBox()),

                  const SizedBox(height: 12),
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
        context
            .findAncestorStateOfType<TelemetryWrapperState>()
            ?.logAudioReplay();
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
