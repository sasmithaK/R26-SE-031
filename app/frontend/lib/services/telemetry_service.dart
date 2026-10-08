import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // For PointerEvent
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'telemetry/telemetry_plugin.dart';
import 'student_service.dart';

// ---------------------------------------------------------------------------
// Rich Touch Point — normalized screen-relative coordinates with timestamp
// ---------------------------------------------------------------------------
class TouchPoint {
  final double xRatio;
  final double yRatio;
  final int timestampMs;
  final String type;

  const TouchPoint({
    required this.xRatio,
    required this.yRatio,
    required this.timestampMs,
    this.type = 'down',
  });

  Map<String, dynamic> toJson() => {
    'x_ratio': xRatio,
    'y_ratio': yRatio,
    'timestamp_ms': timestampMs,
    'type': type,
  };
}

@visibleForTesting
List<Map<String, dynamic>> serializeTelemetryEvents(
  Iterable<TelemetryEvent> events,
  String sessionId,
) {
  return events.toList().asMap().entries.map((entry) {
    final eventJson = entry.value.toJson();
    eventJson['event_id'] ??= '$sessionId:${entry.key}';
    return eventJson;
  }).toList();
}

String _sessionDimension(List<Map<String, dynamic>> events, String field) {
  final values = events
      .map((event) => event[field]?.toString().trim())
      .whereType<String>()
      .where((value) => value.isNotEmpty && value != 'unknown')
      .toSet();
  if (values.isEmpty) return 'unknown';
  return values.length == 1 ? values.single : 'mixed';
}

@visibleForTesting
Map<String, dynamic> buildTelemetrySessionPayload({
  required String studentId,
  required String sessionId,
  required int durationSeconds,
  required DateTime startedAt,
  required DateTime completedAt,
  required List<Map<String, dynamic>> events,
  required Map<String, dynamic> deviceMetrics,
}) {
  return <String, dynamic>{
    'student_id': studentId,
    'session_id': sessionId,
    'skill_id': _sessionDimension(events, 'skill_id'),
    'activity_id': _sessionDimension(events, 'activity_id'),
    'started_at': startedAt.toUtc().toIso8601String(),
    'completed_at': completedAt.toUtc().toIso8601String(),
    'session_duration_seconds': durationSeconds,
    'events': events,
    'device_metrics': deviceMetrics,
  };
}

// ---------------------------------------------------------------------------
// TelemetryEvent — enriched with dyslexia/motor diagnostic metrics
// ---------------------------------------------------------------------------
class TelemetryEvent {
  /// Stable ID shared by real-time and end-of-session persistence.
  final String? eventId;
  final String activityName;
  final int roundNumber;
  final bool isCorrect;
  final int score;
  final DateTime timestamp;

  /// Time from round display to the FIRST screen touch (cognitive processing speed)
  final int firstTouchLatencyMs;

  /// Total time taken for the full round
  final int totalRoundLatencyMs;

  /// Number of taps outside interactive target boundaries (motor precision)
  final int misclickCount;

  /// Number of >8s pauses with no screen touch (Grade-1 hesitation signal)
  final int hesitationCount;

  /// Number of times the student replayed the audio instruction
  final int audioReplayCount;

  /// Number of self-corrections made during the round
  final int correctionCount;

  /// Number of hints requested or given during the round
  final int hintCount;

  /// True if the user exited the activity before completing all rounds
  final bool isAbandoned;

  /// Normalized (x%, y%) touch path captured during the round
  final List<TouchPoint> touchPath;

  // --- Attempt & Accuracy Tracking ---
  final int attemptCount;
  final int incorrectAttemptCount;
  final bool? firstAttemptCorrect;
  final bool finalCorrect;
  final int timeToFirstResponseMs;
  final int timeToCorrectMs;

