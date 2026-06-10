"""
shared/schemas.py
=================
Canonical Pydantic v2 schemas for all inter-service communication in the
R26-SE-031-V2 MBSV architecture.

RULE: Every service imports from this module. No service defines its own
      duplicate models. This ensures field-name consistency across the system.
"""

from __future__ import annotations

from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class EventType(str, Enum):
    TAP = "TAP"
    SWIPE = "SWIPE"
    DRAG = "DRAG"
    HESITATION = "HESITATION"
    REPLAY = "REPLAY"
    HINT = "HINT"


class Modality(str, Enum):
    VISUAL = "VISUAL"
    AUDITORY = "AUDITORY"
    KINESTHETIC = "KINESTHETIC"


class InterventionStage(int, Enum):
    NONE = 0
    STAGE1_INLINE = 1
    STAGE2_ACTIVITY = 2
    STAGE3_RTI = 3


class ActivityType(str, Enum):
    TAPPING_GAME = "TAPPING_GAME"
    BLENDING_GAME = "BLENDING_GAME"           # NEW v3.0 — PAST: Syllable Blending
    FINGER_TRACING = "FINGER_TRACING"
    TEMPLATE_SONG = "TEMPLATE_SONG"
    PICTURE_WORD_MATCH = "PICTURE_WORD_MATCH"
    SPACED_REPETITION_CARD = "SPACED_REPETITION_CARD"
    MINIMAL_PAIR = "MINIMAL_PAIR"


class ErrorType(str, Enum):
    LONG_WORD = "LONG_WORD"
    VOWEL_CONFUSION = "VOWEL_CONFUSION"
    CONSONANT_CONFUSION = "CONSONANT_CONFUSION"
    UNFAMILIAR = "UNFAMILIAR"


class LearnerType(str, Enum):
    VISUAL = "V"
    AUDITORY = "A"
    KINESTHETIC = "K"


# ---------------------------------------------------------------------------
# C1 — CBME: Telemetry Input
# ---------------------------------------------------------------------------

class TouchEvent(BaseModel):
    x: float = Field(..., description="Touch X coordinate (px)")
    y: float = Field(..., description="Touch Y coordinate (px)")
    pressure: float = Field(0.5, ge=0.0, le=1.0, description="Touch pressure [0–1]")
    timestamp_ms: int = Field(..., description="Absolute timestamp (epoch ms)")


class TelemetryPayload(BaseModel):
    """
    Sent by Flutter → C1 after each task interaction event.
    """
    student_id: str
    task_id: str
    session_id: str
    timestamp_ms: int = Field(..., description="Event timestamp (epoch ms)")

    # Touch stream
    touch_events: List[TouchEvent] = Field(default_factory=list)
    event_type: EventType = EventType.TAP

    # Pre-computed behavioral scalars (Flutter-side)
    session_latency_ms: int = Field(0, ge=0, description="Time from task shown → first interaction (ms)")
    hesitation_ms: int = Field(0, ge=0, description="Delay before answering (ms)")
    swipe_velocity: float = Field(0.0, ge=0.0, description="Swipe speed (px/s)")
    correction_rate: float = Field(0.0, ge=0.0, le=1.0, description="Backspace/error corrections / total events")
    replay_count: int = Field(0, ge=0, description="Audio replay button presses this task")
    hint_request_count: int = Field(0, ge=0, description="Hint button presses this task")

    # Optional: on-device audio features (energy-envelope only, no ASR)
    read_aloud_pause_ms: Optional[int] = Field(None, description="Max inter-word pause from energy envelope (ms)")
    syllable_rate: Optional[float] = Field(None, description="Estimated syllables per second from energy peaks")
    disfluency_count: Optional[int] = Field(None, description="Number of energy re-trigger events per word")

    # Optional: stylus trace deviation (RMS error vs. template path, px)
    stylus_deviation: Optional[float] = Field(None, description="RMS deviation from template trace (px)")

    # Optional: raw audio for Whisper transcription (base64-encoded WAV/FLAC, ≤ 30s)
    # If provided, C1 runs openai/whisper-base (language="si") → adds whisper_wer_proxy
    # feature to MBSV computation. Degrades gracefully (0.0) when absent.
    # Reference: Perera & Sumanathilaka (2025) arXiv:2510.04750 — 0.66 Sinhala STT accuracy.
    audio_base64: Optional[str] = Field(None, description="Base64-encoded audio (WAV/FLAC) for Whisper WER proxy")


