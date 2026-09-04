from pydantic import BaseModel
from typing import List, Dict, Any, Optional

class APIResponseBase(BaseModel):
    updated_at: str
    student_id: str
    reporting_period: str

class MLResponseBase(APIResponseBase):
    model_version: str
    feature_version: str
    confidence: Optional[float] = None

# ==========================================
# PARENT DASHBOARD DTOs
# ==========================================

class ParentOverviewDTO(APIResponseBase):
    accuracy: int
    practice_time_minutes: int
    sessions_completed: int
    reading_progress: str

class ParentReadingFluencyDTO(APIResponseBase):
    fluency_status: str
    fluency_score: float

class ParentReadingProgressDTO(APIResponseBase):
    accuracy_trend: List[Dict[str, Any]] # [{"session": "S1", "accuracy": 78}, ...]

class ParentLearningPatternDTO(APIResponseBase):
    observation: str
    recommended_practices: List[str]

class ActivityHistoryItem(BaseModel):
    session_date: str
    activity_name: str
    accuracy: int
    duration_minutes: int

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

# ==========================================
# THERAPIST DASHBOARD DTOs
# ==========================================

class TherapistOverviewDTO(MLResponseBase):
    accuracy: int
    attempted_items: int
    fluency_status: str
    overall_mastery: float

class TherapistBehavioralDTO(MLResponseBase):
    accuracy: int
    attempted: int
    correct: int
    incorrect: int
    completion_rate: float
    accuracy_trend: List[Dict[str, Any]] # [{"session": "SES001", "accuracy": 75}]

class SpeechComparisonItem(BaseModel):
    expected: str
    recognized: str
    result: str # "✓" or "⚠"

class TherapistSpeechAnalysisDTO(MLResponseBase):
    # STT Results
    stt_results: List[SpeechComparisonItem]
    wer: float
    stt_confidence: float
    # Acoustic Results
    voice_onset_time: float
    acoustic_latency: float
    detected_peaks: int
    expected_syllables: int
    peak_count_delta: int
    intra_word_silence_ratio: float
    jitter: float
    shimmer: float
    recording_quality: str
    acoustic_confidence: float
    # Charts
    latency_trend: List[Dict[str, Any]]
    silence_trend: List[Dict[str, Any]]

class TherapistMultimodalEvidenceDTO(MLResponseBase):
    expected_text: str
    stt_text: str
    wer: float
    stt_confidence: float
    latency: float
    silence_ratio: float
    peak_delta: int
    jitter: float
    shimmer: float
    quality: str
    combined_fluency: str
    evidence_quality: str
    interpretation: str

class ShapExplanation(BaseModel):
    feature: str
    contribution: float

class TherapistProfileDTO(MLResponseBase):
    selected_pattern: str
    probabilities: Dict[str, float]
    shap_values: List[ShapExplanation]
    interpretation: str

class TherapistKnowledgeDTO(MLResponseBase):
    knowledge_components: Dict[str, float]
    mastery_trend: List[Dict[str, Any]]

class AdaptiveTimelineEvent(BaseModel):
    attempt: int
    mastery: float
    difficulty: float
    scaffold_desc: str

class TherapistAdaptiveDTO(MLResponseBase):
    learner_ability: float
    item_difficulty: float
    fatigue: float
    decision_timeline: List[Dict[str, Any]]