  // --- Research & Canonical Item Metadata ---
  final String skillId;
  final String activityId;
  final String itemId;
  final int itemVersion;
  final String knowledgeComponentId;
  final String promptModality;
  final String responseModality;
  final String researchRole;
  final String itemRole;
  final String? equivalentGroupId;
  final String responseLoadRelation;
  final String difficultyLabel;
  final double difficultyB;
  final bool isAnchor;
  final List<String> targets;
  final List<String> selectedAnswers;
  final String errorType;
  final String phase;
  final int scaffoldLevelUsed;
  final List<Map<String, dynamic>> scaffoldApplications;

  const TelemetryEvent({
    this.eventId,
    required this.activityName,
    required this.roundNumber,
    required this.isCorrect,
    required this.score,
    required this.timestamp,
    required this.firstTouchLatencyMs,
    required this.totalRoundLatencyMs,
    required this.misclickCount,
    required this.hesitationCount,
    required this.audioReplayCount,
    required this.isAbandoned,
    required this.touchPath,
    this.attemptCount = 1,
    this.incorrectAttemptCount = 0,
    this.firstAttemptCorrect,
    this.finalCorrect = false,
    this.timeToFirstResponseMs = 0,
    this.timeToCorrectMs = 0,
    this.correctionCount = 0,
    this.hintCount = 0,
    this.skillId = '',
    this.activityId = '',
    this.itemId = 'unknown',
    this.itemVersion = 1,
    this.knowledgeComponentId = 'KC_UNKNOWN',
    this.promptModality = 'visual',
    this.responseModality = 'tap',
    this.researchRole = 'primary',
    this.itemRole = 'CORE',
    this.equivalentGroupId,
    this.responseLoadRelation = 'core',
    this.difficultyLabel = 'medium',
    this.difficultyB = 0.0,
    this.isAnchor = false,
    this.targets = const [],
    this.selectedAnswers = const [],
    this.errorType = 'unknown_error',
    this.phase = 'COMPLETE',
    this.scaffoldLevelUsed = 0,
    this.scaffoldApplications = const <Map<String, dynamic>>[],
  });

  Map<String, dynamic> toJson() => {
    if (eventId != null) 'event_id': eventId,
    'activity_name': activityName,
    'round_number': roundNumber,
    'is_correct': isCorrect,
    'score': score,
    // Research timestamps must be unambiguous across devices and time zones.
    'timestamp': timestamp.toUtc().toIso8601String(),
    'first_touch_latency_ms': firstTouchLatencyMs,
    'total_round_latency_ms': totalRoundLatencyMs,
    'misclick_count': misclickCount,
    'hesitation_count': hesitationCount,
    'audio_replay_count': audioReplayCount,
    'correction_count': correctionCount,
    'hint_count': hintCount,
    'is_abandoned': isAbandoned,
    'touch_path': touchPath.map((p) => p.toJson()).toList(),
    'attempt_count': attemptCount,
    'incorrect_attempt_count': incorrectAttemptCount,
    'first_attempt_correct': firstAttemptCorrect,
    'final_correct': finalCorrect,
    'time_to_first_response_ms': timeToFirstResponseMs,
    'time_to_correct_ms': timeToCorrectMs,
    'skill_id': skillId,
    'activity_id': activityId,
    'item_id': itemId,
    'item_version': itemVersion,
    'knowledge_component_id': knowledgeComponentId,
    'prompt_modality': promptModality,
    'response_modality': responseModality,
    'research_role': researchRole,
    'item_role': itemRole,
    'equivalent_group_id': equivalentGroupId,
    'response_load_relation': responseLoadRelation,
    'difficulty_label': difficultyLabel,
    'difficulty_b': difficultyB,
    'is_anchor': isAnchor,
    'targets': targets,
    'selected_answers': selectedAnswers,
    'error_type': errorType,
    'phase': phase,
    'scaffold_level_used': scaffoldLevelUsed,
    'scaffold_applications': scaffoldApplications,
  };
}

