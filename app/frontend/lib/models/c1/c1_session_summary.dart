class C1SessionSummary {
  final String sessionId;
  final int sessionIndex;
  final double accuracy;
  final double medianLatencyMs;
  final double hesitationRate;
  final double misclickRate;
  final double fatigueScore;
  final DateTime timestamp;

  C1SessionSummary({
    required this.sessionId,
    required this.sessionIndex,
    required this.accuracy,
    required this.medianLatencyMs,
    required this.hesitationRate,
    required this.misclickRate,
    required this.fatigueScore,
    required this.timestamp,
  });

  factory C1SessionSummary.fromJson(Map<String, dynamic> json) {
    return C1SessionSummary(
      sessionId: json['session_id'] ?? '',
      sessionIndex: json['session_index'] ?? 0,
      accuracy: json['accuracy'] ?? 0.0,
      medianLatencyMs: json['median_latency_ms'] ?? 0.0,
      hesitationRate: json['hesitation_rate'] ?? 0.0,
      misclickRate: json['misclick_rate'] ?? 0.0,
      fatigueScore: json['fatigue_score'] ?? 0.0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }
}
