class TherapistC1State {
  final String studentId;
  final String? sessionId;
  final Map<String, dynamic> behavior;
  final Map<String, dynamic> indices;
  final Map<String, dynamic> fatigue;
  final Map<String, dynamic> interactionState;
  final Map<String, dynamic> model;
  final Map<String, dynamic> quality;
  final DateTime? updatedAt;

  TherapistC1State({
    required this.studentId,
    this.sessionId,
    required this.behavior,
    required this.indices,
    required this.fatigue,
    required this.interactionState,
    required this.model,
    required this.quality,
    this.updatedAt,
  });

  factory TherapistC1State.fromJson(Map<String, dynamic> json) {
    return TherapistC1State(
      studentId: json['student_id'] ?? '',
      sessionId: json['session_id'],
      behavior: json['behavior'] ?? {},
      indices: json['indices'] ?? {},
      fatigue: json['fatigue'] ?? {},
      interactionState: json['interaction_state'] ?? {},
      model: json['model'] ?? {},
      quality: json['quality'] ?? {},
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  double get accuracy => (behavior['accuracy'] ?? 0.0) * 100;
  double get medianLatencyMs => behavior['median_latency_ms'] ?? 0.0;
  double get hesitationRate => (behavior['hesitation_rate'] ?? 0.0) * 100;
  double get misclickRate => (behavior['misclick_rate'] ?? 0.0) * 100;
  double get replayRate => (behavior['replay_rate'] ?? 0.0) * 100;
  double get completionRate => (behavior['completion_rate'] ?? 0.0) * 100;

  int get totalQuestions => behavior['total_questions'] ?? 0;
  int get correctAnswers => behavior['correct_answers'] ?? 0;
  int get hesitationCount => behavior['hesitation_count'] ?? 0;
  int get misclickCount => behavior['misclick_count'] ?? 0;
  int get replayCount => behavior['replay_count'] ?? 0;

  double get visualProcessingIndex => indices['visual_processing_index'] ?? 0.0;
  double get phonologicalTaskIndex => indices['phonological_task_index'] ?? 0.0;
  double get motorInteractionIndex => indices['motor_interaction_index'] ?? 0.0;
  double get attentionStabilityIndex => indices['attention_stability_index'] ?? 0.0;
  
  double get fatigueScore => fatigue['score'] ?? 0.0;
  String get fatigueStateStr => fatigue['state'] ?? 'LOW';

  double get interactionScore => interactionState['score'] ?? 0.0;
  String get interactionStateStr => interactionState['state'] ?? 'ENGAGED';
  
  String get pattern => model['predicted_pattern'] ?? 'UNKNOWN';
  double get patternProbability {
    var probs = model['probabilities'];
    if (probs != null && probs is Map && pattern != 'UNKNOWN') {
      return (probs[pattern] ?? 0.0) * 100;
    }
    return 0.0;
  }
}
