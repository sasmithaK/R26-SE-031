class ParentC1Summary {
  final String studentId;
  final int overallProgress;
  final int accuracy;
  final String responseSpeed;
  final String attention;
  final String fatigue;
  final List<String> learningObservations;
  final List<String> recommendedPractice;
  final DateTime updatedAt;

  ParentC1Summary({
    required this.studentId,
    required this.overallProgress,
    required this.accuracy,
    required this.responseSpeed,
    required this.attention,
    required this.fatigue,
    required this.learningObservations,
    required this.recommendedPractice,
    required this.updatedAt,
  });

  factory ParentC1Summary.fromJson(Map<String, dynamic> json) {
    return ParentC1Summary(
      studentId: json['student_id'] ?? '',
      overallProgress: json['overall_progress'] ?? 0,
      accuracy: json['accuracy'] ?? 0,
      responseSpeed: json['response_speed'] ?? 'UNKNOWN',
      attention: json['attention'] ?? 'UNKNOWN',
      fatigue: json['fatigue'] ?? 'UNKNOWN',
      learningObservations: List<String>.from(json['learning_observations'] ?? []),
      recommendedPractice: List<String>.from(json['recommended_practice'] ?? []),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }
}
