from datetime import datetime, timezone
from pydantic import BaseModel, Field, model_validator
from typing import List, Dict, Any, Optional

class APIResponseBase(BaseModel):
    data_origin: str = "unspecified"
    dataset_id: Optional[str] = None
    validation_status: str = "not_clinically_validated"
    limitations: List[str] = Field(default_factory=list)
    available: bool = False

    @model_validator(mode="before")
    @classmethod
    def serialize_mongo_timestamps(cls, values):
        if isinstance(values, dict):
            values = dict(values)
            for key in ("updated_at", "last_data_at", "last_active", "updated_at_state"):
                value = values.get(key)
                if isinstance(value, datetime):
                    if value.tzinfo is None:
                        value = value.replace(tzinfo=timezone.utc)
                    values[key] = value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
        return values

    updated_at: str
    student_id: str
    reporting_period: str

class MLResponseBase(APIResponseBase):
    model_version: str
    feature_version: str
    confidence: Optional[float] = None
    last_data_at: Optional[str] = None
    skip_reason: Optional[str] = None

# ==========================================
# PARENT DASHBOARD DTOs
# ==========================================

class ParentOverviewDTO(APIResponseBase):
    accuracy: Optional[int] = None
    practice_time_minutes: Optional[int] = None
    sessions_completed: int
    reading_progress: str

class ParentReadingFluencyDTO(APIResponseBase):
    fluency_status: str
    fluency_score: Optional[float] = None

class ParentReadingProgressDTO(APIResponseBase):
    accuracy_trend: List[Dict[str, Any]] # [{"session": "S1", "accuracy": 78}, ...]

class ParentLearningPatternDTO(APIResponseBase):
    observation: str
    recommended_practices: List[str]

class ActivityHistoryItem(BaseModel):
    session_id: Optional[str] = None
    duration_source: str = "unavailable"
    session_date: str
    activity_name: str
    accuracy: Optional[int] = None
    duration_minutes: Optional[int] = None

class ParentActivityHistoryDTO(APIResponseBase):
    history: List[ActivityHistoryItem]

# ==========================================
# THERAPIST DASHBOARD DTOs (C1-C4 Architecture)
# ==========================================

class TherapistOverviewDTO(MLResponseBase):
    accuracy: Optional[float] = None
    attempted_items: int
    completed_sessions: int
    reading_fluency_status: str
    overall_mastery: Optional[float] = None
    current_pattern: str
    pattern_confidence: Optional[float] = None
    fatigue_status: str
    last_active: Optional[str] = None
    c1_available: bool = False
    c2_available: bool = False
    c3_available: bool = False
    c4_available: bool = False
    latest_recommendation: Optional[str] = None
    assessment_results: List[bool] = Field(default_factory=list)
    comprehensive_assessment_results: Dict[str, List[bool]] = Field(default_factory=dict)
    reviewed_assessments: Dict[str, bool] = Field(default_factory=dict)
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    student_name: Optional[str] = None
    grade: Optional[str] = None
    age: Optional[int] = None
    avatar_url: Optional[str] = None
    parent_name: Optional[str] = None

class KCPerformance(BaseModel):
    KC_AKSHARA_IDENTITY: Optional[float] = None
    KC_PHONEME_GRAPHEME: Optional[float] = None
    KC_WORD_RECOGNITION: Optional[float] = None
    KC_SPELLING_SEQUENCE: Optional[float] = None
    KC_SENTENCE_LANGUAGE: Optional[float] = None
    KC_READING_COMPREHENSION: Optional[float] = None
    KC_VISUAL_SUPPORT: Optional[float] = None
    KC_ORTHOGRAPHIC_MEMORY: Optional[float] = None
    KC_ORAL_READING_FLUENCY: Optional[float] = None

class ErrorDistribution(BaseModel):
    visual_confusion: Optional[float] = None
    phonological_confusion: Optional[float] = None
    sequence_error: Optional[float] = None
    unknown_error: Optional[float] = None

class BehavioralTrends(BaseModel):
    accuracy: List[Dict[str, Any]]
    latency: List[Dict[str, Any]]
    fatigue: List[Dict[str, Any]]

class TherapistC1BehavioralDTO(MLResponseBase):
    session_id: Optional[str] = None
    data_source: str = "session_summaries"
    first_attempt_accuracy: Optional[float] = None
    median_response_latency_ms: Optional[float] = None
    retry_rate: Optional[float] = None
    mean_attempts_per_round: Optional[float] = None
    median_time_to_correct_ms: Optional[float] = None
    correction_rate: Optional[float] = None
    behavioral_fatigue_proxy: Optional[float] = None
    kc_performance: KCPerformance
    error_distribution: ErrorDistribution
    trends: BehavioralTrends

class SpeechLatest(BaseModel):
    pause_count: Optional[int] = None
    mean_pause_duration_ms: Optional[float] = None
    pause_ratio: Optional[float] = None
    speech_duration_ms: Optional[float] = None
    measurement_status: str = "unavailable"
    stt_confidence_method: Optional[str] = None
    expected_text: str
    transcription: str
    wer: Optional[float] = None
    stt_confidence: Optional[float] = None
    acoustic_latency_ms: Optional[float] = None
    voice_onset_ms: Optional[float] = None
    peak_delta: Optional[int] = None
    silence_ratio: Optional[float] = None
    jitter: Optional[float] = None
    shimmer: Optional[float] = None
    recording_quality: str

class SpeechTrends(BaseModel):
    accuracy: List[Dict[str, Any]]
    wer: List[Dict[str, Any]]
    latency: List[Dict[str, Any]]
    silence_ratio: List[Dict[str, Any]]
    peak_delta: List[Dict[str, Any]]

class TherapistC2SpeechDTO(MLResponseBase):
    latest: SpeechLatest
    trends: SpeechTrends

class ShapExplanation(BaseModel):
    feature: str
    contribution: float
    observed_value: Optional[float] = None
    direction: Optional[str] = None

class TherapistC3ProfileDTO(MLResponseBase):
    primary_pattern: str
    probabilities: Dict[str, float]
    confidence: Optional[float] = None
    modalities_used: List[str]
    shap_explanations: List[ShapExplanation]
    llm_summary: Optional[str] = None
    llm_recommendations: Optional[str] = None

class KnowledgeComponent(BaseModel):
    id: str
    name: str
    mastery: float

class AdaptiveHistoryItem(BaseModel):
    timestamp: str
    mastery_before: Optional[float] = None
    mastery_after: Optional[float] = None
    fatigue: Optional[float] = None
    previous_difficulty: Optional[float] = None
    selected_difficulty: Optional[float] = None
    scaffold_level: int
    next_activity: str
    decision: str
    reason: str

class TherapistC4AdaptiveDTO(MLResponseBase):
    knowledge_components: List[KnowledgeComponent]
    theta: Optional[float] = None
    theta_se: Optional[float] = None
    updated_at: str
    updated_at_state: Optional[str] = None  # Knowledge state last updated timestamp
    history: List[AdaptiveHistoryItem]
