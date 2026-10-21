import 'package:flutter/material.dart';
import '../services/telemetry_service.dart';
import '../services/telemetry/plugins/voice_analysis_plugin.dart';
import '../services/telemetry/plugins/eye_tracking_plugin.dart';
import '../models/curriculum_models.dart';
import '../screens/activity_complete_screen.dart';
import '../screens/games/game_factory.dart';
import '../services/tts_service.dart';
import '../services/student_service.dart';
import '../services/progress_service.dart';
import '../adaptive/controllers/adaptive_choice_controller.dart';
import '../adaptive/models/adaptive_scaffold_models.dart';

@visibleForTesting
int countInstructionalChoiceHints(Iterable<ScaffoldCommand> commands) {
  return commands
      .where(
        (command) =>
            command.type == ScaffoldActionType.highlightOptions ||
            command.type == ScaffoldActionType.removeOptions ||
            command.type == ScaffoldActionType.disableOptions,
      )
      .length;
}

/// A wrapper widget that tracks all touch events, latency, and coordinates
/// before they reach the underlying game template.
///
/// Enhanced metrics captured per round:
///  - [firstTouchLatencyMs] — time from round start to first tap
///  - [totalRoundLatencyMs] — full time from round start to completion
///  - [misclickCount] — taps outside target areas (game must call [recordMisclick])
///  - [hesitationCount] — Grade 1 pauses > 8s without any touch
///  - [touchPath]       — normalized (x%, y%) coordinates for each touch
class TelemetryWrapper extends StatefulWidget {
  final ActivityNode activityNode;
  final Widget child;
  final Function(int score) onRoundComplete;
  final Map<String, dynamic>? studentData;

  const TelemetryWrapper({
    super.key,
    required this.activityNode,
    required this.child,
    required this.onRoundComplete,
    this.studentData,
  });

  @override
  State<TelemetryWrapper> createState() => TelemetryWrapperState();

  static TelemetryWrapperState? of(BuildContext context) {
    return context.findAncestorStateOfType<TelemetryWrapperState>();
  }
}

class TelemetryWrapperState extends State<TelemetryWrapper> {
  // ---- Timing ----
  late Stopwatch _roundStopwatch;
  late Stopwatch _hesitationStopwatch;

  // ---- Rich metric accumulators ----
  final List<TouchPoint> _currentTouchPath = [];
  int _firstTouchLatencyMs = -1; // -1 = no touch received yet this round
  int _misclickCount = 0;
  int _hesitationCount = 0;
  int _audioReplayCount = 0;
  int _correctionCount = 0;
  int _hintCount = 0;
  bool _firstTouchRecorded = false;

  // ---- Attempt Tracking ----
  int _attemptCount = 0;
  int _incorrectAttemptCount = 0;
  bool? _firstAttemptCorrect;
  final List<String> _accumulatedAnswers = [];
  final List<Map<String, dynamic>> _attemptHistory = [];
  String? _firstErrorType;
  final List<Map<String, dynamic>> _scaffoldApplications = [];

  // ---- Session accumulators ----
  int _totalScore = 0;
  int _roundsCompletedTotal = 0;
  int _currentRound = 1;
  int _highestScaffoldUsed = 0;
  bool _activityCompleted = false;
  bool _breakRecommendedAfterActivity = false;
  bool _abandonmentLogged = false;
  String? _activeItemId;

  /// Round time (ms) at the moment the child gave the final correct answer.
  /// Games call [markResponseComplete] there, so celebration animations that
  /// run before the round is submitted are not counted as response time.
  int? _responseCompleteMs;

  /// Round time (ms) of the child's first answer (first choice, tap on a
  /// picture or drop on a target). Unlike first touch, taps on the speaker,
  /// back button or tray are not answers.
  int? _firstResponseMs;

  /// Drags released outside every target (a motor miss, not a wrong answer).
  int _strayDropCount = 0;

  @visibleForTesting
  int get currentRound => _currentRound;

  @visibleForTesting
  set currentRound(int value) => _currentRound = value;

  // ---- Hesitation timer ----
  // Grade-1 learners need time to inspect pictures, decode Sinhala prompts,
  // and plan a drag/tap response. A normal 3-5 second pause is not struggle.
  static const int _hesitationThresholdMs = 8000;

  // ---- State Blocking ----
  bool _isSubmittingRound = false;

  @override
  void initState() {
    super.initState();
    if (widget.activityNode.rounds.isNotEmpty) {
      _activeItemId = CanonicalItemResolver.resolve(
        widget.activityNode,
        widget.activityNode.rounds.first,
        0,
      ).itemId;
    }
    _roundStopwatch = Stopwatch()..start();
    _hesitationStopwatch = Stopwatch()..start();
    _initPluginsOnce();

    TelemetryService().broadcastRoundStart(
      widget.activityNode.templateType,
      _currentRound,
      widget.activityNode.telemetryTags,
    );
  }

  @override
  void dispose() {
    if (_roundStopwatch.isRunning &&
        _roundsCompletedTotal < widget.activityNode.rounds.length) {
      // The wrapper was disposed before the game finished natively -> Abandonment
      _logAbandonment();
    }
    _roundStopwatch.stop();
    _hesitationStopwatch.stop();

    // Stop any ongoing TTS audio when navigating away from the activity
    TtsService().stop();

    super.dispose();
  }

  /// Freeze the round's response time at the child's final correct answer.
  /// Touches after this point (during feedback/celebration) are not recorded.
  void markResponseComplete() {
    _responseCompleteMs ??= _roundStopwatch.elapsedMilliseconds;
  }

  /// Mark the child's first answer in this round (the first call wins).
  /// [logAttempt] calls this too, so single-choice games need no extra call.
  void markAnswer() {
    _firstResponseMs ??=
        _responseCompleteMs ?? _roundStopwatch.elapsedMilliseconds;
  }

  /// A drag released outside every target. Counted separately from wrong
  /// answers so movement precision is not confused with knowledge.
  void recordStrayDrop() {
    if (_responseCompleteMs != null || _isSubmittingRound) return;
    _strayDropCount++;
  }