# ---------------------------------------------------------------------------
# C1 — CBME: MBSV Output
# ---------------------------------------------------------------------------

class ErrorPatternVector(BaseModel):
    """
    Binary flags for the four phonological error types detected by C1
    rule-based pattern matching on correction_rate + disfluency_count.
    """
    reversal: int = Field(0, ge=0, le=1)
    omission: int = Field(0, ge=0, le=1)
    substitution: int = Field(0, ge=0, le=1)
    hesitation: int = Field(0, ge=0, le=1)

    def as_list(self) -> List[int]:
        return [self.reversal, self.omission, self.substitution, self.hesitation]


class MBSV(BaseModel):
    """
    Multi-Dimensional Behavioral Signal Vector (6 dimensions).

    Ownership:
        visual_strain_index      → C2 (AVLI) ONLY
        engagement_index         → C2 (AVLI) ONLY
        cognitive_load_index     → C3 (PLCE) ONLY
        session_fatigue_index    → C3 (PLCE) ONLY
        phonological_strain_index → C4 (IIGE) ONLY
        error_pattern_vector     → C4 (IIGE) ONLY
    """
    visual_strain_index: float = Field(..., ge=0.0, le=1.0)
    cognitive_load_index: float = Field(..., ge=0.0, le=1.0)
    phonological_strain_index: float = Field(..., ge=0.0, le=1.0)
    engagement_index: float = Field(..., ge=0.0, le=1.0)
    session_fatigue_index: float = Field(..., ge=0.0, le=1.0)
    error_resilience_index: float = Field(0.0, ge=0.0, le=1.0)  # Added to match C1 model dimensions
    error_pattern_vector: ErrorPatternVector = Field(default_factory=ErrorPatternVector)


class MBSVOutput(BaseModel):
    """Full response from POST /api/v1/telemetry and GET /api/v1/mbsv/{student_id}."""
    student_id: str
    session_id: str
    timestamp_ms: int
    mbsv: MBSV
    shap_available: bool = False
    session_outlier: bool = False


class WelfordState(BaseModel):
    """Returned by GET /api/v1/monitoring/baseline/{student_id}."""
    student_id: str
    feature_states: dict  # {feature_name: {count, mean, std}}


# ---------------------------------------------------------------------------
# C2 — AVLI: Typography + Gamification
# ---------------------------------------------------------------------------

class TypographyConfig(BaseModel):
    """
    Full UI typography configuration returned by C2 to Flutter.
    Sinhala-specific fields: diacritic_offset, glyph_padding.
    """
    font_size: float = Field(20.0, ge=18.0, le=28.0)
    font_family: str = Field("NotoSansSinhala", description="Font family name")
    letter_spacing: float = Field(2.0, ge=0.0, le=8.0)
    word_spacing: float = Field(8.0, ge=4.0, le=20.0)
    line_height: float = Field(1.6, ge=1.4, le=2.2)
    background_contrast: str = Field("WCAG_AA", description="WCAG_AA or WCAG_AAA")
    # Sinhala/Tamil Abugida-specific (research novelty)
    diacritic_offset: float = Field(0.0, ge=-4.0, le=4.0,
                                     description="Vertical pixel offset to maintain vowel sign attachment")
    glyph_padding: float = Field(0.0, ge=0.0, le=6.0,
                                  description="Horizontal padding to prevent abugida crowding")


