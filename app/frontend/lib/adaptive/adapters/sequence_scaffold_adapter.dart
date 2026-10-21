import 'package:flutter/material.dart';

import '../../models/curriculum_models.dart';
import '../../widgets/telemetry_wrapper.dart';
import '../models/adaptive_scaffold_models.dart';
import '../controllers/adaptive_task_coordinator.dart';

/// Shared Component 4 bridge for jumbled-word and jumbled-sentence tasks.
/// Tokens retain their original pool position as a stable research ID even
/// after the UI moves them into answer slots.
mixin SequenceScaffoldAdapter<T extends StatefulWidget> on State<T> {
  String adaptiveSequenceItemId = '';
  final Set<int> adaptiveHintedTokenIndices = <int>{};
  String _sequenceSignature = '';
  List<String> _sequenceTokens = const <String>[];
  List<String> _correctSequence = const <String>[];
  List<int> _correctPoolIndices = const <int>[];
  AdaptiveTaskCoordinator? adaptiveTaskCoordinator;

  /// Sequence screens implement semantic commands here. Keeping this hook in
  /// the shared adapter guarantees that an advertised replay is rendered
  /// instead of being silently accepted by the backend and discarded.
  Future<void> handleAdaptiveSequenceSemanticScaffold(
    ScaffoldCommand command,
  ) async {}

  void initializeAdaptiveSequenceTask({
    required ActivityNode? activity,
    required int roundIndex,
  }) {
    if (activity == null || activity.rounds.isEmpty) return;
    adaptiveTaskCoordinator ??= AdaptiveTaskCoordinator(
      activity: activity,
      initialRoundIndex: roundIndex,
    );
  }

  Map<String, dynamic> adaptiveSequenceRoundData({
    required ActivityNode? activity,
    required int roundIndex,
  }) {
    initializeAdaptiveSequenceTask(activity: activity, roundIndex: roundIndex);
    return adaptiveTaskCoordinator?.roundData ??
        (activity != null && roundIndex < activity.rounds.length
            ? activity.rounds[roundIndex]
            : const <String, dynamic>{});
  }

  Future<AdaptiveTaskTransition?> completeAdaptiveSequenceTask(
    int score, {
    required int roundIndex,
    List<String> selectedAnswers = const <String>[],
  }) async {
    final result = await submitAdaptiveSequenceTask(
      score,
      roundIndex: roundIndex,
      selectedAnswers: selectedAnswers,
    );
    return applyAdaptiveSequenceTaskResult(result);
  }

  /// Submit without changing the rendered item. Sequence screens use this to
  /// keep the completed sentence visible during their success-feedback delay.
  Future<Map<String, dynamic>?> submitAdaptiveSequenceTask(
    int score, {
    required int roundIndex,
    List<String> selectedAnswers = const <String>[],
  }) async {
    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    if (wrapper == null || adaptiveTaskCoordinator == null) return null;
    return wrapper.completeAdaptiveRound(
      score,
      currentRoundIndex: roundIndex,
      itemId: adaptiveTaskCoordinator!.itemId,
      selectedAnswers: selectedAnswers,
    );
  }

  AdaptiveTaskTransition? applyAdaptiveSequenceTaskResult(
    Map<String, dynamic>? result,
  ) => result == null ? null : adaptiveTaskCoordinator?.applyResult(result);

  void configureAdaptiveSequence({
    required ActivityNode? activity,
    required int roundIndex,
    required List<String> poolTokens,
    required List<String> correctSequence,
  }) {
    initializeAdaptiveSequenceTask(activity: activity, roundIndex: roundIndex);
    final itemId = CanonicalItemResolver.normalizeItemId(
      adaptiveTaskCoordinator?.itemId ??
          (activity != null && roundIndex < activity.rounds.length
              ? activity.rounds[roundIndex]['item_id']?.toString() ??
                    CanonicalItemResolver.canonicalItemId(
                      skillId: activity.skillId,
                      activityId: activity.id,
                      roundNumber: roundIndex + 1,
                    )
              : 'UNKNOWN_ITEM'),
    );
    final signature = '$itemId|${poolTokens.join('\u001f')}';
    if (_sequenceSignature == signature) return;
    _sequenceSignature = signature;
    adaptiveSequenceItemId = itemId;
    _sequenceTokens = List<String>.unmodifiable(poolTokens);
    _correctSequence = List<String>.unmodifiable(correctSequence);
    final usedIndices = <int>{};
    final resolvedIndices = <int>[];
    for (final correctToken in _correctSequence) {
      final index = List<int>.generate(_sequenceTokens.length, (value) => value)
          .firstWhere(
            (candidate) =>
                !usedIndices.contains(candidate) &&
                _sequenceTokens[candidate] == correctToken,
            orElse: () => -1,
          );
      if (index < 0) {
        resolvedIndices.clear();
        break;
      }
      usedIndices.add(index);
      resolvedIndices.add(index);
    }
    _correctPoolIndices = List<int>.unmodifiable(resolvedIndices);
    adaptiveHintedTokenIndices.clear();
  }

  String adaptiveTokenId(int originalIndex) =>
      '${adaptiveSequenceItemId}_T${originalIndex + 1}';

  bool isAdaptiveTokenHinted(int originalIndex) =>
      adaptiveHintedTokenIndices.contains(originalIndex);

  Future<void> requestSequenceScaffold({
    required List<int> selectedPoolIndices,
    int correctPosition = 0,
  }) async {
    if (_sequenceTokens.isEmpty || _correctPoolIndices.isEmpty) return;
    final safePosition = correctPosition
        .clamp(0, _correctPoolIndices.length - 1)
        .toInt();
    final targetIndex = _correctPoolIndices[safePosition];
    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    if (wrapper == null) return;
    final result = await wrapper.registerAdaptiveWrongAttempt(
      itemId: adaptiveSequenceItemId,
      extraTelemetry: <String, dynamic>{
        'original_options_count': _sequenceTokens.length,
        'visible_option_ids': List<String>.generate(
          _sequenceTokens.length,
          adaptiveTokenId,
        ),
        // Every token belongs to the answer; the error is its position, not
        // its identity. Never label future required tokens as distractors.
        'incorrect_option_ids': const <String>[],
        'correct_option_ids': <String>[adaptiveTokenId(targetIndex)],
        'selected_option_ids': selectedPoolIndices
            .map(adaptiveTokenId)
            .toList(),
        'selected_answer_values': selectedPoolIndices
            .where((index) => index >= 0 && index < _sequenceTokens.length)
            .map((index) => _sequenceTokens[index])
            .toList(),
        'supported_actions': const <String>[
          'HIGHLIGHT_OPTION',
          'REVEAL_FIRST_TOKEN',
          'REPLAY_INSTRUCTION',
        ],
        'minimum_visible_options': 2,
        'error_type': 'sequence_error',
      },
    );
    final plan = wrapper.semanticScaffoldPlanFromResult(
      result: result,
      correctOptionIds: <String>[adaptiveTokenId(targetIndex)],
      visibleOptionCount: _sequenceTokens.length,
    );
    if (plan == null || !mounted) return;
    for (final command in plan.commands) {
      if (command.type == ScaffoldActionType.replayInstruction ||
          command.type == ScaffoldActionType.slowAudio ||
          command.type == ScaffoldActionType.pauseSession) {
        await handleAdaptiveSequenceSemanticScaffold(command);
      }
    }
    if (!mounted) return;
    final hintedIds = plan.commands
        .where(
          (command) =>
              command.type == ScaffoldActionType.highlightOptions ||
              command.type == ScaffoldActionType.revealFirstToken,
        )
        .expand((command) => command.targetOptionIds)
        .toSet();
    if (hintedIds.isNotEmpty) {
      setState(() {
        adaptiveHintedTokenIndices
          ..clear()
          ..addAll(
            List<int>.generate(
              _sequenceTokens.length,
              (index) => index,
            ).where((index) => hintedIds.contains(adaptiveTokenId(index))),
          );
      });
    }
  }
}