// ---------------------------------------------------------------------------
// TelemetryService — singleton managing session events & cloud submission
// ---------------------------------------------------------------------------
class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  static const String _offlineQueueKey = 'pending_telemetry_queue';

  final List<TelemetryEvent> _sessionEvents = [];
  DateTime? _sessionStartTime;
  String? _sessionId;
  bool _submitOnActivityComplete = false;
  Future<void>? _submissionInFlight;
  String get sessionId => _sessionId ??= const Uuid().v4();
  bool get submitOnActivityComplete => _submitOnActivityComplete;

  DateTime? get sessionStartTime => _sessionStartTime;

  /// Expose the session events for debugging and the temporary dashboard
  List<TelemetryEvent> get sessionEvents => List.unmodifiable(_sessionEvents);

  // Plugin Management
  final List<ITelemetryPlugin> _plugins = [];

  bool isPluginRegistered(String pluginId) {
    return _plugins.any((p) => p.pluginId == pluginId);
  }

  void registerPlugin(ITelemetryPlugin plugin) {
    if (isPluginRegistered(plugin.pluginId)) return;
    _plugins.add(plugin);
    plugin.initialize();
    debugPrint('Telemetry: Registered plugin ${plugin.pluginId}');
  }

  void startSession({bool submitOnActivityComplete = false}) {
    _sessionStartTime = DateTime.now();
    _sessionId = const Uuid().v4();
    _submitOnActivityComplete = submitOnActivityComplete;
    _sessionEvents.clear();
    debugPrint('Telemetry: Session started');
  }

  /// Mark the start of a specific named activity within a session.
  /// Called by [SessionContainerScreen] before each activity is launched.
  void startActivity(String activityName) {
    debugPrint('Telemetry: Activity started — $activityName');
  }

  void broadcastRoundStart(
    String activityName,
    int roundNumber,
    List<String> tags,
  ) {
    for (var plugin in _plugins) {
      plugin.onRoundStart(activityName, roundNumber, tags);
    }
  }

  void broadcastPointerEvent(PointerEvent event) {
    for (var plugin in _plugins) {
      plugin.onPointerEvent(event);
    }
  }

  void broadcastRoundComplete(int score, int latencyMs) {
    for (var plugin in _plugins) {
      plugin.onRoundComplete(score, latencyMs);
    }
  }

  /// Log a fully-enriched round interaction event.
  void logInteraction(TelemetryEvent event) {
    _sessionEvents.add(event);
    // Full touch/scaffold arrays are retained for submission. A compact log
    // avoids Flutter/IDE line truncation being mistaken for lost evidence.
    final logSummary = <String, dynamic>{
      'event_id': event.eventId,
      'item_id': event.itemId,
      'phase': event.phase,
      'is_correct': event.isCorrect,
      'first_attempt_correct': event.firstAttemptCorrect,
      'attempt_count': event.attemptCount,
      'scaffold_level_used': event.scaffoldLevelUsed,
      'target_count': event.targets.length,
      'selected_answer_count': event.selectedAnswers.length,
      'touch_point_count': event.touchPath.length,
    };
    debugPrint('Telemetry log: ${jsonEncode(logSummary)}');
  }

  /// Submit current session's telemetry to the backend.
  /// On network failure, payload is saved to an offline queue in SharedPreferences.
  Future<void> endSessionAndSubmit(String studentId) {
    if (_sessionEvents.isEmpty) {
      return _submissionInFlight ?? Future<void>.value();
    }

    final completedAt = DateTime.now();
    final startedAt = _sessionStartTime ?? completedAt;
    final totalDuration = _sessionStartTime != null
        ? completedAt.difference(_sessionStartTime!).inSeconds
        : 0;

    // Grab a local copy of events and clear immediately to avoid race conditions
    // with newly started sessions while this submits in the background.
    final sessionId = _sessionId ?? const Uuid().v4();
    final eventsToSubmit = serializeTelemetryEvents(_sessionEvents, sessionId);
    final sessionEventCount = _sessionEvents.length;
    _sessionEvents.clear();
    _submitOnActivityComplete = false;

    late final Future<void> trackedSubmission;
    trackedSubmission =
        _submitSessionSnapshot(
          studentId: studentId,
          sessionId: sessionId,
          totalDuration: totalDuration,
          startedAt: startedAt,
          completedAt: completedAt,
          eventsToSubmit: eventsToSubmit,
          sessionEventCount: sessionEventCount,
        ).whenComplete(() {
          if (identical(_submissionInFlight, trackedSubmission)) {
            _submissionInFlight = null;
          }
        });
    _submissionInFlight = trackedSubmission;
    return trackedSubmission;
  }

  Future<void> _submitSessionSnapshot({
    required String studentId,
    required String sessionId,
    required int totalDuration,
    required DateTime startedAt,
    required DateTime completedAt,
    required List<Map<String, dynamic>> eventsToSubmit,
    required int sessionEventCount,
  }) async {
    final payload = buildTelemetrySessionPayload(
      studentId: studentId,
      sessionId: sessionId,
      durationSeconds: totalDuration,
      startedAt: startedAt,
      completedAt: completedAt,
      events: eventsToSubmit,
      deviceMetrics: await _getDeviceMetrics(),
    );

    debugPrint('Telemetry: Submitting session ($sessionEventCount events)...');

    try {
      final error = await StudentService().submitTelemetry(payload);
      if (error != null) {
        debugPrint('Telemetry network error — queuing for later retry: $error');
        await _enqueueOffline(payload);
      } else {
        debugPrint('Telemetry submitted successfully.');
      }
    } catch (e) {
      debugPrint('Telemetry exception — queuing offline: $e');
      await _enqueueOffline(payload);
    }

    // Attempt to flush any previously queued offline payloads
    await flushOfflineQueue(studentId);
  }

  /// Save a failed submission payload into the local offline queue.
  Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_offlineQueueKey) ?? [];
      final studentId = payload['student_id']?.toString();
      final sessionId = payload['session_id']?.toString();
      final deduplicated = existing.where((raw) {
        try {
          final queued = jsonDecode(raw) as Map<String, dynamic>;
          return queued['student_id']?.toString() != studentId ||
              queued['session_id']?.toString() != sessionId;
        } catch (_) {
          return true;
        }
      }).toList();
      deduplicated.add(jsonEncode(payload));
      await prefs.setStringList(_offlineQueueKey, deduplicated);
      debugPrint(
        'Telemetry: Queued offline payload (queue size: ${deduplicated.length}).',
      );
    } catch (e) {
      debugPrint('Telemetry: Failed to save offline queue: $e');
    }
  }

  /// Attempt to flush all offline-queued telemetry payloads to the backend.
  Future<void> flushOfflineQueue(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_offlineQueueKey) ?? [];
      if (queue.isEmpty) return;

      debugPrint('Telemetry: Flushing ${queue.length} offline payload(s)...');
      final remaining = <String>[];

      for (var index = 0; index < queue.length; index++) {
        final raw = queue[index];
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        if (payload['student_id']?.toString() != studentId) {
          remaining.add(raw);
          continue;
        }
        final error = await StudentService().submitTelemetry(payload);
        if (error != null) {
          remaining.add(raw); // still offline — keep in queue
          if (error == 'Failed to connect to the server.') {
            // The endpoint is unavailable. Preserve the rest without issuing
            // scores of identical requests or blocking the child-facing UI.
            remaining.addAll(queue.skip(index + 1));
            break;
          }
        } else {
          debugPrint('Telemetry: Offline payload flushed successfully.');
        }
      }

      await prefs.setStringList(_offlineQueueKey, remaining);
    } catch (e) {
      debugPrint('Telemetry: Offline flush error: $e');
    }
  }

  /// Retrieve device metrics for spatial and acceleration normalization in the backend
  Future<Map<String, dynamic>> _getDeviceMetrics() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webBrowserInfo = await deviceInfo.webBrowserInfo;
        return {'os': 'web', 'model': webBrowserInfo.userAgent};
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'os': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'os': 'ios',
          'model': iosInfo.utsname.machine,
          'systemVersion': iosInfo.systemVersion,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      }
    } catch (e) {
      debugPrint('Failed to get device info: $e');
    }
    return {'os': 'unknown', 'model': 'unknown'};
  }
}
