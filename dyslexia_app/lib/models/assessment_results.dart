/// Data model for comprehensive assessment results
/// Collects 4 key assessment parameters with ratings (weak/moderate/strong)
class AssessmentResults {
  final String studentId;
  final String studentName;
  final int studentAge;
  final String studentGrade;
  
  // The 4 assessment parameters
  final int letterScore; // 0-3 (correct letters identified)
  final double wordsPerMinute; // WPM from fluency task
  final int comprehensionScore; // 0-3 (picture-sentence matches)
  final int wordErrorCount; // errors during fluency task
  
  // Corresponding ratings
  final String letterRating; // weak/moderate/strong
  final String wpmRating; // weak/moderate/strong
  final String comprehensionRating; // weak/moderate/strong
  final String errorRating; // weak/moderate/strong
  
  // Overall tier (combines all 4 ratings)
  final int tier; // 1, 2, or 3
  final String tierDescription;
  final String tierSupport; // High Support, Moderate Support, Developing Well
  
  final DateTime assessedAt;
  
  AssessmentResults({
    required this.studentId,
    required this.studentName,
    required this.studentAge,
    required this.studentGrade,
    required this.letterScore,
    required this.wordsPerMinute,
    required this.comprehensionScore,
    required this.wordErrorCount,
    required this.letterRating,
    required this.wpmRating,
    required this.comprehensionRating,
    required this.errorRating,
    required this.tier,
    required this.tierDescription,
    required this.tierSupport,
    required this.assessedAt,
  });

  /// Convert to JSON for MongoDB storage
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentAge': studentAge,
      'studentGrade': studentGrade,
      'assessmentParameters': {
        'letterScore': letterScore,
        'wordsPerMinute': wordsPerMinute,
        'comprehensionScore': comprehensionScore,
        'wordErrorCount': wordErrorCount,
      },
      'ratings': {
        'letterRating': letterRating,
        'wpmRating': wpmRating,
        'comprehensionRating': comprehensionRating,
        'errorRating': errorRating,
      },
      'tier': {
        'level': tier,
        'description': tierDescription,
        'supportType': tierSupport,
      },
      'assessedAt': assessedAt.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Create from JSON
  factory AssessmentResults.fromJson(Map<String, dynamic> json) {
    return AssessmentResults(
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String,
      studentAge: json['studentAge'] as int,
      studentGrade: json['studentGrade'] as String,
      letterScore: json['assessmentParameters']['letterScore'] as int,
      wordsPerMinute: (json['assessmentParameters']['wordsPerMinute'] as num).toDouble(),
      comprehensionScore: json['assessmentParameters']['comprehensionScore'] as int,
      wordErrorCount: json['assessmentParameters']['wordErrorCount'] as int,
      letterRating: json['ratings']['letterRating'] as String,
      wpmRating: json['ratings']['wpmRating'] as String,
      comprehensionRating: json['ratings']['comprehensionRating'] as String,
      errorRating: json['ratings']['errorRating'] as String,
      tier: json['tier']['level'] as int,
      tierDescription: json['tier']['description'] as String,
      tierSupport: json['tier']['supportType'] as String,
      assessedAt: DateTime.parse(json['assessedAt'] as String),
    );
  }

  /// Get overall performance summary (legacy method)
  String getPerformanceSummary() {
    final ratings = [letterRating, wpmRating, comprehensionRating, errorRating];
    final strongCount = ratings.where((r) => r == 'strong').length;
    final moderateCount = ratings.where((r) => r == 'moderate').length;
    
    if (strongCount >= 3) return 'excellent';
    if (strongCount >= 2 && moderateCount >= 1) return 'good';
    if (moderateCount >= 3) return 'fair';
    return 'needs_support';
  }

  /// Get tier details with recommendations
  Map<String, String> getTierDetails() {
    switch (tier) {
      case 1:
        return {
          'tier': 'Tier 1',
          'support': 'Needs High Support',
          'recommendation': 'Easiest game versions, maximum visual hints, slow speed, large targets, no time pressure',
        };
      case 2:
        return {
          'tier': 'Tier 2',
          'support': 'Needs Moderate Support',
          'recommendation': 'Medium difficulty games, some hints available, moderate pace',
        };
      case 3:
        return {
          'tier': 'Tier 3',
          'support': 'Developing Well',
          'recommendation': 'More challenging games, minimal hints, slightly faster pace',
        };
      default:
        return {'tier': 'Unknown', 'support': 'Unknown', 'recommendation': ''};
    }
  }
}