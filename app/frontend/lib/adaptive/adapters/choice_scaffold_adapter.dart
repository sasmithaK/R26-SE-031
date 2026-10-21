import 'package:flutter/material.dart';

import '../../models/curriculum_models.dart';
import '../../widgets/telemetry_wrapper.dart';
import '../controllers/adaptive_choice_controller.dart';
import '../controllers/adaptive_task_coordinator.dart';
import '../models/adaptive_scaffold_models.dart';

/// Reusable adapter for MCQ/audio/fill-blank templates. It keeps task screens
/// responsible for their content while centralizing C4 IDs, capabilities,
/// command application, and treatment-fidelity telemetry.
mixin ChoiceScaffoldAdapter<T extends StatefulWidget> on State<T> {
  final AdaptiveChoiceController<int> adaptiveChoices =
      AdaptiveChoiceController<int>();
  String _adaptiveSignature = '';
  String adaptiveItemId = '';
  int adaptiveCorrectIndex = 0;
  AdaptiveTaskCoordinator? adaptiveTaskCoordinator;

  /// Activity families opt in only to semantic commands they can really
  /// render. This keeps the model's candidate set honest.
  List<String> get adaptiveSemanticScaffoldCapabilities => const <String>[];

  /// Override in an audio activity to execute the semantic
  /// command after the shared choice reducer has handled option commands.
  Future<void> handleAdaptiveSemanticScaffold(ScaffoldCommand command) async {}

  void initializeAdaptiveTask({
    required ActivityNode? activity,
    required int roundIndex,
  }) {
    if (activity == null || activity.rounds.isEmpty) return;
    adaptiveTaskCoordinator ??= AdaptiveTaskCoordinator(
      activity: activity,
      initialRoundIndex: roundIndex,
    );
  }

  Map<String, dynamic> adaptiveRoundData({
    required ActivityNode? activity,
    required int roundIndex,
  }) {
    initializeAdaptiveTask(activity: activity, roundIndex: roundIndex);
    return adaptiveTaskCoordinator?.roundData ??
        (activity != null && roundIndex < activity.rounds.length
            ? activity.rounds[roundIndex]
            : const <String, dynamic>{});
  }

  Future<AdaptiveTaskTransition?> completeAdaptiveChoiceTask(
    int score, {
    required int roundIndex,
    bool? isCorrect,
    List<String> selectedAnswers = const <String>[],
    bool attemptAlreadyLogged = false,
  }) async {
    final result = await submitAdaptiveChoiceTask(
      score,
      roundIndex: roundIndex,
      isCorrect: isCorrect,
      selectedAnswers: selectedAnswers,
      attemptAlreadyLogged: attemptAlreadyLogged,
    );
    return applyAdaptiveChoiceTaskResult(result);
  }

  /// Submit a completed choice task without immediately changing the item
  /// rendered by the game screen.
  ///
  /// Most screens can use [completeAdaptiveChoiceTask]. Screens that display
  /// success feedback before advancing can submit first and commit the result
  /// after their feedback delay. This prevents the previous item's selected
  /// or correct styling from leaking onto the next item for one frame.
  Future<Map<String, dynamic>?> submitAdaptiveChoiceTask(
    int score, {
    required int roundIndex,
    bool? isCorrect,
    List<String> selectedAnswers = const <String>[],
    bool attemptAlreadyLogged = false,
  }) async {
    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    if (wrapper == null || adaptiveTaskCoordinator == null) return null;
    return wrapper.completeAdaptiveRound(
      score,
      currentRoundIndex: roundIndex,
      itemId: adaptiveTaskCoordinator!.itemId,
      isCorrect: isCorrect,
      selectedAnswers: selectedAnswers,
      attemptAlreadyLogged: attemptAlreadyLogged,
    );
  }

  AdaptiveTaskTransition? applyAdaptiveChoiceTaskResult(
    Map<String, dynamic>? result,
  ) => result == null ? null : adaptiveTaskCoordinator?.applyResult(result);

  void configureAdaptiveChoices({
    required ActivityNode? activity,
    required int roundIndex,
    required List<String> options,
    required int correctIndex,
    AdaptiveOptionRole distractorRole = AdaptiveOptionRole.semanticDistractor,
  }) {
    initializeAdaptiveTask(activity: activity, roundIndex: roundIndex);
    final itemId = CanonicalItemResolver.normalizeItemId(
      adaptiveTaskCoordinator?.itemId ??
          (activity != null &&
                  roundIndex >= 0 &&
                  roundIndex < activity.rounds.length
              ? activity.rounds[roundIndex]['item_id']?.toString() ??
                    CanonicalItemResolver.canonicalItemId(
                      skillId: activity.skillId,
                      activityId: activity.id,
                      roundNumber: roundIndex + 1,
                    )
              : 'UNKNOWN_ITEM'),
    );
    final signature = '$itemId|$correctIndex|${options.join('\u001f')}';
    if (_adaptiveSignature == signature) return;
    _adaptiveSignature = signature;
    adaptiveItemId = itemId;
    adaptiveCorrectIndex = correctIndex;
    adaptiveChoices.configure(
      List<AdaptiveOption<int>>.generate(
        options.length,
        (index) => AdaptiveOption<int>(
          id: adaptiveOptionId(index),
          value: index,
          role: index == correctIndex
              ? AdaptiveOptionRole.target
              : distractorRole,
          metadata: <String, dynamic>{'label': options[index]},
        ),
      ),
    );
  }

  String adaptiveOptionId(int index) => '${adaptiveItemId}_O${index + 1}';

  List<String> get adaptiveOptionLabels => adaptiveChoices.allOptions
      .map((option) => option.metadata['label']?.toString() ?? '')
      .toList();

  bool isAdaptivelyRemoved(int index) =>
      adaptiveChoices.removedIds.contains(adaptiveOptionId(index));

  bool isAdaptivelyHighlighted(int index) =>
      adaptiveChoices.visualStateFor(adaptiveOptionId(index)) ==
      AdaptiveOptionVisualState.hint;

  Future<ScaffoldApplicationReport?> requestChoiceScaffold({
    required int selectedIndex,
    required List<String> options,
    required int correctIndex,
    required String errorType,
    List<String> struggledTargetUnits = const <String>[],
    List<String> additionalCapabilities = const <String>[],
  }) async {
    adaptiveChoices.markIncorrect(adaptiveOptionId(selectedIndex));
    final wrapper = context.findAncestorStateOfType<TelemetryWrapperState>();
    if (wrapper == null) return null;
    final result = await wrapper.registerAdaptiveWrongAttempt(
      itemId: adaptiveItemId,
      extraTelemetry: <String, dynamic>{
        'original_options_count': options.length,
        'visible_option_ids': adaptiveChoices.visibleOptions
            .map((option) => option.id)
            .toList(),
        'incorrect_option_ids': <String>[
          adaptiveOptionId(selectedIndex),
          ...adaptiveChoices.visibleOptions
              .where(
                (option) =>
                    option.value != correctIndex &&
                    option.value != selectedIndex,
              )
              .map((option) => option.id),
        ],
        'correct_option_ids': <String>[adaptiveOptionId(correctIndex)],
        'selected_option_ids': <String>[adaptiveOptionId(selectedIndex)],
        'selected_answer_values': <String>[options[selectedIndex]],
        'supported_actions': <String>{
          'REMOVE_OPTION',
          'HIGHLIGHT_OPTION',
          ...adaptiveSemanticScaffoldCapabilities,
          ...additionalCapabilities,
        }.toList(),
        'minimum_visible_options': 2,
        'error_type': errorType,
        'struggled_target_units': struggledTargetUnits,
      },
    );
    final report = wrapper.applyScaffoldResult<int>(
      controller: adaptiveChoices,
      result: result,
      correctOptionIds: <String>[adaptiveOptionId(correctIndex)],
    );
    final rawAction = result?['next_action'];
    if (rawAction is Map) {
      final plan = ScaffoldPlan.fromNextAction(
        Map<String, dynamic>.from(rawAction),
        correctOptionIds: <String>[adaptiveOptionId(correctIndex)],
      );
      for (final command in plan.commands) {
        if (command.type == ScaffoldActionType.replayInstruction ||
            command.type == ScaffoldActionType.slowAudio ||
            command.type == ScaffoldActionType.pauseSession) {
          await handleAdaptiveSemanticScaffold(command);
        }
      }
    }
    return report;
  }

  void clearAdaptiveWrongFeedback() => adaptiveChoices.clearTransientFeedback();

  void disposeChoiceScaffoldAdapter() => adaptiveChoices.dispose();
}
