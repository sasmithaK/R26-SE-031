class LearnerProfile {
  final String studentId;

  // Raw assessment scores
  final int letterScore;
  final double wpmScore;
  final int comprehensionScore;
  final int wordErrorCount;

  // Derived values
  final int profileTier;
  final int startingGameLevel;

  const LearnerProfile({
    required this.studentId,
    required this.letterScore,
    required this.wpmScore,
    required this.comprehensionScore,
    required this.wordErrorCount,
    required this.profileTier,
    required this.startingGameLevel,
  });

  factory LearnerProfile.fromScores({
    required String studentId,
    required int letterScore,
    required double wpmScore,
    required int comprehensionScore,
    required int wordErrorCount,
  }) {
    final tier = _calculateTier(
      letterScore,
      wpmScore,
      comprehensionScore,
      wordErrorCount,
    );

    final startingLevel = _tierToGameLevel(tier);

    return LearnerProfile(
      studentId: studentId,
      letterScore: letterScore,
      wpmScore: wpmScore,
      comprehensionScore: comprehensionScore,
      wordErrorCount: wordErrorCount,
      profileTier: tier,
      startingGameLevel: startingLevel,
    );
  }

  static int _calculateTier(
    int letterScore,
    double wpmScore,
    int comprehensionScore,
    int wordErrorCount,
  ) {
    final int letterSub = letterScore <= 1 ? 0 : letterScore == 2 ? 1 : 2;
    final int wpmSub = wpmScore < 15 ? 0 : wpmScore <= 25 ? 1 : 2;
    final int comprehSub = comprehensionScore <= 1 ? 0 : comprehensionScore == 2 ? 1 : 2;
    final int errorSub = wordErrorCount > 3 ? 0 : wordErrorCount >= 2 ? 1 : 2;

    final double average = (letterSub + wpmSub + comprehSub + errorSub) / 4.0;

    if (average < 0.75) return 1;
    if (average < 1.5) return 2;
    return 3;
  }

  static int _tierToGameLevel(int tier) {
    switch (tier) {
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 3;
      default:
        return 1;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'letterScore': letterScore,
      'wpmScore': wpmScore,
      'comprehensionScore': comprehensionScore,
      'wordErrorCount': wordErrorCount,
      'profileTier': profileTier,
      'startingGameLevel': startingGameLevel,
    };
  }

  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    return LearnerProfile(
      studentId: json['studentId'] as String,
      letterScore: json['letterScore'] as int,
      wpmScore: (json['wpmScore'] as num).toDouble(),
      comprehensionScore: json['comprehensionScore'] as int,
      wordErrorCount: json['wordErrorCount'] as int,
      profileTier: json['profileTier'] as int,
      startingGameLevel: json['startingGameLevel'] as int,
    );
  }
}