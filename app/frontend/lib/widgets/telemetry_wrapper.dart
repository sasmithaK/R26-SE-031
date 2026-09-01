import 'package:flutter/material.dart';
import '../services/telemetry_service.dart';
import '../services/telemetry/plugins/voice_analysis_plugin.dart';
import '../services/telemetry/plugins/eye_tracking_plugin.dart';
import '../models/curriculum_models.dart';
import '../screens/activity_complete_screen.dart';
import '../screens/games/game_factory.dart';
import '../services/tts_service.dart';
import '../services/student_service.dart';

/// A wrapper widget that tracks all touch events, latency, and coordinates
/// before they reach the underlying game template.
///
/// Enhanced metrics captured per round:
///  - [firstTouchLatencyMs] — time from round start to first tap
///  - [totalRoundLatencyMs] — full time from round start to completion
///  - [misclickCount] — taps outside target areas (game must call [recordMisclick])
///  - [hesitationCount] — pauses > 2s without any touch
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
  int _firstTouchLatencyMs = -1;    // -1 = no touch received yet this round
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
  String? _firstErrorType;

  // ---- Session accumulators ----
  int _totalScore = 0;
  int _roundsCompletedTotal = 0;
  int _currentRound = 1;

  // ---- Hesitation timer ----
  static const int _hesitationThresholdMs = 2000;

  @override
  void initState() {
    super.initState();
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
    if (_roundStopwatch.isRunning && _roundsCompletedTotal < widget.activityNode.rounds.length) {
      // The wrapper was disposed before the game finished natively -> Abandonment
      _logAbandonment();
    }
    _roundStopwatch.stop();
    _hesitationStopwatch.stop();
    
    // Stop any ongoing TTS audio when navigating away from the activity
    TtsService().stop();
    
    super.dispose();
  }

  void _logAbandonment() {
    _roundStopwatch.stop();
    final totalRoundLatency = _roundStopwatch.elapsedMilliseconds;
    
    final event = TelemetryEvent(
      activityName: widget.activityNode.templateType,
      roundNumber: _currentRound,
      isCorrect: false,
      score: 0,
      timestamp: DateTime.now(),
      firstTouchLatencyMs: _firstTouchLatencyMs < 0 ? 0 : _firstTouchLatencyMs,
      totalRoundLatencyMs: totalRoundLatency,
      misclickCount: _misclickCount,
      hesitationCount: _hesitationCount,
      audioReplayCount: _audioReplayCount,
      isAbandoned: true, // FLAG SET!
      touchPath: List.unmodifiable(_currentTouchPath),
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

  /// Called by the transparent Listener widget on every pointer event.
  void _recordTouch(PointerEvent details, Size screenSize) {
    // Check for hesitation since last touch
    if (_hesitationStopwatch.elapsedMilliseconds > _hesitationThresholdMs) {
      _hesitationCount++;
      debugPrint('TELEMETRY: Hesitation detected (${_hesitationStopwatch.elapsedMilliseconds} ms).');
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
    if (details is PointerDownEvent) type = 'down';
    else if (details is PointerUpEvent) type = 'up';

    // Record normalized touch point
    final xRatio = screenSize.width > 0
        ? (details.position.dx / screenSize.width).clamp(0.0, 1.0)
        : 0.0;
    final yRatio = screenSize.height > 0
        ? (details.position.dy / screenSize.height).clamp(0.0, 1.0)
        : 0.0;

    _currentTouchPath.add(TouchPoint(
      xRatio: double.parse(xRatio.toStringAsFixed(3)),
      yRatio: double.parse(yRatio.toStringAsFixed(3)),
      timestampMs: _roundStopwatch.elapsedMilliseconds,
      type: type,
    ));

    TelemetryService().broadcastPointerEvent(details);
  }

  /// Game activities should call this when the child taps a non-target area.
  void recordMisclick() {
    _misclickCount++;
    debugPrint('TELEMETRY: Misclick recorded (total: $_misclickCount).');
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
    _attemptCount++;
    if (_firstAttemptCorrect == null) {
      _firstAttemptCorrect = isCorrect;
    }
    if (!isCorrect) {
      _incorrectAttemptCount++;
    }
    _accumulatedAnswers.addAll(selectedAnswers);
    if (errorType != null && _firstErrorType == null) {
      _firstErrorType = errorType;
    }
  }

  /// Called by individual game activities when a round is completed.
  void completeRound(int baseScore, {
    String errorType = 'unknown_error',
    List<String> selectedAnswers = const [],
    int correctionCount = 0,
    int hintCount = 0,
  }) {
    bool isCorrect = baseScore > 0;
    
    // Automatically log this attempt if none was logged manually, or include the final correct attempt
    logAttempt(isCorrect: isCorrect, selectedAnswers: selectedAnswers, errorType: errorType);

    _roundStopwatch.stop();
    final totalRoundLatency = _roundStopwatch.elapsedMilliseconds;
    
    int timeToFirstResponseMs = _firstTouchLatencyMs >= 0 ? _firstTouchLatencyMs : 0;
    int timeToCorrectMs = isCorrect ? totalRoundLatency : 0;

    // Nuanced Scoring: Apply penalties for cognitive effort struggles
    int penalty = (_misclickCount * 5) + (_hesitationCount * 2);
    int finalRoundScore = (baseScore - penalty).clamp(0, 100);

    _totalScore += finalRoundScore;
    _roundsCompletedTotal++;

    // Resolve Canonical Metadata
    var rounds = widget.activityNode.rounds;
    Map<String, dynamic> roundData = _currentRound <= rounds.length ? rounds[_currentRound - 1] : {};
    
    final canonical = CanonicalItemResolver.resolve(widget.activityNode, roundData, _currentRound - 1);
    final researchMeta = widget.activityNode.researchMetadata;

    // Build and log the rich telemetry event
    final event = TelemetryEvent(
      activityName: widget.activityNode.templateType,
      roundNumber: _currentRound,
      isCorrect: isCorrect,
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
      finalCorrect: isCorrect,
      timeToFirstResponseMs: timeToFirstResponseMs,
      timeToCorrectMs: timeToCorrectMs,
      skillId: widget.activityNode.skillId,
      activityId: widget.activityNode.id,
      itemId: canonical.itemId,
      itemVersion: canonical.itemVersion,
      knowledgeComponentId: researchMeta?.knowledgeComponentId ?? 'KC_UNKNOWN',
      promptModality: researchMeta?.promptModality ?? 'visual',
      responseModality: researchMeta?.responseModality ?? 'tap',
      researchRole: researchMeta?.researchRole ?? 'primary',
      difficultyLabel: canonical.difficultyLabel,
      difficultyB: canonical.difficultyB,
      isAnchor: canonical.isAnchor,
      targets: canonical.targets,
      selectedAnswers: List.unmodifiable(_accumulatedAnswers),
      errorType: _firstErrorType ?? errorType,
    );

    TelemetryService().broadcastRoundComplete(finalRoundScore, totalRoundLatency);
    TelemetryService().logInteraction(event);

    // --- NEW: Real-time Orchestrator Submission (C1-C4) ---
    final studentId = widget.studentData?['student_id'] ?? widget.studentData?['id'] ?? widget.studentData?['_id'];
    if (studentId == null || studentId.toString().isEmpty) {
      debugPrint('TELEMETRY: Skipped real-time submission because student_id is unavailable.');
    } else {
      final sessionId = TelemetryService().sessionId;

    final payload = {
      "schema_version": "2.0",
      "student_id": studentId,
      "session_id": sessionId,
      "activity_id": widget.activityNode.id,
      "item_id": canonical.itemId,
      "knowledge_component_id": event.knowledgeComponentId,
      "event_id": '$sessionId:${TelemetryService().sessionEvents.length - 1}',
      "difficulty_b": canonical.difficultyB,
      "is_anchor": canonical.isAnchor,
      "first_attempt_correct": event.firstAttemptCorrect,
      "attempt_count": event.attemptCount,
      "incorrect_attempt_count": event.incorrectAttemptCount,
      "first_error_type": event.errorType,
      "hint_count": event.hintCount,
      "correction_count": event.correctionCount,
      "response": {
        "selected_character": "item", 
        "is_correct": event.firstAttemptCorrect ?? event.isCorrect
      },
      "telemetry": {
        "first_touch_latency_ms": event.firstTouchLatencyMs >= 0 ? event.firstTouchLatencyMs : 0,
        "total_round_latency_ms": event.totalRoundLatencyMs,
        "hesitation_count": event.hesitationCount,
        "misclick_count": event.misclickCount,
        "touch_stream": event.touchPath.map((p) => p.toJson()).toList()
      }
    };
    
    // Fire and forget
      StudentService().submitInteraction(payload).then((result) {
        if (result != null) {
          debugPrint('TELEMETRY: Received C1-C4 result: $result');
        }
      });
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
    _currentRound++;
    _currentTouchPath.clear();
    _firstTouchLatencyMs = -1;
    _firstTouchRecorded = false;
    _misclickCount = 0;
    _hesitationCount = 0;
    _audioReplayCount = 0;
    _correctionCount = 0;
    _hintCount = 0;
    _attemptCount = 0;
    _incorrectAttemptCount = 0;
    _firstAttemptCorrect = null;
    _accumulatedAnswers.clear();
    _firstErrorType = null;
    _roundStopwatch.reset();
    _roundStopwatch.start();
    _hesitationStopwatch.reset();
    _hesitationStopwatch.start();

    TelemetryService().broadcastRoundStart(
      widget.activityNode.templateType,
      _currentRound,
      widget.activityNode.telemetryTags,
    );
  }

  /// Called after all rounds are completed to show the completion screen.
  void completeActivity(BuildContext context) {
    int finalScore = 100; // Always award 100% for completing the activity

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityCompleteScreen(
          activityNode: widget.activityNode,
          skillId: widget.activityNode.id,
          score: finalScore,
          isRevisiting: false,
          onRetake: () {
            Navigator.pop(context, 'retake');
          },
          onContinue: () {
            Navigator.pop(context, finalScore);
          },
        ),
      ),
    ).then((value) {
      if (mounted) {
        if (value == 'retake') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameFactory.buildGame(widget.activityNode, studentData: widget.studentData),
            ),
          );
        } else {
          Navigator.pop(context, value ?? finalScore);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Listener(
      onPointerDown: (e) => _recordTouch(e, screenSize),
      onPointerMove: (e) => _recordTouch(e, screenSize),
      onPointerUp: (e) => _recordTouch(e, screenSize),
      child: widget.child,
    );
  }
}