class TypographyRequest(BaseModel):
    """Sent by Flutter → C2 to request adaptive typography."""
    student_id: str
    session_id: str
    session_number: int = Field(1, ge=1)
    visual_strain_index: float = Field(..., ge=0.0, le=1.0)
    engagement_index: float = Field(..., ge=0.0, le=1.0)
    phonological_strain_index: float = Field(0.0, ge=0.0, le=1.0)
    current_content_text: Optional[str] = Field(None, description="Sinhala text for SOVCM score computation")
    child_age_years: Optional[int] = Field(None, ge=5, le=10)


class TypographyResponse(BaseModel):
    """Full response from POST /api/v1/ui/typography."""
    student_id: str
    linucb_arm_selected: int
    typography_config: TypographyConfig
    game_mode_trigger: bool = False
    game_difficulty: int = Field(2, ge=1, le=5)


class RewardPayload(BaseModel):
    """Sent by Flutter → C2 after a reading attempt to update LinUCB."""
    student_id: str
    session_id: str
    arm_id: int
    visual_strain_before: float = Field(..., ge=0.0, le=1.0)
    visual_strain_after: float = Field(..., ge=0.0, le=1.0)
    reading_accuracy_delta: float = Field(0.0, ge=-1.0, le=1.0)


class StudentPreferences(BaseModel):
    """Stored during guardian onboarding."""
    student_id: str
    preferred_font: str = "NotoSansSinhala"
    preferred_theme: str = "Calm Blue"
    language: str = "si"  # 'si' or 'ta'
    learner_type: LearnerType = LearnerType.VISUAL


# ---------------------------------------------------------------------------
# C3 — PLCE: Mastery + Content
# ---------------------------------------------------------------------------

class MasteryUpdatePayload(BaseModel):
    """Sent by Flutter → C3 after each task response."""
    student_id: str
    session_id: str
    skill_id: str = Field(..., description="e.g. 'S3_syllable_formation'")
    is_correct: bool
    response_latency_ms: int = Field(..., ge=0)
    # MBSV dimensions consumed by C3
    cognitive_load_index: float = Field(0.5, ge=0.0, le=1.0)
    session_fatigue_index: float = Field(0.0, ge=0.0, le=1.0)


class BKTState(BaseModel):
    """Per-student, per-skill BKT state."""
    student_id: str
    skill_id: str
    p_know: float = Field(0.3, ge=0.0, le=1.0)
    p_init: float = 0.3
    p_learn: float = 0.1
    p_slip: float = 0.1
    p_guess: float = 0.2
    observations: int = 0
    last_updated_ms: int = 0


class MasteryUpdateResponse(BaseModel):
    student_id: str
    skill_id: str
    p_know_before: float
    p_know_after: float
    mastery_achieved: bool  # p_know > 0.833 (PAST criterion: 5/6 correct = 0.833)
    zpd_active: bool        # 0.45 <= p_know < 0.833


class ContentItem(BaseModel):
    item_id: str
    skill_id: str
    sinhala_text: str
    english_gloss: Optional[str] = None
    irt_difficulty_b: float = Field(0.0, description="IRT 2PL b parameter; −2.0 (easy) to +2.0 (hard)")
    audio_url: Optional[str] = None
    image_url: Optional[str] = None
    modality: Modality = Modality.VISUAL


class ContentItemResponse(BaseModel):
    """Returned by GET /api/v1/content/next/{student_id}."""
    student_id: str
    content_item: ContentItem
    bkt_p_know: float
    zpd_active: bool
    fatigue_override: bool
    mastery_vector: dict  # {skill_id: p_know} — full vector for C4


class LearnerTypePayload(BaseModel):
    student_id: str
    learner_type: LearnerType
    vark_scores: Optional[dict] = None  # {V: int, A: int, K: int}


# ---------------------------------------------------------------------------
# C4 — IIGE: Intervention
# ---------------------------------------------------------------------------

