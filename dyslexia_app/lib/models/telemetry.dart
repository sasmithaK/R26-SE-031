class TouchEvent {
  final double x;
  final double y;
  final double pressure;
  final int timestampMs;

  TouchEvent({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'pressure': pressure,
        'timestamp_ms': timestampMs,
      };
}

class TelemetryPayload {
  final String studentId;
  final String taskId;
  final String sessionId;
  final int timestampMs;
  final List<TouchEvent> touchEvents;
  final String eventType;
  final int sessionLatencyMs;
  final int hesitationMs;
  final double swipeVelocity;
  final double correctionRate;
  final int replayCount;
  final int hintRequestCount;

  TelemetryPayload({
    required this.studentId,
    required this.taskId,
    required this.sessionId,
    required this.timestampMs,
    this.touchEvents = const [],
    this.eventType = 'TAP',
    this.sessionLatencyMs = 0,
    this.hesitationMs = 0,
    this.swipeVelocity = 0.0,
    this.correctionRate = 0.0,
    this.replayCount = 0,
    this.hintRequestCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'task_id': taskId,
        'session_id': sessionId,
        'timestamp_ms': timestampMs,
        'touch_events': touchEvents.map((e) => e.toJson()).toList(),
        'event_type': eventType,
        'session_latency_ms': sessionLatencyMs,
        'hesitation_ms': hesitationMs,
        'swipe_velocity': swipeVelocity,
        'correction_rate': correctionRate,
        'replay_count': replayCount,
        'hint_request_count': hintRequestCount,
      };
}
