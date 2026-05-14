class MBSV {
  final double visualStrainIndex;
  final double cognitiveLoadIndex;
  final double phonologicalStrainIndex;
  final double engagementIndex;
  final double sessionFatigueIndex;
  final double errorResilienceIndex;
  final List<double> errorPatternVector; // [reversal, omission, substitution, hesitation]

  MBSV({
    required this.visualStrainIndex,
    required this.cognitiveLoadIndex,
    required this.phonologicalStrainIndex,
    required this.engagementIndex,
    required this.sessionFatigueIndex,
    this.errorResilienceIndex = 0.0,
    required this.errorPatternVector,
  });

  factory MBSV.fromJson(Map<String, dynamic> json) {
    return MBSV(
      visualStrainIndex: (json['visual_strain_index'] ?? 0.0).toDouble(),
      cognitiveLoadIndex: (json['cognitive_load_index'] ?? 0.0).toDouble(),
      phonologicalStrainIndex: (json['phonological_strain_index'] ?? 0.0).toDouble(),
      engagementIndex: (json['engagement_index'] ?? 0.0).toDouble(),
      sessionFatigueIndex: (json['session_fatigue_index'] ?? 0.0).toDouble(),
      errorResilienceIndex: (json['error_resilience_index'] ?? 0.0).toDouble(),
      errorPatternVector: _parseErrorPattern(json['error_pattern_vector']),
    );
  }

  // Backend serialises ErrorPatternVector as {"reversal":0,"omission":0,"substitution":0,"hesitation":0}.
  // Also handles list format for forward-compatibility.
  static List<double> _parseErrorPattern(dynamic raw) {
    if (raw == null) return [0.0, 0.0, 0.0, 0.0];
    if (raw is List) {
      final list = raw.map((e) => (e as num).toDouble()).toList();
      while (list.length < 4) list.add(0.0);
      return list;
    }
    if (raw is Map) {
      return [
        (raw['reversal'] ?? 0).toDouble(),
        (raw['omission'] ?? 0).toDouble(),
        (raw['substitution'] ?? 0).toDouble(),
        (raw['hesitation'] ?? 0).toDouble(),
      ];
    }
    return [0.0, 0.0, 0.0, 0.0];
  }

  Map<String, dynamic> toJson() => {
    'visual_strain_index': visualStrainIndex,
    'cognitive_load_index': cognitiveLoadIndex,
    'phonological_strain_index': phonologicalStrainIndex,
    'engagement_index': engagementIndex,
    'session_fatigue_index': sessionFatigueIndex,
    'error_resilience_index': errorResilienceIndex,
    'error_pattern_vector': errorPatternVector,
  };

  factory MBSV.initial() => MBSV(
    visualStrainIndex: 0.1,
    cognitiveLoadIndex: 0.1,
    phonologicalStrainIndex: 0.1,
    engagementIndex: 0.9,
    sessionFatigueIndex: 0.0,
    errorResilienceIndex: 0.0,
    errorPatternVector: [0.0, 0.0, 0.0, 0.0],
  );
}