class InterventionCheckPayload(BaseModel):
    """Sent by Flutter → C4 every 5 seconds during a reading task."""
    student_id: str
    session_id: str
    current_word: str = Field(..., description="Sinhala word currently displayed")
    phonological_strain_index: float = Field(..., ge=0.0, le=1.0)
    error_pattern_vector: List[int] = Field(
        default=[0, 0, 0, 0],
        description="[reversal, omission, substitution, hesitation]"
    )
    strain_duration_ms: int = Field(0, ge=0, description="Continuous duration above threshold (ms)")
    mastery_vector: Optional[dict] = Field(None, description="From C3 /mastery endpoint")
    # NEW (v5.0): full sentence context for SinBERT classification (§2.3)
    # If provided, C4 uses SinBERT on the sentence instead of rule-based Unicode analysis on word alone.
    # Reference: Perera & Sumanathilaka (2025) arXiv:2510.04750 — 0.70 error classification accuracy.
    context_sentence: Optional[str] = Field(None, description="Full Sinhala sentence being read (for SinBERT classifier)")


class ActivityContent(BaseModel):
    """Activity-specific payload for the Flutter overlay."""
    target_text: Optional[str] = None
    target_vowel_sign: Optional[str] = None
    audio_url: Optional[str] = None
    image_urls: Optional[List[str]] = None
    song_url: Optional[str] = None
    word_pairs: Optional[List[dict]] = None


class InterventionStageResponse(BaseModel):
    """Returned by POST /api/v1/intervention/check."""
    student_id: str
    stage: InterventionStage
    # Stage 1
    syllable_segments: Optional[List[str]] = None
    # Stage 2
    error_type: Optional[ErrorType] = None
    activity_type: Optional[ActivityType] = None
    activity_difficulty: Optional[int] = Field(None, ge=1, le=5)
    activity_content: Optional[ActivityContent] = None
    sm2_quality_required: bool = False


class SM2UpdatePayload(BaseModel):
    """Sent by Flutter → C4 after an activity completes."""
    student_id: str
    skill_id: str
    activity_accuracy_pct: float = Field(..., ge=0.0, le=100.0)
    # NEW (v5.0): stroke accuracy from CNN/SSIM scorer for FINGER_TRACING activities (§3.3)
    # Maps to SM-2 quality via accuracy_to_sm2_quality() — UCSC 21% improvement as baseline.
    stroke_accuracy_pct: Optional[float] = Field(None, ge=0.0, le=100.0,
        description="CNN/SSIM stroke similarity score for FINGER_TRACING (De Silva et al. 2025)")


class SM2ScheduleResponse(BaseModel):
    """Returned by GET /api/v1/intervention/sm2/schedule/{student_id}."""
    student_id: str
    review_skills: List[str]  # skill_ids due for review today
    total_due: int


class RTIAlert(BaseModel):
    """Tier 3 escalation alert → guardian dashboard."""
    student_id: str
    skill_id: str
    word: str
    failure_count: int
    suggested_activity: str
    alert_timestamp_ms: int


# ---------------------------------------------------------------------------
# Onboarding — Guardian Intake + Observation Matrix Seeding  (v3.0)
# ---------------------------------------------------------------------------

class AtRiskFlag(str, Enum):
    """
    Computed from the Advanced Assessments Dyslexia Screening Test (guardian-answered).
    Thresholds: 0–75 → typically_developing, 76–150 → at_risk_moderate, >150 → at_risk_strong.
    Reference: Advanced Assessments Ltd (2020). Dyslexia Screening Test.
    """
    TYPICALLY_DEVELOPING = "typically_developing"
    AT_RISK_MODERATE     = "at_risk_moderate"
    AT_RISK_STRONG       = "at_risk_strong"


class ObservationLevel(str, Enum):
    """
    4-level rating scale from Lokubalasuriya et al. (2019) Observation Matrix.
    Missing (0), Unsatisfactory (1), Emerging (2), Proficient (3).
    """
    MISSING        = "Missing"
    UNSATISFACTORY = "Unsatisfactory"
    EMERGING       = "Emerging"
    PROFICIENT     = "Proficient"