  void _logAbandonment() {
    if (widget.activityNode.isParentPractice) return;
    if (_activityCompleted || _abandonmentLogged) return;
    // Letter-pronunciation practice is reading-aloud (C2) evidence; it has no
    // touch rounds, so leaving it is not a C1 abandoned round.
    if (widget.activityNode.templateType == 'letter_pronunciation') return;
    final answeredThisRound =
        _attemptCount > 0 || _firstResponseMs != null || _responseCompleteMs != null;
    // All rounds of the run were completed and nothing was answered since
    // (e.g. closing the completion screen while offline): nothing abandoned.
    // Remediation rounds also increase the completed count, so a round the
    // child had started answering is still logged.
    if (!answeredThisRound &&
        widget.activityNode.rounds.isNotEmpty &&
        (_roundsCompletedTotal >= widget.activityNode.rounds.length ||
            _currentRound > widget.activityNode.rounds.length)) {
      return;
    }
    // The final correct answer was given and the child left during the
    // celebration: record the round as completed (C1 only; Component 4 never
    // received it), not as abandoned.
    final completedDuringFeedback = _responseCompleteMs != null;
    // Seal the unfinished round exactly once. PopScope calls this while the
    // route is still alive so the level map can submit the event immediately
    // after Navigator.push completes. dispose() remains a defensive fallback.
    _abandonmentLogged = true;
    _roundStopwatch.stop();
    final totalRoundLatency = _roundStopwatch.elapsedMilliseconds;
    final roundIndex = widget.activityNode.rounds.isEmpty
        ? 0
        : (_currentRound - 1)
              .clamp(0, widget.activityNode.rounds.length - 1)
              .toInt();
    final roundData = widget.activityNode.rounds.isEmpty
        ? <String, dynamic>{}
        : widget.activityNode.rounds[roundIndex];
    final fallback = CanonicalItemResolver.resolve(
      widget.activityNode,
      roundData,
      roundIndex,
    );
    final canonical = CanonicalItemResolver.resolveByItemId(
      widget.activityNode,
      _activeItemId ?? fallback.itemId,
      roundIndex,
    );
    final researchMeta = widget.activityNode.researchMetadata;
    final sessionId = TelemetryService().sessionId;

    final completedMs = _responseCompleteMs ?? totalRoundLatency;
    final event = TelemetryEvent(
      eventId: completedDuringFeedback
          ? '$sessionId:${canonical.itemId}:complete'
          : '$sessionId:${canonical.itemId}:abandoned',
      phase: completedDuringFeedback ? 'COMPLETE' : 'ABANDONED',
      activityName: widget.activityNode.templateType,
      roundNumber: _currentRound,
      isCorrect: completedDuringFeedback,
      score: completedDuringFeedback ? 100 : 0,
      timestamp: DateTime.now(),
      firstTouchLatencyMs: _firstTouchLatencyMs < 0 ? 0 : _firstTouchLatencyMs,
      totalRoundLatencyMs: completedDuringFeedback ? completedMs : totalRoundLatency,
      misclickCount: _misclickCount,
      hesitationCount: _hesitationCount,
      audioReplayCount: _audioReplayCount,
      isAbandoned: !completedDuringFeedback,
      touchPath: List.unmodifiable(_currentTouchPath),
      attemptCount: completedDuringFeedback
          ? _attemptCount + 1
          : (_attemptCount > 0 ? _attemptCount : 1),
      incorrectAttemptCount: _incorrectAttemptCount,
      firstAttemptCorrect: completedDuringFeedback
          ? (_firstAttemptCorrect ?? true)
          : _firstAttemptCorrect,
      finalCorrect: completedDuringFeedback,
      timeToFirstResponseMs:
          _firstResponseMs ??
          (_firstTouchLatencyMs < 0 ? 0 : _firstTouchLatencyMs),
      timeToCorrectMs: completedDuringFeedback ? completedMs : 0,
      strayDropCount: _strayDropCount,
      skillId: widget.activityNode.skillId,
      activityId: widget.activityNode.id,
      itemId: canonical.itemId,
      itemVersion: canonical.itemVersion,
      knowledgeComponentId: researchMeta?.knowledgeComponentId ?? 'KC_UNKNOWN',
      promptModality: researchMeta?.promptModality ?? 'visual',
      responseModality: researchMeta?.responseModality ?? 'tap',
      researchRole: researchMeta?.researchRole ?? 'primary',
      itemRole: canonical.itemRole,
      equivalentGroupId: canonical.equivalentGroupId,
      responseLoadRelation: canonical.responseLoadRelation,
      difficultyLabel: canonical.difficultyLabel,
      difficultyB: canonical.difficultyB,
      isAnchor: canonical.isAnchor,
      targets: canonical.targets,
      selectedAnswers: List.unmodifiable(_accumulatedAnswers),
      errorType: _firstErrorType ??
          (completedDuringFeedback ? 'none' : 'abandoned_before_completion'),
      scaffoldLevelUsed: _highestScaffoldUsed,
      scaffoldApplications: List<Map<String, dynamic>>.unmodifiable(
        _scaffoldApplications,
      ),
      attemptHistory: List<Map<String, dynamic>>.unmodifiable(_attemptHistory),
    );
    TelemetryService().logInteraction(event);
    debugPrint('TELEMETRY: ACTIVITY ABANDONED AT ROUND $_currentRound');
  }

  void _initPluginsOnce() {
    if (TelemetryService().isPluginRegistered('voice_analysis_v1')) return;

    final voicePlugin = VoiceAnalysisPlugin()..setEnabled(true);
    final eyePlugin = EyeTrackingPlugin()..setEnabled(false);

    TelemetryService().registerPlugin(voicePlugin);
    TelemetryService().registerPlugin(eyePlugin);
  }

