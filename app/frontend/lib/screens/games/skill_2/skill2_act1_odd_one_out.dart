import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sipsara_app/utils/sound_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/telemetry_wrapper.dart';
import '../../../models/curriculum_models.dart';
import '../shared_templates/widgets/shared_game_layout.dart';
import '../../../services/progress_service.dart';
import '../shared_widgets/shared_celebration_popup.dart';
import '../../../services/tts_service.dart';
import '../../../adaptive/controllers/adaptive_choice_controller.dart';
import '../../../adaptive/models/adaptive_scaffold_models.dart';
import '../../../adaptive/widgets/adaptive_answer_pool.dart';
import 'skill2_round_resolver.dart';

class Skill2Act1OddOneOut extends StatefulWidget {
  final ActivityNode? activityNode;
  final Map<String, dynamic>? studentData;
  final bool isRemedial;

  const Skill2Act1OddOneOut({
    super.key,
    this.activityNode,
    this.isRemedial = false,
    this.studentData,
  });

  @override
  State<Skill2Act1OddOneOut> createState() => _Skill2Act1OddOneOutState();
}

class _Skill2Act1OddOneOutState extends State<Skill2Act1OddOneOut> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentRoundIndex = 0;
  bool _isRoundComplete = false;
  bool _isActivityComplete = false;

  late List<Map<String, dynamic>> _shuffledItems;
  Set<int> _foundIndices = {};
  int _targetCount = 0;

  // Track temporarily tapped incorrect items for red flash
  Set<int> _wrongIndices = {};
  final AdaptiveChoiceController<int> _choiceController =
      AdaptiveChoiceController<int>();
  String? _currentVariantId;
  String _currentItemId = '';
  Map<String, dynamic> _activeRoundData = <String, dynamic>{};

  // No randomized colors; we use clean, readable white/cream tiles

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
      if (Skill2RoundResolver.shouldAutoplayActivityIntroduction(
        roundIndex: _currentRoundIndex,
        variantId: _currentVariantId,
      )) {
        _playCurrentInstruction();
      }
    });
  }

  void _playCurrentInstruction() {
    String spokenInstruction = 'කොටුවේ පෙන්වා ඇති අකුර සොයන්න.';
    TtsService().speak(spokenInstruction, folder: 'skill_2');
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _choiceController.dispose();
    super.dispose();
  }

  void _setupRound() {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isNotEmpty && _currentRoundIndex < rounds.length) {
      final resolved = Skill2RoundResolver.resolve(
        activity: widget.activityNode,
        roundIndex: _currentRoundIndex,
        variantId: _currentVariantId,
      );
      _currentItemId = resolved.itemId;
      _currentVariantId = resolved.variantId;
      _activeRoundData = resolved.data;

      final rawItems = _activeRoundData['items'] as List<dynamic>? ?? [];
      final items = rawItems.asMap().entries.map((entry) {
        final item = Map<String, dynamic>.from(entry.value as Map);
        item['option_id'] ??= '${_canonicalItemId()}_O${entry.key + 1}';
        return item;
      }).toList();

      // Shuffle the items for this round
      items.shuffle(Random());
      _shuffledItems = items;

      final targetLetter = _activeRoundData['target_letter']?.toString();

      // Count targets (support both new 'is_target' boolean and old 'target_letter' string)
      _targetCount = items.where((item) {
        if (item.containsKey('is_target')) {
          return item['is_target'] == true;
        }
        return item['value'] == targetLetter;
      }).length;
      _choiceController.configure(
        List<AdaptiveOption<int>>.generate(items.length, (index) {
          final item = items[index];
          final isTarget =
              item['is_target'] == true ||
              (item['is_target'] == null && item['value'] == targetLetter);
          final id = item['option_id'].toString();
          return AdaptiveOption<int>(
            id: id,
            value: index,
            role: isTarget
                ? AdaptiveOptionRole.target
                : AdaptiveOptionRole.visualDistractor,
            metadata: item,
          );
        }),
      );
    } else {
      _shuffledItems = [];
      _targetCount = 0;
      _currentItemId = '';
      _activeRoundData = <String, dynamic>{};
    }

    _foundIndices.clear();
    _wrongIndices.clear();
    _isRoundComplete = false;
  }

  String _canonicalItemId() {
    return _currentItemId;
  }

  String _optionId(int index) =>
      _shuffledItems[index]['option_id']?.toString() ??
      '${_canonicalItemId()}_O${index + 1}';

  void _transitionToNextRound(Map<String, dynamic>? c4Result) {
    final rounds = widget.activityNode?.rounds ?? [];

    int? nextIdx;
    if (c4Result != null && c4Result.containsKey('next_action')) {
      final nextAction = c4Result['next_action'];

      if (nextAction['decision'] == 'CURRICULUM_COMPLETE' ||
          nextAction['decision'] == 'ACTIVITY_COMPLETE') {
        setState(() {
          _isActivityComplete = true;
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
        _currentVariantId = Skill2RoundResolver.variantFromItemId(nextItem);
        nextIdx = Skill2RoundResolver.roundIndexFromItemId(nextItem);
      }
    }

    // Sequential fallback if backend fails or returns null
    if (nextIdx == null) {
      debugPrint(
        'BACKEND_ERROR_SEQUENTIAL_FALLBACK (no result or missing next_action)',
      );
      nextIdx = _currentRoundIndex + 1;
    }

    if (nextIdx < rounds.length) {
      setState(() {
        _currentRoundIndex = nextIdx!;
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
        _setupRound();
      });
    } else {
      setState(() {
        _isActivityComplete = true;
        final sId = widget.activityNode?.skillId ?? '';
        final aId = widget.activityNode?.id ?? '';
        if (sId.isNotEmpty && aId.isNotEmpty) {
          ProgressService().saveActivityScore(sId, aId, 100);
          ProgressService().clearActivityState(sId, aId);
        }
      });
    }
  }

  Future<void> _onItemTapped(int index) async {
    if (_isRoundComplete ||
        _foundIndices.contains(index) ||
        _choiceController.removedIds.contains(_optionId(index)))
      return;

    final item = _shuffledItems[index];
    final targetLetter = _activeRoundData['target_letter']?.toString();

    final isCorrect =
        item['is_target'] == true ||
        (item['is_target'] == null && item['value'] == targetLetter);

    if (isCorrect) {
      setState(() {
        _foundIndices.add(index);
        _choiceController.markCorrect(_optionId(index));
      });
      SoundUtils.playFeedback('audio/correct.mp3');

      if (_foundIndices.length == _targetCount) {
        setState(() {
          _isRoundComplete = true;
        });

        final c4Result = await context
            .findAncestorStateOfType<TelemetryWrapperState>()
            ?.completeAdaptiveRound(
              100,
              currentRoundIndex: _currentRoundIndex,
              itemId: _canonicalItemId(),
              selectedAnswers: _foundIndices.map(_optionId).toList(),
            );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _transitionToNextRound(c4Result);
        });
      }
    } else {
      setState(() {
        _wrongIndices.add(index);
        _choiceController.markIncorrect(_optionId(index));
      });
      SoundUtils.playFeedback('audio/wrong.mp3');

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _wrongIndices.remove(index);
            _choiceController.clearTransientFeedback();
          });
        }
      });

      final extraTelemetry = {
        "original_options_count": _shuffledItems.length,
        "visible_option_ids": _choiceController.visibleOptions
            .map((option) => option.id)
            .toList(),
        "incorrect_option_ids": List.generate(_shuffledItems.length, (i) => i)
            .where((i) {
              final it = _shuffledItems[i];
              final tg = _activeRoundData['target_letter']?.toString();
              final isTarget =
                  it['is_target'] == true ||
                  (it['is_target'] == null && it['value'] == tg);
              return !isTarget &&
                  !_choiceController.removedIds.contains(_optionId(i));
            })
            .map(_optionId)
            .toList(),
        "remaining_target_ids": List.generate(_shuffledItems.length, (i) => i)
            .where((i) {
              final it = _shuffledItems[i];
              final tg = _activeRoundData['target_letter']?.toString();
              return (it['is_target'] == true ||
                      (it['is_target'] == null && it['value'] == tg)) &&
                  !_foundIndices.contains(i);
            })
            .map(_optionId)
            .toList(),
        "correct_option_ids": List.generate(_shuffledItems.length, (i) => i)
            .where(
              (i) =>
                  _choiceController.allOptions[i].isTarget &&
                  !_foundIndices.contains(i),
            )
            .map(_optionId)
            .toList(),
        "selected_option_ids": _foundIndices.map(_optionId).toList(),
        "supported_actions": [
          "REMOVE_OPTION",
          "HIGHLIGHT_OPTION",
          "REPLAY_INSTRUCTION",
        ],
        "minimum_visible_options": 2,
      };

      final c4Result = await context
          .findAncestorStateOfType<TelemetryWrapperState>()
          ?.registerAdaptiveWrongAttempt(
            currentRoundIndex: _currentRoundIndex,
            itemId: _canonicalItemId(),
            extraTelemetry: extraTelemetry,
          );

      if (c4Result != null && c4Result.containsKey('next_action')) {
        final nextAction = c4Result['next_action'];

        if (nextAction['decision'] == 'TERMINATE' ||
            nextAction['decision'] == 'REMEDIATION') {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (!mounted) return;
            _transitionToNextRound(c4Result);
          });
          return;
        }

        context
            .findAncestorStateOfType<TelemetryWrapperState>()
            ?.applyScaffoldResult<int>(
              controller: _choiceController,
              result: c4Result,
              correctOptionIds: (extraTelemetry['correct_option_ids'] as List)
                  .cast<String>(),
            );
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isRoundComplete) {
          setState(() {
            _wrongIndices.remove(index);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rounds = widget.activityNode?.rounds ?? [];
    if (rounds.isEmpty || _shuffledItems.isEmpty) {
      return const Scaffold(body: Center(child: Text('No rounds available')));
    }

    final promptText = 'කොටුවේ පෙන්වා ඇති අකුර සොයන්න.';
    final titleText = widget.activityNode?.title ?? 'නිවැරදි අකුර සොයමු';

    String? targetLetter;
    final itemsList = _activeRoundData['items'];
    if (itemsList != null) {
      List<String> uniqueLetters = [];
      for (var item in itemsList) {
        if (item['is_target'] == true && item['type'] == 'letter') {
          final val = item['value']?.toString();
          if (val != null && !uniqueLetters.contains(val)) {
            uniqueLetters.add(val);
          }
        }
      }
      if (uniqueLetters.isNotEmpty) {
        targetLetter = uniqueLetters.join(' ');
      }
    }

    return SharedGameLayout(
      studentData: widget.studentData,
      activityTitle: widget.activityNode?.title ?? '',
      title: titleText,
      currentRoundIndex: _currentRoundIndex,
      totalRounds: rounds.length,
      isRoundComplete: _isRoundComplete,
      isActivityComplete: _isActivityComplete,
      onNext: () {
        final wrapper = context
            .findAncestorStateOfType<TelemetryWrapperState>();
        if (wrapper != null) {
          wrapper.completeActivity(context);
        } else {
          Navigator.pop(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Skill 1 Style Instruction Card with Isolated Letter
            _buildInstructionCard(promptText, targetLetter),
            const SizedBox(height: 12),

            // Found Counter
            _buildFoundCounter(),
            const SizedBox(height: 32),

            // Giant Wooden Board with Grid of Tiles
            Expanded(child: Center(child: _buildWoodenBoard())),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(String instruction, [String? targetLetter]) {
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
            if (targetLetter != null) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.warmAmber.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      (targetLetter.contains('අ') || targetLetter.contains('ආ'))
                          ? -4.0
                          : 0.0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          targetLetter,
                          style: AppTypography.sinhala(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
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

  Widget _buildFoundCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _foundIndices.length == _targetCount
            ? const Color(0xFF6DBE6D).withValues(alpha: 0.15)
            : const Color(0xFFF9C623).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _foundIndices.length == _targetCount
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
            _foundIndices.length == _targetCount
                ? Icons.check_circle_rounded
                : Icons.search_rounded,
            color: _foundIndices.length == _targetCount
                ? const Color(0xFF6DBE6D)
                : const Color(0xFFE8A54B),
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${_foundIndices.length} / $_targetCount සොයා ගත්තා',
                style: AppTypography.sinhala(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _foundIndices.length == _targetCount
                      ? const Color(0xFF4E9E4E)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoodenBoard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE8C396), // Light warm wood inner
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFF8B5A2B),
          width: 10,
        ), // Thick dark wood frame
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          // Inner shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(
              0,
              5,
            ), // Inner top shadow to make it feel recessed
          ),
        ],
      ),
      child: _buildCardGrid(),
    );
  }

  Widget _buildCardGrid() {
    final total = _choiceController.visibleOptions.length;

    // Dynamic sizing based on items to perfectly fit the board
    double itemSize;
    double spacing;

    if (total <= 4) {
      itemSize = 115.0;
      spacing = 24.0;
    } else {
      itemSize = 90.0;
      spacing = 16.0;
    }

    return AdaptiveAnswerPool<int>(
      controller: _choiceController,
      spacing: spacing,
      minExtent: itemSize,
      maxExtent: itemSize,
      itemBuilder: (context, option, state, extent) => SizedBox(
        width: extent,
        height: extent + 8,
        child: _buildCard(option.value),
      ),
    );
  }

  Widget _buildCard(int index) {
    final item = _shuffledItems[index];
    final isFound = _foundIndices.contains(index);
    final isWrong = _wrongIndices.contains(index);
    final isHighlighted =
        _choiceController.visualStateFor(_optionId(index)) ==
        AdaptiveOptionVisualState.hint;

    // 3D Press state
    final isPressed = isFound || isWrong;

    // Base colors (Clean white for readability)
    Color tileColor = Colors.white;
    Color borderColor = Colors.black.withValues(alpha: 0.1);
    Color shadowColor = const Color(0xFFD1D5DB); // Light grey shadow
    Color textColor = AppColors.textPrimary;
    double borderWidth = 2.0;

    if (isFound) {
      tileColor = AppColors.gentleGreen;
      borderColor = Colors.green[700]!;
      shadowColor = Colors.green[800]!;
      textColor = Colors.white;
    } else if (isWrong) {
      tileColor = AppColors.softCoral;
      borderColor = Colors.red[800]!;
      shadowColor = Colors.red[900]!;
      textColor = Colors.white;
    } else if (isHighlighted) {
      tileColor = AppColors.warmAmber.withOpacity(0.3);
      borderColor = AppColors.warmAmber;
      shadowColor = AppColors.warmAmber;
    }

    // Dim the unselected tiles if the round is complete to focus on the correct answers
    final double tileOpacity = (_isRoundComplete && !isFound) ? 0.5 : 1.0;

    Widget content;
    if (item['type'] == 'icon') {
      content = Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.asset(item['value'], fit: BoxFit.contain),
      );
    } else {
      content = Center(
        child: Text(
          item['value'],
          style: TextStyle(
            fontFamily: 'IskoolaPota',
            fontSize: _shuffledItems.length > 4 ? 56 : 72,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) {
        if (!_isRoundComplete && !_foundIndices.contains(index)) {
          // Play a tiny click sound or just let visual feedback handle it
        }
      },
      onTap: () => _onItemTapped(index),
      child: Opacity(
        opacity: tileOpacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          // When pressed, the tile moves down by adding top margin and removing bottom margin
          margin: EdgeInsets.only(
            top: isPressed ? 8.0 : 0.0,
            bottom: isPressed ? 0.0 : 8.0,
          ),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPressed
                  ? borderColor
                  : Colors.white.withValues(alpha: 0.5),
              width: isPressed ? borderWidth : 2,
            ),
            boxShadow: [
              // The 3D bottom edge shadow
              if (!isPressed)
                BoxShadow(
                  color: shadowColor,
                  offset: const Offset(0, 8),
                  blurRadius: 0,
                ),
              // General drop shadow
              if (!isPressed)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(0, 12),
                  blurRadius: 10,
                ),
            ],
          ),
          child: AnimatedScale(
            scale: isPressed && isWrong ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: content,
          ),
        ),
      ),
    );
  }
}
