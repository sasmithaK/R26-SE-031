import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/telemetry.dart';
import '../services/api_config.dart';

class TelemetryCollector {
  final String studentId;
  final String taskId;
  final String sessionId;

  final List<TouchEvent> _touchEvents = [];
  int _startTime = 0;
  int _firstInteractionTime = 0;
  int _replayCount = 0;
  int _hintCount = 0;
  int _correctionCount = 0;
  int _totalInteractions = 0;

  TelemetryCollector({
    required this.studentId,
    required this.taskId,
    required this.sessionId,
  }) {
    _startTime = DateTime.now().millisecondsSinceEpoch;
  }

  void recordTouch(double x, double y, {double pressure = 0.5}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_firstInteractionTime == 0) {
      _firstInteractionTime = now;
    }
    _touchEvents.add(TouchEvent(
      x: x,
      y: y,
      pressure: pressure,
      timestampMs: now,
    ));
    _totalInteractions++;
  }

  void recordReplay() => _replayCount++;
  void recordHint() => _hintCount++;
  void recordCorrection() {
    _correctionCount++;
    _totalInteractions++;
  }

  TelemetryPayload finalize(String eventType) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final latency = _firstInteractionTime > 0 ? _firstInteractionTime - _startTime : 0;
    final hesitation = _totalInteractions > 0 ? now - _startTime : 0;

    return TelemetryPayload(
      studentId: studentId,
      taskId: taskId,
      sessionId: sessionId,
      timestampMs: now,
      touchEvents: _touchEvents,
      eventType: eventType,
      sessionLatencyMs: latency,
      hesitationMs: hesitation,
      correctionRate: _totalInteractions > 0 ? _correctionCount / _totalInteractions : 0.0,
      replayCount: _replayCount,
      hintRequestCount: _hintCount,
    );
  }

  /// Send telemetry payload to C1
  Future<void> send(TelemetryPayload payload) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.monitoringUrl}/telemetry'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': payload.studentId,
              'session_id': payload.sessionId,
              'task_id': payload.taskId,
              'timestamp_ms': payload.timestampMs,
              'event_type': payload.eventType,
              'session_latency_ms': payload.sessionLatencyMs,
              'hesitation_ms': payload.hesitationMs,
              'correction_rate': payload.correctionRate,
              'replay_count': payload.replayCount,
              'hint_request_count': payload.hintRequestCount,
              'touch_events': payload.touchEvents
                  .map((e) => {'x': e.x, 'y': e.y, 'pressure': e.pressure, 'timestamp_ms': e.timestampMs})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        debugPrint('[Telemetry] C1 returned ${response.statusCode}');
      } else {
        debugPrint('[Telemetry] Sent: ${payload.eventType} for student ${payload.studentId}');
      }
    } catch (e) {
      debugPrint('[Telemetry] Send error: $e');
      // Fail silently — don't break the app
    }
  }
}
