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
    assessment_summary: Dict[str, Any] = Field(default_factory=dict)

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

class RoundJourneyItem(BaseModel):
    round_number: int
    result_icon: str            # "⭐" / "👍" / "💡" / "📝"
    result_text: str            # "Got it right!" / "Needed a hint" / "Got extra practice"
    was_first_try: bool
    needed_remediation: bool

class RecommendedPracticeItem(BaseModel):
    activity_id: str            # "2.1"
    activity_name: str          # "අකුරු හඳුනමු (Letter Identification)"
    description: str            # "Strengthens letter recognition"
    template_type: str          # "skill2_odd_one_out"
    rounds_count: int           # 7

class AdaptiveInsightItem(BaseModel):
    activity_id: str
    activity_name: str
    # 1. Completion Progress
    rounds_completed: int
    rounds_total: int
    is_activity_complete: bool
    completion_text: str        # "3 of 5 puzzles done" / "Activity Complete!"
    # 2. First-Try Accuracy
    first_try_correct: int
    first_try_total: int
    accuracy_text: str          # "Got 4 right on first try!"
    # 3. App Adaptation Story
    remediation_count: int
    adaptation_text: str        # "App gave extra practice on 2 tricky puzzles"
    # 4. Independence Level
    independent_rounds: int
    guided_rounds: int
    independence_text: str      # "Solved 4 independently"
    independence_badge: str     # "Independent Learner 🌟" / "Guided Learner 💡"
    # 5. Round Journey
    round_journey: List[RoundJourneyItem]
    # 6. Overall Rating
    star_rating: int            # 1-3
    rating_text: str            # "⭐⭐⭐ Excellent!" / "⭐⭐ Good Progress!"
    # 7. Recommended Practice
    recommendations: List[RecommendedPracticeItem]
    # Meta
    last_played: str
    times_played: int

class ParentAdaptiveInsightsDTO(APIResponseBase):
    activities: List[AdaptiveInsightItem]
    support_summary: Dict[str, Any] = Field(default_factory=dict)
    policy_notice: str = ""

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
    grapheme_accuracy: Optional[float] = None
    word_accuracy: Optional[float] = None
    reading_rate_wpm: Optional[float] = None
    combined_confidence: Optional[float] = None
    reading_performance_score: Optional[float] = None
    method_disagreement: bool = False
    quality_issues: List[str] = Field(default_factory=list)
    recording_quality: str

class SpeechTrends(BaseModel):
    accuracy: List[Dict[str, Any]]
    wer: List[Dict[str, Any]]
    latency: List[Dict[str, Any]]
    silence_ratio: List[Dict[str, Any]]
    peak_delta: List[Dict[str, Any]]

class TherapistC2SpeechDTO(MLResponseBase):
    recording_count: int = 0
    usable_recording_count: int = 0
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
    pipeline_status: str = "not_run"
    missing_inputs: List[str] = Field(default_factory=list)

class KnowledgeComponent(BaseModel):
    id: str
    name: str
    mastery: float
    observations: int = 0
    independent_observations: int = 0
    supported_observations: int = 0
    last_observed_at: Optional[str] = None

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
    reason_codes: List[str] = Field(default_factory=list)
    item_id: Optional[str] = None
    knowledge_component_id: Optional[str] = None
    response_quality: Optional[str] = None
    item_role: Optional[str] = None
    mastery_evidence_role: Optional[str] = None
    mastery_update_applied: Optional[bool] = None

class TherapistC4AdaptiveDTO(MLResponseBase):
    knowledge_components: List[KnowledgeComponent]
    skills: List[Dict[str, Any]] = Field(default_factory=list)
    activities: List[Dict[str, Any]] = Field(default_factory=list)
    theta: Optional[float] = None
    theta_se: Optional[float] = None
    updated_at: str
    updated_at_state: Optional[str] = None  # Knowledge state last updated timestamp
    history: List[AdaptiveHistoryItem]
    policy_status: Dict[str, Any] = Field(default_factory=dict)
    latest_policy_decision: Dict[str, Any] = Field(default_factory=dict)
    support_effectiveness: List[Dict[str, Any]] = Field(default_factory=list)
    persistent_learning_needs: List[Dict[str, Any]] = Field(default_factory=list)
    summary: Dict[str, Any] = Field(default_factory=dict)
    mastery_trend: List[Dict[str, Any]] = Field(default_factory=list)
    recurring_targets: List[Dict[str, Any]] = Field(default_factory=list)
    next_session_plan: Dict[str, Any] = Field(default_factory=dict)
    data_quality: Dict[str, Any] = Field(default_factory=dict)
