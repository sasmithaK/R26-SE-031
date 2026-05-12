/// Represents a student's fluency progress record.
/// Fluency levels are calculated as:
/// Level 1: New student (0 sessions) or WPM < 20
/// Level 2: 1-3 sessions with WPM 20-40
/// Level 3: 4+ sessions with WPM 35-60
/// Level 4: Advanced (WPM >= 60)
class FluencyProgress {
  final String studentId;
  final int sessionsCompleted;
  final double avgWpm;
  final int fluencyLevel;
  final double avgWer; // Average Word Error Rate
  final int breakdownLevel; // Level where fluency broke down (0 = not yet)
  final DateTime lastUpdated;

  FluencyProgress({
    required this.studentId,
    required this.sessionsCompleted,
    required this.avgWpm,
    required this.fluencyLevel,
    this.avgWer = 0.0,
    this.breakdownLevel = 0,
    required this.lastUpdated,
  });

  /// Calculate fluency level based on sessions and average WPM.
  static int calculateFluencyLevel(int sessions, double avgWpm) {
    int tier;
    if (sessions == 0 || avgWpm < 20) {
      tier = 1;
    } else if (sessions >= 1 && sessions < 4 && avgWpm >= 20 && avgWpm < 40) {
      tier = 2;
    } else if (sessions >= 4 && avgWpm >= 35 && avgWpm < 60) {
      tier = 3;
    } else if (avgWpm >= 60) {
      tier = 4;
    } else {
      // Default tier based on sessions
      tier = (sessions >= 4) ? 3 : ((sessions >= 1) ? 2 : 1);
    }
    return tier;
  }

  /// Convert to JSON for MongoDB storage.
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'sessionsCompleted': sessionsCompleted,
      'avgWpm': avgWpm,
      'fluencyLevel': fluencyLevel,
      'avgWer': avgWer,
      'breakdownLevel': breakdownLevel,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON (e.g., from MongoDB).
  factory FluencyProgress.fromJson(Map<String, dynamic> json) {
    return FluencyProgress(
      studentId: json['studentId'] as String,
      sessionsCompleted: json['sessionsCompleted'] as int,
      avgWpm: (json['avgWpm'] as num).toDouble(),
      fluencyLevel: json['fluencyLevel'] as int,
      avgWer: (json['avgWer'] as num?)?.toDouble() ?? 0.0,
      breakdownLevel: json['breakdownLevel'] as int? ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}
