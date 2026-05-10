/// Represents a student's reading comprehension progress record.
/// Comprehension assessment combines reading fluency (word-tapping) with picture matching.
/// Levels measure: reading time, accuracy (correct picture match), and cognitive load tolerance.
class ComprehensionProgress {
  final String studentId;
  final int sessionsCompleted;
  final double avgReadingTimeSeconds;
  final double comprehensionAccuracy; // Percentage of correct matches (0-100)
  final int highestLevelReached; // 1, 2, or 3
  final int failureLevel; // Level where student first failed (0 = no failure yet)
  final DateTime lastUpdated;

  ComprehensionProgress({
    required this.studentId,
    required this.sessionsCompleted,
    required this.avgReadingTimeSeconds,
    required this.comprehensionAccuracy,
    required this.highestLevelReached,
    this.failureLevel = 0,
    required this.lastUpdated,
  });

  /// Calculate comprehension level based on accuracy and reading speed.
  static int calculateComprehensionLevel(
    double accuracy,
    double avgReadingTime,
  ) {
    // If accuracy is low, they're struggling to comprehend
    if (accuracy < 50) return 1;
    if (accuracy < 75) return 2;
    return 3;
  }

  /// Convert to JSON for MongoDB storage.
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'sessionsCompleted': sessionsCompleted,
      'avgReadingTimeSeconds': avgReadingTimeSeconds,
      'comprehensionAccuracy': comprehensionAccuracy,
      'highestLevelReached': highestLevelReached,
      'failureLevel': failureLevel,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON (MongoDB).
  factory ComprehensionProgress.fromJson(Map<String, dynamic> json) {
    return ComprehensionProgress(
      studentId: json['studentId'] as String,
      sessionsCompleted: json['sessionsCompleted'] as int? ?? 0,
      avgReadingTimeSeconds: (json['avgReadingTimeSeconds'] as num?)?.toDouble() ?? 0.0,
      comprehensionAccuracy: (json['comprehensionAccuracy'] as num?)?.toDouble() ?? 0.0,
      highestLevelReached: json['highestLevelReached'] as int? ?? 1,
      failureLevel: json['failureLevel'] as int? ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }
}
