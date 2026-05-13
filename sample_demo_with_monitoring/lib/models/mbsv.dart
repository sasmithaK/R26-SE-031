class MBSV {
  final double visualStrainIndex;
  final double cognitiveLoadIndex;
  final double phonologicalStrainIndex;
  final double engagementIndex;
  final double sessionFatigueIndex;
  final List<double> errorPatternVector;

  MBSV({
    required this.visualStrainIndex,
    required this.cognitiveLoadIndex,
    required this.phonologicalStrainIndex,
    required this.engagementIndex,
    required this.sessionFatigueIndex,
    required this.errorPatternVector,
  });

  factory MBSV.fromJson(Map<String, dynamic> json) {
    return MBSV(
      visualStrainIndex: (json['visual_strain_index'] ?? 0.0).toDouble(),
      cognitiveLoadIndex: (json['cognitive_load_index'] ?? 0.0).toDouble(),
      phonologicalStrainIndex: (json['phonological_strain_index'] ?? 0.0).toDouble(),
      engagementIndex: (json['engagement_index'] ?? 0.0).toDouble(),
      sessionFatigueIndex: (json['session_fatigue_index'] ?? 0.0).toDouble(),
      errorPatternVector: List<double>.from(json['error_pattern_vector'] ?? [0.0, 0.0, 0.0]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visual_strain_index': visualStrainIndex,
      'cognitive_load_index': cognitiveLoadIndex,
      'phonological_strain_index': phonologicalStrainIndex,
      'engagement_index': engagementIndex,
      'session_fatigue_index': sessionFatigueIndex,
      'error_pattern_vector': errorPatternVector,
    };
  }

  factory MBSV.initial() {
    return MBSV(
      visualStrainIndex: 0.1,
      cognitiveLoadIndex: 0.1,
      phonologicalStrainIndex: 0.1,
      engagementIndex: 0.9,
      sessionFatigueIndex: 0.0,
      errorPatternVector: [0.0, 0.0, 0.0],
    );
  }
}
