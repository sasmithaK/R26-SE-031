/// Data model for Letter Identification Assessment
/// Tracks both visual discrimination and phonological awareness scores
class LetterIdentificationScore {
  final String studentId;
  final String letter;
  final bool visualDiscriminationCorrect; // Did they match the letter visually?
  final int visualDiscriminationTime; // Time taken in seconds
  final bool phonologicalAwarenessCorrect; // Did they pick the correct picture?
  final int phonologicalAwarenessTime; // Time taken in seconds
  final DateTime attemptedAt;

  LetterIdentificationScore({
    required this.studentId,
    required this.letter,
    required this.visualDiscriminationCorrect,
    required this.visualDiscriminationTime,
    required this.phonologicalAwarenessCorrect,
    required this.phonologicalAwarenessTime,
    required this.attemptedAt,
  });

  /// Calculate overall success (both tasks correct)
  bool get isSuccessful => visualDiscriminationCorrect && phonologicalAwarenessCorrect;

  /// Total time for both tasks
  int get totalTime => visualDiscriminationTime + phonologicalAwarenessTime;

  /// Convert to JSON for MongoDB storage
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'letter': letter,
      'visualDiscriminationCorrect': visualDiscriminationCorrect,
      'visualDiscriminationTime': visualDiscriminationTime,
      'phonologicalAwarenessCorrect': phonologicalAwarenessCorrect,
      'phonologicalAwarenessTime': phonologicalAwarenessTime,
      'isSuccessful': isSuccessful,
      'totalTime': totalTime,
      'attemptedAt': attemptedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory LetterIdentificationScore.fromJson(Map<String, dynamic> json) {
    return LetterIdentificationScore(
      studentId: json['studentId'] as String,
      letter: json['letter'] as String,
      visualDiscriminationCorrect: json['visualDiscriminationCorrect'] as bool,
      visualDiscriminationTime: json['visualDiscriminationTime'] as int,
      phonologicalAwarenessCorrect: json['phonologicalAwarenessCorrect'] as bool,
      phonologicalAwarenessTime: json['phonologicalAwarenessTime'] as int,
      attemptedAt: DateTime.parse(json['attemptedAt'] as String),
    );
  }
}

/// Represents a session of letter identification assessment
class LetterIdentificationSession {
  final String studentId;
  final List<LetterIdentificationScore> scores;
  final DateTime startedAt;
  final DateTime? completedAt;

  LetterIdentificationSession({
    required this.studentId,
    required this.scores,
    required this.startedAt,
    this.completedAt,
  });

  /// Calculate overall visual discrimination accuracy
  double get visualDiscriminationAccuracy {
    if (scores.isEmpty) return 0.0;
    final correct = scores.where((s) => s.visualDiscriminationCorrect).length;
    return (correct / scores.length) * 100;
  }

  /// Calculate overall phonological awareness accuracy
  double get phonologicalAwarenessAccuracy {
    if (scores.isEmpty) return 0.0;
    final correct = scores.where((s) => s.phonologicalAwarenessCorrect).length;
    return (correct / scores.length) * 100;
  }

  /// Calculate overall task success rate
  double get overallSuccessRate {
    if (scores.isEmpty) return 0.0;
    final correct = scores.where((s) => s.isSuccessful).length;
    return (correct / scores.length) * 100;
  }

  /// Convert to JSON for MongoDB storage
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'scores': scores.map((s) => s.toJson()).toList(),
      'visualDiscriminationAccuracy': visualDiscriminationAccuracy,
      'phonologicalAwarenessAccuracy': phonologicalAwarenessAccuracy,
      'overallSuccessRate': overallSuccessRate,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory LetterIdentificationSession.fromJson(Map<String, dynamic> json) {
    final scoresList = (json['scores'] as List)
        .map((s) => LetterIdentificationScore.fromJson(s))
        .toList();
    return LetterIdentificationSession(
      studentId: json['studentId'] as String,
      scores: scoresList,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    );
  }
}
