from pydantic import BaseModel, Field
from typing import Optional, Dict

class BehavioralFeatures(BaseModel):
    accuracy: Optional[float] = None
    mean_latency_ms: Optional[float] = None
    median_latency_ms: Optional[float] = None
    latency_std_ms: Optional[float] = None
    mean_first_touch_latency_ms: Optional[float] = None
    hesitation_rate: Optional[float] = None
    misclick_rate: Optional[float] = None
    replay_rate: Optional[float] = None
    completion_rate: Optional[float] = None
    latency_drift: Optional[float] = None
    error_drift: Optional[float] = None
    hesitation_drift: Optional[float] = None
    accuracy_slope: Optional[float] = None
    total_questions: Optional[int] = 0
    correct_answers: Optional[int] = 0
    hesitation_count: Optional[int] = 0
    misclick_count: Optional[int] = 0
    replay_count: Optional[int] = 0

class LearnerIndices(BaseModel):
    # New non-overclaiming terminology
    visual_task_performance: Optional[float] = None
    phonological_task_performance: Optional[float] = None
    motor_interaction_pattern: Optional[float] = None
    attention_interaction_indicator: Optional[float] = None
    behavioral_fatigue_indicator: Optional[float] = None

    # Legacy fields (preserved temporarily for UI compatibility)
    visual_processing_index: Optional[float] = None
    phonological_task_index: Optional[float] = None
    motor_interaction_index: Optional[float] = None
    attention_stability_index: Optional[float] = None

class FatigueState(BaseModel):
    score: float = Field(default=0.0)
    state: str = Field(default="LOW", description="LOW, MODERATE, HIGH, VERY_HIGH")

class InteractionState(BaseModel):
    score: float = Field(default=0.0)
    state: str = Field(default="ENGAGED", description="ENGAGED, MODERATE_LOAD, HIGH_LOAD")

class QualityMetrics(BaseModel):
    events_received: int
    events_valid: int
    events_invalid: int
    missing_feature_rate: float
    quality_score: float

class ModelMetadata(BaseModel):
    model_name: str
    model_version: str
    feature_schema_version: str
    predicted_pattern: Optional[str] = None
    probabilities: Optional[Dict[str, float]] = None
    confidence: Optional[float] = None
    model_used: Optional[str] = None

class C1Result(BaseModel):
    student_id: str
    session_id: str
    behavior: BehavioralFeatures
    indices: LearnerIndices
    fatigue: FatigueState
    interaction_state: InteractionState
    quality: QualityMetrics
    model: ModelMetadata

from datetime import datetime

class ParentC1Summary(BaseModel):
    student_id: str
    overall_progress: int
    accuracy: int
    response_speed: str
    attention: str
    fatigue: str
    learning_observations: list[str] = Field(default_factory=list)
    recommended_practice: list[str] = Field(default_factory=list)
    updated_at: datetime

class TherapistC1State(C1Result):
    updated_at: Optional[datetime] = None

class C1TrendPoint(BaseModel):
    session_id: str
    session_index: int
    accuracy: float
    median_latency_ms: float
    fatigue_score: float
    hesitation_rate: float
    timestamp: datetime

class C1SessionSummary(BaseModel):
    session_id: str
    session_index: int
    accuracy: float
    median_latency_ms: float
    hesitation_rate: float
    fatigue_score: float
    timestamp: datetime

class SessionSummary(BaseModel):
    student_id: str
    session_id: str
    started_at: str
    completed_at: str
    total_trials: int
    overall: dict
    error_profile: dict
    behavioral_fatigue_proxy: Optional[float]
    fatigue_components: dict
    knowledge_components: dict
    activity_breakdown: dict
    feature_version: str = "c1-v2"
    schema_version: str = "1.0"

class C3ReadyFeatures(BaseModel):
    akshara_accuracy: Optional[float] = None
    akshara_median_latency_ms: Optional[float] = None
    phoneme_grapheme_accuracy: Optional[float] = None
    phoneme_grapheme_median_latency_ms: Optional[float] = None
    word_recognition_accuracy: Optional[float] = None
    word_recognition_median_latency_ms: Optional[float] = None
    spelling_sequence_accuracy: Optional[float] = None
    sequence_error_rate: Optional[float] = None
    sentence_language_accuracy: Optional[float] = None
    reading_comprehension_accuracy: Optional[float] = None
    orthographic_confusion_rate: Optional[float] = None
    phonological_confusion_rate: Optional[float] = None
    overall_accuracy: Optional[float] = None
    mean_attempts_per_round: Optional[float] = None
    mean_incorrect_attempts_per_round: Optional[float] = None
    retry_rate: Optional[float] = None
    median_response_latency_ms: Optional[float] = None
    median_time_to_correct_ms: Optional[float] = None
    correction_rate: Optional[float] = None
    mean_audio_replays_per_audio_trial: Optional[float] = None
    audio_replay_trial_rate: Optional[float] = None
    audio_replay_rate: Optional[float] = None # Deprecated, use mean_audio_replays_per_audio_trial
    behavioral_fatigue_proxy: Optional[float] = None
    visual_support_accuracy: Optional[float] = None

