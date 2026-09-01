from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

# ==========================================
# C1: Behavioral Monitoring (Telemetry)
# ==========================================

class TelemetryEvent(BaseModel):
    event_id: str
    student_id: str
    session_id: str
    activity_id: str
    item_id: str
    timestamp: str
    is_correct: bool
    first_touch_latency_ms: Optional[float] = None
    total_round_latency_ms: float
    hesitation_count: int = 0
    misclick_count: int = 0
    audio_replay_count: int = 0

class BehavioralFeatures(BaseModel):
    session_id: str
    student_id: str
    accuracy: float
    median_latency_ms: float
    latency_std_ms: float
    hesitation_rate: float
    misclick_rate: float
    latency_drift: float
    error_drift: float
    fatigue_score: float
    visual_processing_index: float
    phonological_task_index: float
    motor_interaction_index: float
    attention_stability_index: float
    feature_version: str

# ==========================================
# C2: Kinematic Engine
# ==========================================

class KinematicFeatures(BaseModel):
    event_id: str
    student_id: str
    session_id: str
    target_character: str
    selected_character: str
    time_to_first_touch_ms: float
    path_length: float
    straight_line_distance: float
    path_efficiency: float
    mean_velocity: float
    velocity_variance: float
    mean_dwell_time_ms: float
    normalized_jerk: float
    orthographic_confusion_index: float
    feature_version: str

class SpeechFeatures(BaseModel):
    event_id: str
    student_id: str
    speech_latency_ms: float
    speech_duration_ms: float
    intra_word_silence_ratio: float
    jitter: float
    shimmer: float
    stt_confidence: float
    feature_version: str

# ==========================================
# C3: Learner Profile & XAI
# ==========================================

class SHAPFeature(BaseModel):
    feature: str
    value: float
    contribution: float

class LearnerProfile(BaseModel):
    student_id: str
    session_id: str
    profile: str
    probabilities: Dict[str, float]
    confidence: float
    shap: List[SHAPFeature]
    modalities_used: List[str]
    model_version: str

# ==========================================
# C4: Adaptive Tutoring & Knowledge States
# ==========================================

class KnowledgeState(BaseModel):
    student_id: str
    knowledge_components: Dict[str, float]
    theta_estimate: float
    theta_standard_error: float
    updated_at: str
    model_version: str

class AdaptiveDecision(BaseModel):
    decision_id: str
    student_id: str
    session_id: str
    knowledge_component_id: str
    mastery_before: float
    mastery_after: float
    fatigue_score: float
    previous_difficulty: float
    selected_difficulty: float
    previous_activity: str
    selected_activity: str
    scaffold_level: int
    session_decision: str
    decision_reason: str
    policy_version: str

# ==========================================
# Model Version Metadata
# ==========================================

class ModelVersion(BaseModel):
    model_id: str
    version: str
    algorithm: str
    feature_schema: str
    training_dataset: str
    created_at: str
    status: str
