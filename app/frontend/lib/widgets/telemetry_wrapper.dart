import 'dart:math';
import 'dart:async';
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
  bool _firstTouchRecorded = false;

  // ---- Session accumulators ----
  int _totalScore = 0;
  int _roundsCompletedTotal = 0;
  int _currentRound = 1;
  int _highestScaffoldUsed = 0;

  @visibleForTesting
  int get currentRound => _currentRound;
  
  @visibleForTesting
  set currentRound(int value) => _currentRound = value;

  // ---- Hesitation timer ----
  static const int _hesitationThresholdMs = 3000;

  // ---- State Blocking ----
  bool _isSubmittingRound = false;

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
      firstTouchLatencyMs: _firstTouchLatencyMs,
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
    if (_isSubmittingRound) return;
    
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

  /// Called by games when the child selects a wrong answer but hasn't failed the round yet.
  Future<int?> registerWrongAttempt({int? currentRoundIndex, int maxAttempts = 3}) async {
    final result = await registerAdaptiveWrongAttempt(currentRoundIndex: currentRoundIndex, maxAttempts: maxAttempts);
    if (result != null && result.containsKey('next_action')) {
      final nextAction = result['next_action'];
      if (nextAction['decision'] == 'TERMINATE') {
         return currentRoundIndex ?? _currentRound;
      }
    }
    return null; // Return null to indicate no forceful jump yet
  }

  Future<Map<String, dynamic>?> registerAdaptiveWrongAttempt({int? currentRoundIndex, int maxAttempts = 3, Map<String, dynamic>? extraTelemetry}) async {
    _misclickCount++;
    final itemId = "${widget.activityNode.id}_round${currentRoundIndex != null ? currentRoundIndex + 1 : _currentRound}";
    
    // Build attempt payload
    final studentId = widget.studentData?['id'] ?? widget.studentData?['_id'] ?? 'STU001';
    final sessionId = TelemetryService().sessionStartTime?.toIso8601String() ?? DateTime.now().toIso8601String();
    
    final payload = {
      "student_id": studentId,
      "session_id": sessionId,
      "skill_id": widget.activityNode.skillId,
      "activity_id": widget.activityNode.id,
      "round_number": _currentRound,
      "item_id": itemId,
      "phase": "ATTEMPT",
      "response": {
        "selected_character": "item", 
        "is_correct": false
      },
      "telemetry": {
        "first_touch_latency_ms": _firstTouchLatencyMs >= 0 ? _firstTouchLatencyMs : 0,
        "total_round_latency_ms": _roundStopwatch.elapsedMilliseconds,
        "hesitation_count": _hesitationCount,
        "misclick_count": _misclickCount,
        "audio_replay_count": _audioReplayCount,
        "scaffold_level_used": 0,
        "touch_stream": _currentTouchPath.map((p) => p.toJson()).toList(),
        if (extraTelemetry != null) ...extraTelemetry
      }
    };
    
    final result = await StudentService().submitInteraction(payload);
    
    if (result != null && result['next_action'] != null) {
      final level = result['next_action']['scaffold_level'];
      if (level is num && level.toInt() > _highestScaffoldUsed) {
        _highestScaffoldUsed = level.toInt();
      }
    }
    
    debugPrint('\n===== TASK ATTEMPT =====');
    debugPrint('item=$itemId');
    debugPrint('attempt=$_misclickCount');
    debugPrint('result=$result');
    debugPrint('======================\n');
    
    return result;
  }

  /// Game activities should call this when the child replays an audio instruction.
  void logAudioReplay() {
    _audioReplayCount++;
    debugPrint('TELEMETRY: Audio replay recorded (total: $_audioReplayCount).');
  }

  /// Called by individual game activities when a round is completed.
  Future<int?> completeRound(int baseScore, {int? currentRoundIndex}) async {
    await completeAdaptiveRound(baseScore, currentRoundIndex: currentRoundIndex);
    return _currentRound - 1;
  }

  Future<Map<String, dynamic>?> completeAdaptiveRound(int baseScore, {int? currentRoundIndex}) async {
    if (currentRoundIndex != null) {
      _currentRound = currentRoundIndex + 1;
    }
    if (_isSubmittingRound) return null;
    _isSubmittingRound = true;

    _roundStopwatch.stop();
    final totalRoundLatency = _roundStopwatch.elapsedMilliseconds;

    // Nuanced Scoring: Apply penalties for cognitive effort struggles
    int penalty = (_misclickCount * 5) + (_hesitationCount * 2);
    int finalRoundScore = (baseScore - penalty).clamp(0, 100);

    _totalScore += finalRoundScore;
    _roundsCompletedTotal++;

    // Build and log the rich telemetry event
    final event = TelemetryEvent(
      activityName: widget.activityNode.templateType,
      roundNumber: _currentRound,
      isCorrect: finalRoundScore > 0,
      score: finalRoundScore,
      timestamp: DateTime.now(),
      firstTouchLatencyMs: _firstTouchLatencyMs >= 0 ? _firstTouchLatencyMs : 0,
      totalRoundLatencyMs: totalRoundLatency,
      misclickCount: _misclickCount,
      hesitationCount: _hesitationCount,
      audioReplayCount: _audioReplayCount,
      isAbandoned: false,
      touchPath: List.unmodifiable(_currentTouchPath),
    );

    TelemetryService().broadcastRoundComplete(finalRoundScore, totalRoundLatency);
    TelemetryService().logInteraction(event);

    // --- NEW: Real-time Orchestrator Submission (C1-C4) ---
    final studentId = widget.studentData?['id'] ?? widget.studentData?['_id'] ?? 'STU001';
    final sessionId = TelemetryService().sessionStartTime?.toIso8601String() ?? DateTime.now().toIso8601String();

    final payload = {
      "student_id": studentId,
      "session_id": sessionId,
      "skill_id": widget.activityNode.skillId,
      "activity_id": widget.activityNode.id,
      "round_number": _currentRound,
      "item_id": "${widget.activityNode.id}_round$_currentRound",
      "response": {
        "selected_character": "item", 
        "is_correct": finalRoundScore > 0
      },
      "telemetry": {
        "first_touch_latency_ms": event.firstTouchLatencyMs >= 0 ? event.firstTouchLatencyMs : 0,
        "total_round_latency_ms": event.totalRoundLatencyMs,
        "hesitation_count": event.hesitationCount,
        "misclick_count": event.misclickCount,
        "audio_replay_count": event.audioReplayCount,
        "scaffold_level_used": _highestScaffoldUsed,
        "touch_stream": event.touchPath.map((p) => p.toJson()).toList()
      }
    };
    
    // Await response
    final result = await StudentService().submitInteraction(payload);
    
    _applyAdaptiveNextAction(result, itemId: "${widget.activityNode.id}_round$_currentRound");

    if (finalRoundScore > 0) {
      final itemId = "${widget.activityNode.id}_round$_currentRound";
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
  void applyAdaptiveNextAction(Map<String, dynamic>? result, {String? itemId}) => _applyAdaptiveNextAction(result, itemId: itemId);

  void _applyAdaptiveNextAction(Map<String, dynamic>? result, {String? itemId}) {
    if (widget.activityNode.skillId != 'skill_2') {
      debugPrint('[C4 ADAPTIVE GATE] skill=${widget.activityNode.skillId} adaptive=false reason=SKILL_2_ONLY_PILOT');
      return;
    }

    bool fallback = true;
    try {
      if (result != null && result.containsKey('next_action')) {
        final nextAction = result['next_action'] as Map<String, dynamic>?;
        if (nextAction != null) {
          final decision = nextAction['decision']?.toString();
          final nextActivity = nextAction['next_activity']?.toString();
          final nextItem = nextAction['next_item']?.toString();
          
          final completionResult = result['response_quality'] ?? (_misclickCount == 0 ? "CLEAN_SUCCESS" : "STRUGGLED_SUCCESS");
          debugPrint('\n===== C4 FRONTEND ADAPTATION =====');
          debugPrint('COMPLETED_ITEM=$itemId');
          debugPrint('COMPLETION_RESULT=$completionResult');
          debugPrint('NEXT_DECISION=${nextAction["decision"]}');
          debugPrint('SELECTED_NEXT_ITEM=$nextItem');

          if (decision == 'CURRICULUM_COMPLETE' || decision == 'ACTIVITY_COMPLETE') {
            debugPrint('\nAction:\nC4_ACTIVITY_OR_CURRICULUM_COMPLETE');
            // Do NOT pop here. Let the game handle showing the completion UI
            return;
          }

          if (nextItem != null && nextActivity != null) {
            // Parse canonical S(\d+)A(\d+)R(\d+) and optional (V\d+)
            final regex = RegExp(r'^S(\d+)A(\d+)R(\d+)(V\d+)?$', caseSensitive: false);
            final match = regex.firstMatch(nextItem);
            
            if (match != null) {
              final pSkill = int.tryParse(match.group(1) ?? '');
              final pAct = int.tryParse(match.group(2) ?? '');
              final pRound = int.tryParse(match.group(3) ?? '');
              
              debugPrint('\nParsed:\nskill=$pSkill\nactivity=$pAct\nround=$pRound');
              
              // Determine current canonical activity
              String currentCanonical = "";
              final sMatch = RegExp(r'skill_(\d+)').firstMatch(widget.activityNode.skillId ?? '');
              final aMatch = RegExp(r'act_(\d+)').firstMatch(widget.activityNode.id);
              if (sMatch != null && aMatch != null) {
                currentCanonical = "${sMatch.group(1)}.${aMatch.group(1)}";
              }

              if (currentCanonical == nextActivity) {
                if (pRound != null) {
                  int nextIndex = pRound - 1;
                  if (nextIndex >= 0 && nextIndex < widget.activityNode.rounds.length) {
                    debugPrint('\nAction:\nADAPTIVE SAME-ACTIVITY JUMP\n\nFlutter next round index:\n$nextIndex');
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
        debugPrint('BACKEND_ERROR_SEQUENTIAL_FALLBACK (no result or missing next_action)');
      }
    } catch (e) {
      debugPrint('Error parsing adaptive result: $e');
    }
    
    if (fallback) {
      _currentRound++;
    }
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
    debugPrint('Destination:\nskill=$skillId\nactivity=$activityId\nround=${targetRoundIndex + 1}');

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
        debugPrint('\nActivity node:\nFOUND\n\nAction:\nNAVIGATING TO C4 ACTIVITY');
        debugPrint('===================================\n');

        TelemetryService().startActivity(targetNode.title);
        await ProgressService().saveActivityState(skillId, activityId, targetRoundIndex);

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
