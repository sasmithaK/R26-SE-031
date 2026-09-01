import 'c1_therapist_state.dart';

// Since the detailed session endpoint returns C1Result, we can just wrap it in C1SessionDetail 
// or alias it to TherapistC1State.
class C1SessionDetail extends TherapistC1State {
  C1SessionDetail({
    required super.studentId,
    super.sessionId,
    required super.behavior,
    required super.indices,
    required super.fatigue,
    required super.interactionState,
    required super.model,
    required super.quality,
    super.updatedAt,
  });

  factory C1SessionDetail.fromJson(Map<String, dynamic> json) {
    final state = TherapistC1State.fromJson(json);
    return C1SessionDetail(
      studentId: state.studentId,
      sessionId: state.sessionId,
      behavior: state.behavior,
      indices: state.indices,
      fatigue: state.fatigue,
      interactionState: state.interactionState,
      model: state.model,
      quality: state.quality,
      updatedAt: state.updatedAt,
    );
  }
}