  /// Pause hesitation tracking while audio is playing.
  void pauseHesitationTimer() {
    if (_hesitationStopwatch.isRunning) {
      _hesitationStopwatch.stop();
      debugPrint('TELEMETRY: Hesitation timer paused (audio playing).');
    }
  }

  /// Resume hesitation tracking after audio completes.
  void resumeHesitationTimer() {
    if (!_hesitationStopwatch.isRunning) {
      _hesitationStopwatch.reset();
      _hesitationStopwatch.start();
      debugPrint('TELEMETRY: Hesitation timer resumed.');
    }
  }

  /// Resets round and hesitation timers. Used after mandatory wait/memorization phases.
  void resetRoundTimers({bool clearPreResponseEvidence = false}) {
    // The child already answered (e.g. tapped during the audio prompt): keep
    // this round's timing; resetting now would measure from the second answer.
    if (_attemptCount > 0 || _firstResponseMs != null) {
      debugPrint('TELEMETRY: Round timers kept (an answer was already given).');
      return;
    }
    _responseCompleteMs = null;
    _firstResponseMs = null;
    _roundStopwatch.reset();
    _roundStopwatch.start();
    _hesitationStopwatch.reset();
    _hesitationStopwatch.start();
    _firstTouchLatencyMs = -1;
    _firstTouchRecorded = false;
    if (clearPreResponseEvidence) {
      _hesitationCount = 0;
      _currentTouchPath.clear();
    }
    debugPrint('TELEMETRY: Round timers reset.');
  }

  /// Called by the transparent Listener widget on every pointer event.
  void _recordTouch(PointerEvent details, Size screenSize) {
    if (_isSubmittingRound || _responseCompleteMs != null) return;

    // Check for hesitation since last touch
    if (_hesitationStopwatch.elapsedMilliseconds > _hesitationThresholdMs) {
      _hesitationCount++;
      debugPrint(
        'TELEMETRY: Hesitation detected (${_hesitationStopwatch.elapsedMilliseconds} ms).',
      );
    }
    _hesitationStopwatch.reset();
    _hesitationStopwatch.start();

    // Capture first-touch latency
    if (!_firstTouchRecorded) {
      _firstTouchLatencyMs = _roundStopwatch.elapsedMilliseconds;
      _firstTouchRecorded = true;
      debugPrint('TELEMETRY: First touch at $_firstTouchLatencyMs ms.');
    }

    // Determine touch type
    String type = 'move';
    if (details is PointerDownEvent)
      type = 'down';
    else if (details is PointerUpEvent)
      type = 'up';

    // Record normalized touch point
    final xRatio = screenSize.width > 0
        ? (details.position.dx / screenSize.width).clamp(0.0, 1.0)
        : 0.0;
    final yRatio = screenSize.height > 0
        ? (details.position.dy / screenSize.height).clamp(0.0, 1.0)
        : 0.0;

    _currentTouchPath.add(
      TouchPoint(
        xRatio: double.parse(xRatio.toStringAsFixed(3)),
        yRatio: double.parse(yRatio.toStringAsFixed(3)),
        timestampMs: _roundStopwatch.elapsedMilliseconds,
        type: type,
      ),
    );

    TelemetryService().broadcastPointerEvent(details);
  }

  /// Game activities should call this when the child taps a non-target area.
  void recordMisclick() {
    _misclickCount++;
    debugPrint('TELEMETRY: Misclick recorded (total: $_misclickCount).');
  }

  /// Called by games when the child selects a wrong answer but hasn't failed the round yet.
  Future<int?> registerWrongAttempt({
    int? currentRoundIndex,
    int maxAttempts = 3,
  }) async {
    final result = await registerAdaptiveWrongAttempt(
      currentRoundIndex: currentRoundIndex,
      maxAttempts: maxAttempts,
    );
    if (result != null && result.containsKey('next_action')) {
      final nextAction = result['next_action'];
      if (nextAction['decision'] == 'TERMINATE') {
        return currentRoundIndex ?? _currentRound;
      }
    }
    return null; // Return null to indicate no forceful jump yet
  }

