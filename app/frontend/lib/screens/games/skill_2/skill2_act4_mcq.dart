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

/// Activity 4: වචනයට සවන් දී පින්තූරය සොයමු (Listen to Word & Find Image)
/// Template: audio_image_match_game
class Skill2Act4Mcq extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;
  const Skill2Act4Mcq({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill2Act4Mcq> createState() => _Skill2Act4McqState();
}

class _Skill2Act4McqState extends State<Skill2Act4Mcq> {
  String _lastSpokenInstruction = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<int> _selectedIndices = {};
  final Set<int> _hiddenIndices = {};
  final Set<int> _highlightIndices = {};
  
  bool _isCorrect = false;
  bool _activityComplete = false;
  int _currentRoundIndex = 0;
  String _currentItemId = '';
  String? _currentVariantId;

  String _promptText = '';
  String _displayWord = '';
  List<String> _options = [];
  List<int> _correctIndices = [];

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
    
    _setupRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudioPrompt(autoPlay: true);
    });
  }

  void _setupRound() {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isNotEmpty && _currentRoundIndex < rounds.length) {
      final currentRound = rounds[_currentRoundIndex];
      _currentItemId = currentRound['item_id']?.toString() ?? 'S2A4R0${_currentRoundIndex + 1}';
      
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
      
      _promptText = roundData['prompt']?.toString() ?? 'අසා සිටින පින්තූරය තෝරන්න';
      _options = (roundData['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      
      if (roundData['correct_indices'] != null) {
        _correctIndices = List<int>.from(roundData['correct_indices']);
      } else if (roundData['correct_index'] != null) {
        _correctIndices = [roundData['correct_index'] as int];
      } else {
        _correctIndices = [0];
      }
      
      final RegExp quoteRegex = RegExp(r"'(.*?)'");
      final match = quoteRegex.firstMatch(_promptText);
      _displayWord = roundData['target_word']?.toString() ?? (match != null ? match.group(1) ?? '' : '');
      
    } else {
      _options = [];
    }

    _selectedIndices.clear();
    _hiddenIndices.clear();
    _highlightIndices.clear();
    _isCorrect = false;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudioPrompt({bool autoPlay = false}) {
    String spokenInstruction = _promptText
        .replaceAll('මා', 'ම')
        .replaceAllMapped(RegExp(r" '?(.)'? අකුර"), (match) => ' ${match.group(1)}, අකුර')
        .replaceAllMapped(RegExp(r" '?(.)'? පින්තූරය"), (match) => ' ${match.group(1)}, පින්තූරය')
        .replaceAllMapped(RegExp(r" '?(.)'? තෝරන්න"), (match) => ' ${match.group(1)}යන්න තෝරන්න');
    
    if (autoPlay && _lastSpokenInstruction == spokenInstruction) {
      return;
    }
    _lastSpokenInstruction = spokenInstruction;
    TtsService().speak(spokenInstruction, folder: 'skill_2');
  }

  void _transitionToNextRound(Map<String, dynamic>? nextAction) {
    if (nextAction != null && nextAction['decision'] == 'ACTIVITY_COMPLETE') {
      _completeActivity();
      return;
    }
    
    int totalRounds = widget.activityNode?.rounds.length ?? 1;
    setState(() {
      if (nextAction != null && nextAction.containsKey('next_item')) {
         final nextItem = nextAction['next_item'].toString();
         
         // Extract round number from strings like S2A4R01 or S2A4R01V1
         final regex = RegExp(r'R(\d+)');
         final match = regex.firstMatch(nextItem);
         if (match != null && match.group(1) != null) {
            int roundNum = int.tryParse(match.group(1)!) ?? (_currentRoundIndex + 1);
            _currentRoundIndex = roundNum - 1; // 0-indexed
         } else {
            _currentRoundIndex++;
         }

         if (nextItem.contains('V1')) _currentVariantId = 'V1';
         else if (nextItem.contains('V2')) _currentVariantId = 'V2';
         else _currentVariantId = null;
         
      } else {
         _currentVariantId = null;
         _currentRoundIndex++;
      }
      
      final sId = widget.activityNode?.skillId ?? '';
      final aId = widget.activityNode?.id ?? '';
      if (sId.isNotEmpty && aId.isNotEmpty) {
        int progress = ((_currentRoundIndex / totalRounds) * 100).toInt();
        ProgressService().saveActivityScore(sId, aId, progress);
        ProgressService().saveActivityState(sId, aId, _currentRoundIndex);
      }
      _setupRound();
    });
    
    if (_currentRoundIndex < totalRounds || _currentVariantId != null) {
      _playAudioPrompt(autoPlay: true);
    } else {
      _completeActivity();
    }
  }

  void _completeActivity() {
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
  
  void _processScaffoldAction(Map<String, dynamic> nextAction) {
    setState(() {
      _highlightIndices.clear();
      
      if (nextAction['remove_option_ids'] != null) {
        final List<dynamic> removeIds = nextAction['remove_option_ids'];
        for (var id in removeIds) {
          final idx = _options.indexOf(id.toString());
          if (idx != -1 && !_correctIndices.contains(idx)) {
            _hiddenIndices.add(idx);
          }
        }
      }
      
      if (nextAction['highlight_correct'] == true) {
        for (var idx in _correctIndices) {
           if (!_selectedIndices.contains(idx)) {
               _highlightIndices.add(idx);
           }
        }
      }
    });
  }

  void _checkAnswer(int index) async {
    if (_isCorrect || _hiddenIndices.contains(index)) return;

    final bool wasSelected = _selectedIndices.contains(index);
    setState(() {
      if (wasSelected) {
        _selectedIndices.remove(index);
        _highlightIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });

    final bool isThisTapCorrect = _correctIndices.contains(index);

    if (wasSelected) {
       // Just deselecting, no backend call
       return;
    }

    if (!isThisTapCorrect) {
      // Incorrect tap -> Send ATTEMPT to C4
      SoundUtils.playFeedback('audio/wrong.mp3');
      
      final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
      if (wrapper != null) {
        List<String> visibleOpts = [];
        List<String> incorrectHistory = [];
        List<String> selectedOpts = [];
        List<String> remainingCorrectOpts = [];
        
        for (int i = 0; i < _options.length; i++) {
            if (!_hiddenIndices.contains(i)) visibleOpts.add(_options[i]);
            if (_selectedIndices.contains(i)) {
               selectedOpts.add(_options[i]);
               if (!_correctIndices.contains(i)) {
                   incorrectHistory.add(_options[i]);
               }
            }
            if (_correctIndices.contains(i) && !_selectedIndices.contains(i)) {
                remainingCorrectOpts.add(_options[i]);
            }
        }
        
        final result = await wrapper.registerAdaptiveWrongAttempt(
            itemId: _currentItemId,
            extraTelemetry: {
                "visible_option_ids": visibleOpts,
                "incorrect_option_ids": incorrectHistory,
                "selected_option_ids": selectedOpts,
                "remaining_correct_option_ids": remainingCorrectOpts,
                "required_target_count": _correctIndices.length
            }
        );
        
        if (result != null && result['next_action'] != null) {
           final nextAction = result['next_action'];
           if (nextAction['decision'] == 'REMEDIATION' || nextAction['decision'] == 'TERMINATE') {
               Future.delayed(const Duration(milliseconds: 1400), () {
                 if (mounted) _transitionToNextRound(nextAction);
               });
           } else {
               _processScaffoldAction(nextAction);
               Future.delayed(const Duration(milliseconds: 800), () {
                 if (mounted) {
                   setState(() {
                     _selectedIndices.remove(index);
                   });
                 }
               });
           }
        } else {
           Future.delayed(const Duration(milliseconds: 800), () {
             if (mounted) {
               setState(() {
                 _selectedIndices.remove(index);
               });
             }
           });
        }
      }
      return;
    }
    
    // Correct tap! Check if ALL targets are found
    SoundUtils.playFeedback('audio/correct.mp3');
    bool allTargetsFound = _correctIndices.every((i) => _selectedIndices.contains(i));
    
    if (allTargetsFound) {
       // COMPLETE exactly once
       final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
       if (wrapper != null) {
          final result = await wrapper.completeAdaptiveRound(100, itemId: _currentItemId);
          setState(() {
             _isCorrect = true;
          });
          
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) {
               final nextAction = (result != null && result.containsKey('next_action')) 
                   ? result['next_action'] 
                   : null;
               _transitionToNextRound(nextAction as Map<String, dynamic>?);
            }
          });
       }
    } else {
       // Correct partial tap -> update local selected state only
       // Highlight should disappear since it's selected
       setState(() {
           _highlightIndices.remove(index);
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    var rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('වචනයට සවන් දී පින්තූරය සොයමු')),
        body: const Center(child: Text('No rounds available.')),
      );
    }

    final titleText = widget.activityNode?.title ?? 'වචනයට සවන් දී පින්තූරය සොයමු';

    double itemSize;
    double spacing;
    double fontSize;
    final total = _options.length;
    final bool hasLongText = _options.any((opt) => opt.toString().length > 4 || opt.toString().contains(' '));

    if (total <= 2) {
      itemSize = 160.0;
      spacing = 32.0;
      fontSize = 72.0;
    } else if (total <= 4) {
      itemSize = 130.0;
      spacing = 16.0;
      fontSize = 56.0;
    } else if (total <= 6) {
      itemSize = 100.0;
      spacing = 12.0;
      fontSize = 48.0;
    } else if (total <= 9) {
      itemSize = 80.0;
      spacing = 10.0;
      fontSize = 40.0;
    } else {
      itemSize = 64.0;
      spacing = 8.0;
      fontSize = 32.0;
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
            _buildInstructionCard(_promptText),
            if (_displayWord.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.5), width: 2.5),
                  boxShadow: [
                    BoxShadow(color: AppColors.warmAmber.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  _displayWord,
                  style: AppTypography.sinhala(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_correctIndices.length > 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'අකුරු ${_correctIndices.length} ක් තෝරන්න (${_selectedIndices.length}/${_correctIndices.length})',
                  style: AppTypography.sinhala(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE65100),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 20),
            ],

            Flexible(
              fit: FlexFit.loose,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, -4)),
                  ],
                ),
                child: Center(
                  child: Wrap(
                    key: ValueKey('round_${_currentItemId}'),
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.center,
                    children: List.generate(_options.length, (index) {
                      if (_hiddenIndices.contains(index)) return const SizedBox.shrink();
                      
                      final isSelected = _selectedIndices.contains(index);
                      final isRight = isSelected && _correctIndices.contains(index);
                      final isWrong = isSelected && !_correctIndices.contains(index);
                      final isHighlighted = _highlightIndices.contains(index);

                      return GestureDetector(
                        onTap: () => _checkAnswer(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: hasLongText ? null : itemSize,
                          height: hasLongText ? null : itemSize,
                          padding: hasLongText ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16) : null,
                          decoration: BoxDecoration(
                            color: isRight
                                ? const Color(0xFF6DBE6D).withValues(alpha: 0.15)
                                : isWrong
                                ? const Color(0xFFE87C6D).withValues(alpha: 0.15)
                                : isHighlighted 
                                ? AppColors.warmAmber.withValues(alpha: 0.3)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isRight
                                  ? const Color(0xFF6DBE6D)
                                  : isWrong
                                  ? const Color(0xFFE87C6D)
                                  : isHighlighted 
                                  ? AppColors.warmAmber
                                  : AppColors.borderLight,
                              width: (isRight || isWrong || isHighlighted) ? 4.0 : 3.0,
                            ),
                            boxShadow: [
                              if (isRight)
                                BoxShadow(color: const Color(0xFF6DBE6D).withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)
                              else if (isWrong)
                                BoxShadow(color: const Color(0xFFE87C6D).withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)
                              else if (isHighlighted)
                                BoxShadow(color: AppColors.warmAmber.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)
                              else
                                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _options[index],
                              style: TextStyle(fontSize: hasLongText ? 24.0 : fontSize),
                              textAlign: TextAlign.center,
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
                  BoxShadow(color: AppColors.warmAmber.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}