class GuardianIntakePayload(BaseModel):
    """
    Guardian-answered screening questionnaire (Advanced Assessments Dyslexia
    Screening Test, Part 1 adapted for third-person child framing).
    Each key maps to a boolean: True = guardian answered 'Yes'.
    Sent by Flutter → C3 onboarding endpoint during Session 0.
    """
    student_id: str
    language: str = "si"   # 'si' | 'ta'
    # Part 1 — Scored questions
    left_right_confusion:           bool = False  # 10 pts
    tires_quickly_reading:          bool = False  # 10 pts
    mind_wanders_reading:           bool = False  # 10 pts
    many_errors_reading:            bool = False  # 20 pts
    difficulty_staying_focused:     bool = False  # 20 pts
    hard_to_remember_names:         bool = False  # 20 pts
    hard_to_pronounce_words:        bool = False  # 10 pts
    forgets_short_words_spelling:   bool = False  # 20 pts
    difficulty_spelling_unfamiliar: bool = False  # 30 pts
    difficulty_reading_unfamiliar:  bool = False  # 30 pts
    understands_words_cannot_spell: bool = False  # 20 pts
    gets_stuck_on_words:            bool = False  # 10 pts
    eyes_out_of_coordination:       bool = False  # 10 pts
    words_appear_blurred:           bool = False  # 30 pts
    # Part 2 — Symptom checklist (feeds C4 error-type priority weights)
    confusion_similar_letters:  bool = False   # → REVERSAL priority
    omission_of_words:          bool = False   # → OMISSION priority
    slow_reading_speed:         bool = False   # → LONG_WORD priority
    inaccurate_reading:         bool = False   # → CONSONANT_CONFUSION priority
    perceived_text_distortion:  bool = False   # → VOWEL_CONFUSION / visual stress → C2


class SymptomProfile(BaseModel):
    """
    Error-type priority weights derived from guardian symptom checklist (Part 2).
    Used by C4 to bias activity selection toward symptom-indicated error types
    from Session 1, before behavioral data accumulates.
    Weight scale: 0 (no priority boost) → 3 (strong boost).
    """
    reversal_priority:            int = Field(0, ge=0, le=3)
    omission_priority:            int = Field(0, ge=0, le=3)
    long_word_priority:           int = Field(0, ge=0, le=3)
    consonant_confusion_priority: int = Field(0, ge=0, le=3)
    vowel_confusion_priority:     int = Field(0, ge=0, le=3)


class AtRiskResult(BaseModel):
    """
    Output of the guardian intake scoring computation.
    Returned by POST /api/v1/onboarding/intake.
    """
    student_id: str
    at_risk_score: int
    at_risk_flag: AtRiskFlag
    symptom_profile: SymptomProfile


class ObservationMatrixSeed(BaseModel):
    """
    Observation Matrix ratings from Lokubalasuriya (2019) pilot observer,
    used to seed BKT initial p_know values more accurately than the default 0.3 prior.

    Mapping (MATRIX_TO_P_KNOW):
        Missing        → p_know = 0.05
        Unsatisfactory → p_know = 0.15
        Emerging       → p_know = 0.40
        Proficient     → p_know = 0.75

    Reference: Lokubalasuriya et al. (2019). Early Language Characteristics of
    Dyslexia in Sri Lankan Sinhala Speaking Children. 8th LLCE Conference.
    """
    student_id: str
    phonological_processing:   ObservationLevel = ObservationLevel.EMERGING
    reading_decoding:          ObservationLevel = ObservationLevel.EMERGING
    writing_copy_dictation:    ObservationLevel = ObservationLevel.EMERGING
    visual_spatial_attention:  ObservationLevel = ObservationLevel.EMERGING
    language_comprehension:    ObservationLevel = ObservationLevel.EMERGING