  Future<Map<String, dynamic>?> registerAdaptiveWrongAttempt({
    int? currentRoundIndex,
    int maxAttempts = 3,
    Map<String, dynamic>? extraTelemetry,
    String? itemId,
  }) async {
    _misclickCount++;
    logAttempt(
      isCorrect: false,
      selectedAnswers: _extractSelectedAnswers(extraTelemetry),
      errorType: extraTelemetry?['error_type']?.toString(),
    );

    // Parent-launched practice uses reviewed confirmation content as a fresh
    // sequential activity. It must not update BKT, invoke the adaptive policy,
    // or change the child's normal curriculum position.
    if (widget.activityNode.isParentPractice) {
      debugPrint('PARENT_PRACTICE: wrong attempt retained locally.');
      return null;
    }

    final roundNumber = currentRoundIndex != null
        ? currentRoundIndex + 1
        : _currentRound;
    final payloadItemId = CanonicalItemResolver.normalizeItemId(
      itemId ??
          CanonicalItemResolver.canonicalItemId(
            skillId: widget.activityNode.skillId,
            activityId: widget.activityNode.id,
            roundNumber: roundNumber,
          ),
    );
    final canonical = CanonicalItemResolver.resolveByItemId(
      widget.activityNode,
      payloadItemId,
      roundNumber - 1,
    );
    _activeItemId = canonical.itemId;
    final researchMeta = widget.activityNode.researchMetadata;
    final selectedAnswers = _extractSelectedAnswers(extraTelemetry);
    final firstResponseMs = _firstTouchLatencyMs >= 0
        ? _firstTouchLatencyMs
        : 0;
    final attemptErrorType =
        _firstErrorType ??
        extraTelemetry?['error_type']?.toString() ??
        'incorrect_selection';

    // Build attempt payload
    final studentId = _studentId;
    if (studentId == null) {
      debugPrint('C4 submission skipped: no authenticated student identifier.');
      return null;
    }
    final sessionId = TelemetryService().sessionId;

    final payload = {
      "student_id": studentId,
      "session_id": sessionId,
      "event_id": '$sessionId:$payloadItemId:attempt:$_attemptCount',
      "skill_id": widget.activityNode.skillId,
      "activity_id": widget.activityNode.id,
      "round_number": roundNumber,
      "item_id": payloadItemId,
      "knowledge_component_id":
          researchMeta?.knowledgeComponentId ?? 'KC_UNKNOWN',
      "phase": "ATTEMPT",
      "difficulty_b": canonical.difficultyB,
      "is_anchor": canonical.isAnchor,
      "response": {
        "selected_character": selectedAnswers.isEmpty
            ? "item"
            : selectedAnswers.last,
        "is_correct": false,
      },
      "telemetry": {
        "first_touch_latency_ms": firstResponseMs,
        "total_round_latency_ms": _roundStopwatch.elapsedMilliseconds,
        "hesitation_count": _hesitationCount,
        "misclick_count": _misclickCount,
        "audio_replay_count": _audioReplayCount,
        "scaffold_level_used": _highestScaffoldUsed,
        "touch_stream": _currentTouchPath.map((p) => p.toJson()).toList(),
        if (extraTelemetry != null) ...extraTelemetry,
        // Canonical lineage is applied last so game-specific telemetry cannot
        // accidentally replace the identity of the attempted V1/V2 item.
        "item_version": canonical.itemVersion,
        "prompt_modality": researchMeta?.promptModality ?? 'visual',
        "response_modality": researchMeta?.responseModality ?? 'tap',
        "research_role": researchMeta?.researchRole ?? 'primary',
        "difficulty_label": canonical.difficultyLabel,
        "error_type": attemptErrorType,
        "final_correct": false,
        "time_to_first_response_ms": firstResponseMs,
        "time_to_correct_ms": 0,
        "score": 0,
        "is_abandoned": false,
        "attempt_count": _attemptCount,
        "incorrect_attempt_count": _incorrectAttemptCount,
        "first_attempt_correct": false,
        "correction_count": _correctionCount,
        "hint_count": _hintCount,
        "item_role": canonical.itemRole,
        "equivalent_group_id": canonical.equivalentGroupId,
        "response_load_relation": canonical.responseLoadRelation,
        "target_ids": canonical.targets,
        "selected_answers": selectedAnswers,
        "attempt_history": List<Map<String, dynamic>>.from(_attemptHistory),
      },
    };

    final result = await StudentService().submitInteraction(payload);

    if (result != null && result['next_action'] != null) {
      final level = result['next_action']['scaffold_level'];
      if (level is num && level.toInt() > _highestScaffoldUsed) {
        _highestScaffoldUsed = level.toInt();
      }
    }

    debugPrint('\n===== TASK ATTEMPT =====');
    debugPrint('item=$payloadItemId');
    debugPrint('attempt=$_misclickCount');
    debugPrint('result=$result');
    debugPrint('======================\n');

    return result;
  }

