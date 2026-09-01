class C1TrendPoint {
  final String sessionId;
  final int sessionIndex;
  final double accuracy;
  final double medianLatencyMs;
  final double fatigueScore;
  final double hesitationRate;
  final DateTime timestamp;

  C1TrendPoint({
    required this.sessionId,
    required this.sessionIndex,
    required this.accuracy,
    required this.medianLatencyMs,
    required this.fatigueScore,
    required this.hesitationRate,
    required this.timestamp,
  });

  factory C1TrendPoint.fromJson(Map<String, dynamic> json) {
    return C1TrendPoint(
      sessionId: json['session_id'] ?? '',
      sessionIndex: json['session_index'] ?? 0,
      accuracy: json['accuracy'] ?? 0.0,
      medianLatencyMs: json['median_latency_ms'] ?? 0.0,
      fatigueScore: json['fatigue_score'] ?? 0.0,
      hesitationRate: json['hesitation_rate'] ?? 0.0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }
}