  String? get _studentId {
    final value =
        widget.studentData?['id'] ??
        widget.studentData?['_id'] ??
        widget.studentData?['student_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  List<String> _extractSelectedAnswers(Map<String, dynamic>? telemetry) {
    if (telemetry == null) return const <String>[];
    final raw =
        telemetry['selected_answer_values'] ??
        telemetry['selected_option_ids'] ??
        telemetry['selected_answers'] ??
        telemetry['selected_option_id'];
    if (raw is Iterable) return raw.map((value) => value.toString()).toList();
    return raw == null ? const <String>[] : <String>[raw.toString()];
  }

  /// Applies either the V2 command protocol or the legacy C4 response through
  /// the shared reducer and records treatment fidelity for research analysis.
  ScaffoldApplicationReport? applyScaffoldResult<T>({
    required AdaptiveChoiceController<T> controller,
    required Map<String, dynamic>? result,
    Iterable<String> correctOptionIds = const <String>[],
  }) {
    final raw = result?['next_action'];
    if (raw is! Map) return null;
    final nextAction = Map<String, dynamic>.from(raw);
    final plan = ScaffoldPlan.fromNextAction(
      nextAction,
      correctOptionIds: correctOptionIds,
    );
    if (plan.scaffoldLevel > _highestScaffoldUsed) {
      _highestScaffoldUsed = plan.scaffoldLevel;
    }
    if (plan.isEmpty) return null;
    final report = controller.applyPlan(plan);
    _hintCount += countInstructionalChoiceHints(plan.commands);
    _scaffoldApplications.add(<String, dynamic>{
      ...report.toJson(),
      'command_types': plan.commands
          .map((command) => command.type.name)
          .toList(),
      'scaffold_level': plan.scaffoldLevel,
      'policy_version': plan.policyVersion,
      'reason_codes': plan.reasonCodes,
    });
    debugPrint('C4 scaffold applied: ${_scaffoldApplications.last}');
    return report;
  }

  /// Applies non-choice commands (sequence, sorting, listening) without
  /// coupling the policy service to an activity's widget tree.
  ScaffoldPlan? semanticScaffoldPlanFromResult({
    required Map<String, dynamic>? result,
    Iterable<String> correctOptionIds = const <String>[],
    int visibleOptionCount = 0,
  }) {
    final raw = result?['next_action'];
    if (raw is! Map) return null;
    final plan = ScaffoldPlan.fromNextAction(
      Map<String, dynamic>.from(raw),
      correctOptionIds: correctOptionIds,
    );
    if (plan.isEmpty) return null;
    if (plan.scaffoldLevel > _highestScaffoldUsed) {
      _highestScaffoldUsed = plan.scaffoldLevel;
    }
    _hintCount += plan.commands.length;
    _scaffoldApplications.add(<String, dynamic>{
      'action_id': plan.actionId,
      'command_types': plan.commands
          .map((command) => command.type.name)
          .toList(),
      'requested_option_ids': plan.commands
          .expand((command) => command.targetOptionIds)
          .toSet()
          .toList(),
      'applied_option_ids': plan.commands
          .expand((command) => command.targetOptionIds)
          .toSet()
          .toList(),
      'visible_before': visibleOptionCount,
      'visible_after': visibleOptionCount,
      'rejected_reasons': const <String>[],
      'scaffold_level': plan.scaffoldLevel,
      'policy_version': plan.policyVersion,
      'reason_codes': plan.reasonCodes,
    });
    return plan;
  }

  Future<ScaffoldPlan?> requestSemanticScaffold({
    required String itemId,
    required List<String> visibleOptionIds,
    required List<String> selectedOptionIds,
    required List<String> correctOptionIds,
    required List<String> supportedActions,
    required String errorType,
    List<String> struggledTargetUnits = const <String>[],
    List<String> incorrectOptionIds = const <String>[],
    List<String> selectedAnswerValues = const <String>[],
    int minimumVisibleOptions = 2,
  }) async {
    final result = await registerAdaptiveWrongAttempt(
      itemId: itemId,
      extraTelemetry: <String, dynamic>{
        'original_options_count': visibleOptionIds.length,
        'visible_option_ids': visibleOptionIds,
        'selected_option_ids': selectedOptionIds,
        'selected_answer_values': selectedAnswerValues,
        'correct_option_ids': correctOptionIds,
        'incorrect_option_ids': incorrectOptionIds,
        'supported_actions': supportedActions,
        'minimum_visible_options': minimumVisibleOptions,
        'error_type': errorType,
        'struggled_target_units': struggledTargetUnits,
      },
    );
    return semanticScaffoldPlanFromResult(
      result: result,
      correctOptionIds: correctOptionIds,
      visibleOptionCount: visibleOptionIds.length,
    );
  }

  /// Game activities should call this when the child replays an audio instruction.
  void logAudioReplay() {
    _audioReplayCount++;
    debugPrint('TELEMETRY: Audio replay recorded (total: $_audioReplayCount).');
  }

  /// Game activities should call this when the child corrects/revises a previous action.
  void logCorrection() {
    _correctionCount++;
    debugPrint('TELEMETRY: Correction recorded (total: $_correctionCount).');
  }

  /// Game activities should call this when a hint is provided to the child.
  void logHint() {
    _hintCount++;
    debugPrint('TELEMETRY: Hint recorded (total: $_hintCount).');
  }

  /// Log a child's attempt at answering the prompt.
  void logAttempt({
    required bool isCorrect,
    List<String> selectedAnswers = const [],
    String? errorType,
  }) {
    markAnswer();
    _attemptCount++;
    if (_firstAttemptCorrect == null) {
      _firstAttemptCorrect = isCorrect;
    }
    if (!isCorrect) {
      _incorrectAttemptCount++;
    }
    final supportActions = <String>{};
    for (final application in _scaffoldApplications) {
      final commands = application['command_types'];
      if (commands is Iterable) {
        supportActions.addAll(commands.map((value) => value.toString()));
      }
    }
    _attemptHistory.add(<String, dynamic>{
      'attempt_number': _attemptCount,
      'is_correct': isCorrect,
      'selected_answers': List<String>.from(selectedAnswers),
      'support_applied_before_response': _scaffoldApplications.isNotEmpty,
      'support_actions_before_response': supportActions.toList(),
    });
    _accumulatedAnswers.addAll(selectedAnswers);
    if (errorType != null && _firstErrorType == null) {
      _firstErrorType = errorType;
    }
  }

  /// Called by individual game activities when a round is completed.
  Future<int?> completeRound(
    int baseScore, {
    int? currentRoundIndex,
    String? itemId,
    bool? isCorrect,
    List<String> selectedAnswers = const <String>[],
    String? errorType,
    int correctionCount = 0,
    int hintCount = 0,
    bool attemptAlreadyLogged = false,
  }) async {
    await completeAdaptiveRound(
      baseScore,
      currentRoundIndex: currentRoundIndex,
      itemId: itemId,
      isCorrect: isCorrect,
      selectedAnswers: selectedAnswers,
      errorType: errorType,
      correctionCount: correctionCount,
      hintCount: hintCount,
      attemptAlreadyLogged: attemptAlreadyLogged,
    );
    return _currentRound - 1;
  }

  Future<Map<String, dynamic>?> completeAdaptiveRound(
    int baseScore, {
    int? currentRoundIndex,
    String? itemId,
    bool? isCorrect,
    List<String> selectedAnswers = const <String>[],
    String? errorType,
    int correctionCount = 0,
    int hintCount = 0,
    bool attemptAlreadyLogged = false,
  }) async {
    if (currentRoundIndex != null) {
      _currentRound = currentRoundIndex + 1;
    }
    if (_isSubmittingRound) return null;
    _isSubmittingRound = true;

    _roundStopwatch.stop();
    // Session record: response time ends at the final correct answer.
    final totalRoundLatency =
        _responseCompleteMs ?? _roundStopwatch.elapsedMilliseconds;
    // Component 4 receives exactly what it received before (full elapsed time).
    final c4TotalRoundLatency = _roundStopwatch.elapsedMilliseconds;

    final finalIsCorrect = isCorrect ?? baseScore > 0;
    if (!attemptAlreadyLogged) {
      logAttempt(
        isCorrect: finalIsCorrect,
        selectedAnswers: selectedAnswers,
        errorType: errorType,
      );
    }
    // Sent to Component 4 unchanged (first touch); the session record below
    // carries the first ANSWER time instead.
    int timeToFirstResponseMs = _firstTouchLatencyMs >= 0
        ? _firstTouchLatencyMs
        : 0;
    final firstAnswerMs = _firstResponseMs ?? timeToFirstResponseMs;
    int timeToCorrectMs = finalIsCorrect ? totalRoundLatency : 0;

    // Nuanced Scoring: Apply penalties for cognitive effort struggles
    int penalty = (_misclickCount * 5) + (_hesitationCount * 2);
    int finalRoundScore = (baseScore - penalty).clamp(0, 100);

    _totalScore += finalRoundScore;
    _roundsCompletedTotal++;

    // Resolve Canonical Metadata
    var rounds = widget.activityNode.rounds;
    Map<String, dynamic> roundData = _currentRound <= rounds.length
        ? rounds[_currentRound - 1]
        : {};

    final fallbackCanonical = CanonicalItemResolver.resolve(
      widget.activityNode,
      roundData,
      _currentRound - 1,
    );
    final payloadItemId = CanonicalItemResolver.normalizeItemId(
      itemId ?? fallbackCanonical.itemId,
    );
    final canonical = CanonicalItemResolver.resolveByItemId(
      widget.activityNode,
      payloadItemId,
      _currentRound - 1,
    );
    _activeItemId = canonical.itemId;
    final researchMeta = widget.activityNode.researchMetadata;
    if (finalIsCorrect && selectedAnswers.isEmpty) {
      for (final target in canonical.targets) {
        if (!_accumulatedAnswers.contains(target)) {
          _accumulatedAnswers.add(target);
        }
      }
      if (_attemptHistory.isNotEmpty &&
          (_attemptHistory.last['selected_answers'] as List).isEmpty) {
        _attemptHistory.last['selected_answers'] = List<String>.from(
          canonical.targets,
        );
      }
    }

    final sessionId = TelemetryService().sessionId;
    final completionEventId = '$sessionId:$payloadItemId:complete';

    // Build and log the rich telemetry event
    final event = TelemetryEvent(
      eventId: completionEventId,
      activityName: widget.activityNode.templateType,
      roundNumber: _currentRound,
      isCorrect: finalIsCorrect,
      score: finalRoundScore,
      timestamp: DateTime.now(),
      firstTouchLatencyMs: timeToFirstResponseMs,
      totalRoundLatencyMs: totalRoundLatency,
      misclickCount: _misclickCount,
      hesitationCount: _hesitationCount,
      audioReplayCount: _audioReplayCount,
      correctionCount: _correctionCount + correctionCount,
      hintCount: _hintCount + hintCount,
      isAbandoned: false,
      touchPath: List.unmodifiable(_currentTouchPath),
      attemptCount: _attemptCount,
      incorrectAttemptCount: _incorrectAttemptCount,
      firstAttemptCorrect: _firstAttemptCorrect,
      finalCorrect: finalIsCorrect,
      timeToFirstResponseMs: firstAnswerMs,
      timeToCorrectMs: timeToCorrectMs,
      strayDropCount: _strayDropCount,
      skillId: widget.activityNode.skillId,
      activityId: widget.activityNode.id,
      itemId: canonical.itemId,
      itemVersion: canonical.itemVersion,
      knowledgeComponentId: researchMeta?.knowledgeComponentId ?? 'KC_UNKNOWN',
      promptModality: researchMeta?.promptModality ?? 'visual',
      responseModality: researchMeta?.responseModality ?? 'tap',
      researchRole: researchMeta?.researchRole ?? 'primary',
      itemRole: canonical.itemRole,
      equivalentGroupId: canonical.equivalentGroupId,
      responseLoadRelation: canonical.responseLoadRelation,
      difficultyLabel: canonical.difficultyLabel,
      difficultyB: canonical.difficultyB,
      isAnchor: canonical.isAnchor,
      targets: canonical.targets,
      selectedAnswers: List.unmodifiable(_accumulatedAnswers),
      errorType: _firstErrorType ?? errorType ?? 'none',
      phase: 'COMPLETE',
      scaffoldLevelUsed: _highestScaffoldUsed,
      scaffoldApplications: List<Map<String, dynamic>>.unmodifiable(
        _scaffoldApplications,
      ),
      attemptHistory: List<Map<String, dynamic>>.unmodifiable(_attemptHistory),
    );

    TelemetryService().broadcastRoundComplete(
      finalRoundScore,
      totalRoundLatency,
    );
    if (!widget.activityNode.isParentPractice) {
      TelemetryService().logInteraction(event);
    }

    // --- NEW: Real-time Orchestrator Submission (C1-C4) ---
    final studentId = _studentId;
    final payload = {
      "schema_version": "2.0",
      "student_id": studentId,
      "session_id": sessionId,
      "event_id": completionEventId,
      "skill_id": widget.activityNode.skillId,
      "activity_id": widget.activityNode.id,
      "round_number": _currentRound,
      "item_id": payloadItemId,
      "knowledge_component_id": event.knowledgeComponentId,
      "difficulty_b": event.difficultyB,
      "is_anchor": event.isAnchor,
      "response": {"selected_character": "item", "is_correct": event.isCorrect},
      "telemetry": {
        "first_touch_latency_ms": event.firstTouchLatencyMs >= 0
            ? event.firstTouchLatencyMs
            : 0,
        "total_round_latency_ms": c4TotalRoundLatency,
        "hesitation_count": event.hesitationCount,
        "misclick_count": event.misclickCount,
        "audio_replay_count": event.audioReplayCount,
        "scaffold_level_used": _highestScaffoldUsed,
        "touch_stream": event.touchPath.map((p) => p.toJson()).toList(),
        "item_version": event.itemVersion,
        "prompt_modality": event.promptModality,
        "response_modality": event.responseModality,
        "research_role": event.researchRole,
        "difficulty_label": event.difficultyLabel,
        "error_type": event.errorType,
        "final_correct": event.finalCorrect,
        "time_to_first_response_ms": timeToFirstResponseMs,
        "time_to_correct_ms": finalIsCorrect ? c4TotalRoundLatency : 0,
        "score": event.score,
        "is_abandoned": event.isAbandoned,
        "attempt_count": event.attemptCount,
        "incorrect_attempt_count": event.incorrectAttemptCount,
        "first_attempt_correct": event.firstAttemptCorrect,
        "correction_count": event.correctionCount,
        "hint_count": event.hintCount,
        "item_role": event.itemRole,
        "equivalent_group_id": event.equivalentGroupId,
        "response_load_relation": event.responseLoadRelation,
        "target_ids": event.targets,
        "selected_answers": event.selectedAnswers,
        "scaffold_applications": List<Map<String, dynamic>>.from(
          _scaffoldApplications,
        ),
        "attempt_history": List<Map<String, dynamic>>.from(_attemptHistory),
      },
    };

    // Await response
    final result = widget.activityNode.isParentPractice || studentId == null
        ? null
        : await StudentService().submitInteraction(payload);
    if (widget.activityNode.isParentPractice) {
      debugPrint(
        'PARENT_PRACTICE: completion kept outside Component 4 mastery and progression.',
      );
    } else if (studentId == null) {
      debugPrint('C4 submission skipped: no authenticated student identifier.');
    }

    final rawNextAction = result?['next_action'];
    if (rawNextAction is Map) {
      final rawReasons = rawNextAction['reason_codes'];
      final reasons = rawReasons is Iterable
          ? rawReasons.map((reason) => reason.toString()).toSet()
          : const <String>{};
      if (reasons.contains('BREAK_RECOMMENDED_AFTER_ACTIVITY')) {
        _breakRecommendedAfterActivity = true;
      }
    }

    _applyAdaptiveNextAction(result, itemId: payloadItemId);

    if (widget.activityNode.isParentPractice) {
      if (_currentRound >= 1 &&
          _currentRound <= widget.activityNode.rounds.length) {
        // Store the zero-based index of the next unfinished practice task.
        await ProgressService().saveActivityState(
          widget.activityNode.skillId,
          widget.activityNode.id,
          _currentRound - 1,
        );
      } else {
        // Finishing the final task removes the resume prompt.
        await ProgressService().clearActivityState(
          widget.activityNode.skillId,
          widget.activityNode.id,
        );
      }
    }

    if (finalRoundScore > 0) {
      final logItemId = payloadItemId;
      debugPrint('\n===== ROUND COMPLETE =====');
      debugPrint('item=$itemId');
      // If it's a correct answer, attempts = misclicks + 1 (the final correct tap)
      debugPrint('attempts=${_misclickCount + 1}');
      debugPrint('final_correct=true');
      debugPrint('misclick_count=$_misclickCount');
      debugPrint('sending_to_C4=true');
      debugPrint('==========================\n');
    }

    debugPrint(
      'TELEMETRY: Round $_currentRound | '
      'Correct: ${finalRoundScore > 0} | '
      'Score: $finalRoundScore | '
      'First-Touch: ${event.firstTouchLatencyMs}ms | '
      'Total: ${totalRoundLatency}ms | '
      'Misclicks: $_misclickCount | '
      'Hesitations: $_hesitationCount | '
      'Audio Replays: $_audioReplayCount | '
      'Touch points: ${_currentTouchPath.length}',
    );

    // Forward to game loop
    widget.onRoundComplete(finalRoundScore);

    // Reset for next round
    // _currentRound is updated in _applyAdaptiveNextAction
    _currentTouchPath.clear();
    _firstTouchLatencyMs = -1;
    _firstTouchRecorded = false;
    _misclickCount = 0;
    _hesitationCount = 0;
    _audioReplayCount = 0;
    _highestScaffoldUsed = 0;
    _attemptCount = 0;
    _incorrectAttemptCount = 0;
    _firstAttemptCorrect = null;
    _accumulatedAnswers.clear();
    _attemptHistory.clear();
    _firstErrorType = null;
    _correctionCount = 0;
    _hintCount = 0;
    _scaffoldApplications.clear();
    _responseCompleteMs = null;
    _firstResponseMs = null;
    _strayDropCount = 0;
    _roundStopwatch.reset();
    _roundStopwatch.start();
    _hesitationStopwatch.reset();
    _hesitationStopwatch.start();

    TelemetryService().broadcastRoundStart(
      widget.activityNode.templateType,
      _currentRound,
      widget.activityNode.telemetryTags,
    );

    _isSubmittingRound = false;
    return result;
  }

  @visibleForTesting
  void applyAdaptiveNextAction(
    Map<String, dynamic>? result, {
    String? itemId,
  }) => _applyAdaptiveNextAction(result, itemId: itemId);

  void _applyAdaptiveNextAction(
    Map<String, dynamic>? result, {
    String? itemId,
  }) {
    bool fallback = true;
    try {
      if (result != null && result.containsKey('next_action')) {
        final nextAction = result['next_action'] as Map<String, dynamic>?;
        if (nextAction != null) {
          final decision = nextAction['decision']?.toString();
          final nextActivity = nextAction['next_activity']?.toString();
          final nextItem = nextAction['next_item']?.toString();

          final completionResult =
              result['response_quality'] ??
              (_misclickCount == 0 ? "CLEAN_SUCCESS" : "STRUGGLED_SUCCESS");
          debugPrint('\n===== C4 FRONTEND ADAPTATION =====');
          debugPrint('COMPLETED_ITEM=$itemId');
          debugPrint('COMPLETION_RESULT=$completionResult');
          debugPrint('NEXT_DECISION=${nextAction["decision"]}');
          debugPrint('SELECTED_NEXT_ITEM=$nextItem');

          if (decision == 'CURRICULUM_COMPLETE' ||
              decision == 'ACTIVITY_COMPLETE') {
            debugPrint('\nAction:\nC4_ACTIVITY_OR_CURRICULUM_COMPLETE');
            _activityCompleted = true;
            // Do NOT pop here. Let the game handle showing the completion UI
            return;
          }

          if (nextItem != null && nextActivity != null) {
            // Parse canonical S(\d+)A(\d+)R(\d+) and optional (V\d+)
            final normalizedNextItem = CanonicalItemResolver.normalizeItemId(
              nextItem,
            );
            _activeItemId = normalizedNextItem;
            final regex = RegExp(
              r'^S(\d+)A(\d+)R(\d+)(V\d+)?$',
              caseSensitive: false,
            );
            final match = regex.firstMatch(normalizedNextItem);

            if (match != null) {
              final pSkill = int.tryParse(match.group(1) ?? '');
              final pAct = int.tryParse(match.group(2) ?? '');
              final pRound = int.tryParse(match.group(3) ?? '');

              debugPrint(
                '\nParsed:\nskill=$pSkill\nactivity=$pAct\nround=$pRound',
              );

              // Determine current canonical activity
              String currentCanonical = "";
              final sMatch = RegExp(
                r'skill_(\d+)',
              ).firstMatch(widget.activityNode.skillId ?? '');
              final aMatch = RegExp(
                r'act_(\d+)',
              ).firstMatch(widget.activityNode.id);
              if (sMatch != null && aMatch != null) {
                currentCanonical = "${sMatch.group(1)}.${aMatch.group(1)}";
              }

              if (currentCanonical == nextActivity) {
                if (pRound != null) {
                  int nextIndex = pRound - 1;
                  if (nextIndex >= 0 &&
                      nextIndex < widget.activityNode.rounds.length) {
                    debugPrint(
                      '\nAction:\nADAPTIVE SAME-ACTIVITY JUMP\n\nFlutter next round index:\n$nextIndex',
                    );
                    _currentRound = pRound;
                    fallback = false;
                  } else {
                    debugPrint('\nAction:\nC4_ITEM_OUT_OF_RANGE');
                  }
                }
              } else {
                debugPrint('\nAction:\nNAVIGATING TO C4 ACTIVITY');
                _navigateToC4Activity(nextActivity, pRound);
              }
            } else {
              debugPrint('\nAction:\nC4_ITEM_PARSE_FAILED');
            }
          } else {
            debugPrint('\nAction:\nC4_RESPONSE_MISSING_FALLBACK');
          }
          debugPrint('==================================\n');
        } else {
          debugPrint('C4_RESPONSE_MISSING_FALLBACK (null next_action)');
        }
      } else {
        debugPrint(
          'BACKEND_ERROR_SEQUENTIAL_FALLBACK (no result or missing next_action)',
        );
      }
    } catch (e) {
      debugPrint('Error parsing adaptive result: $e');
    }

    if (fallback) {
      _currentRound++;
      if (_currentRound >= 1 &&
          _currentRound <= widget.activityNode.rounds.length) {
        _activeItemId = CanonicalItemResolver.resolve(
          widget.activityNode,
          widget.activityNode.rounds[_currentRound - 1],
          _currentRound - 1,
        ).itemId;
      }
    }
  }

  /// Called after all rounds are completed to show the completion screen.
  void completeActivity(BuildContext context) {
    int finalScore = 100; // Always award 100% for completing the activity
    final navigator = Navigator.of(context);
    final activityRoute = ModalRoute.of(context);
    var returnedDirectlyToMap = false;

    navigator
        .push(
          MaterialPageRoute(
            builder: (context) => ActivityCompleteScreen(
              activityNode: widget.activityNode,
              skillId: widget.activityNode.skillId,
              score: finalScore,
              isRevisiting: false,
              recommendBreak: _breakRecommendedAfterActivity,
              onRetake: () {
                Navigator.pop(context, 'retake');
              },
              onContinue: () {
                // Remove the completed game underneath this screen first. The
                // completion screen then closes directly onto the map, preventing
                // the old game (especially Activity 4's train) from flashing for
                // one reverse-route transition.
                returnedDirectlyToMap = true;
                if (activityRoute != null && activityRoute.isActive) {
                  navigator.removeRoute(activityRoute, finalScore);
                }
                navigator.pop(finalScore);
              },
            ),
          ),
        )
        .then((value) {
          if (returnedDirectlyToMap) return;
          if (mounted) {
            if (value == 'retake') {
              // Return ownership to the level map. It closes the completed
              // telemetry session before launching the retake as a new session.
              // Replacing this route directly used to detach the retake from the
              // level-map future, causing a later abandonment to be discarded.
              Navigator.pop(context, 'retake');
            } else {
              Navigator.pop(context, value ?? finalScore);
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _logAbandonment();
      },
      child: Listener(
        onPointerDown: (e) => _recordTouch(e, screenSize),
        onPointerMove: (e) => _recordTouch(e, screenSize),
        onPointerUp: (e) => _recordTouch(e, screenSize),
        child: widget.child,
      ),
    );
  }

  Future<void> _navigateToC4Activity(String nextActivity, int? pRound) async {
    final sMatch = RegExp(r'^(\d+)\.(\d+)$').firstMatch(nextActivity);
    if (sMatch == null) {
      debugPrint('\nAction:\nC4_NEXT_ACTIVITY_UNAVAILABLE (parse failed)');
      return;
    }

    final sNum = sMatch.group(1);
    final aNum = sMatch.group(2);
    final skillId = 'skill_$sNum';
    final activityId = 'act_$aNum';
    final targetRoundIndex = (pRound ?? 1) - 1;

    debugPrint('\n===== C4 ACTIVITY PROGRESSION =====');
    debugPrint(
      'Destination:\nskill=$skillId\nactivity=$activityId\nround=${targetRoundIndex + 1}',
    );

    try {
      final skillDetail = await SkillDetail.load('$skillId.json');
      ActivityNode? targetNode;
      for (var node in skillDetail.activities) {
        if (node.id == activityId) {
          targetNode = node;
          break;
        }
      }

      if (targetNode != null) {
        debugPrint(
          '\nActivity node:\nFOUND\n\nAction:\nNAVIGATING TO C4 ACTIVITY',
        );
        debugPrint('===================================\n');

        TelemetryService().startActivity(targetNode.title);
        await ProgressService().saveActivityState(
          skillId,
          activityId,
          targetRoundIndex,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameFactory.buildGame(
                targetNode!,
                studentData: widget.studentData,
              ),
            ),
          );
        }
      } else {
        debugPrint('\nAction:\nC4_NEXT_ACTIVITY_UNAVAILABLE (Not found)');
      }
    } catch (e) {
      debugPrint('\nAction:\nC4_NEXT_ACTIVITY_UNAVAILABLE ($e)');
    }
  }
}
