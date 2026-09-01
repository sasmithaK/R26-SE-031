from pydantic import BaseModel, Field
from typing import Optional, List


class TouchPoint(BaseModel):
    """Legacy: A single normalized screen touch coordinate captured during a round."""
    x_ratio: float = Field(..., ge=0.0, le=1.0, description="Horizontal position as fraction of screen width")
    y_ratio: float = Field(..., ge=0.0, le=1.0, description="Vertical position as fraction of screen height")
    timestamp_ms: int = Field(..., ge=0, description="Milliseconds elapsed since round start")
    type: Optional[str] = Field(default="down", description="Type of touch event: down, move, or up")

class TouchStreamPoint(BaseModel):
    """Component 2: Standardized stream point with actions."""
    t: int = Field(..., ge=0)
    x: float = Field(..., ge=0.0, le=1.0)
    y: float = Field(..., ge=0.0, le=1.0)
    type: str = Field(..., description="DOWN, MOVE, or UP")


class TelemetryEvent(BaseModel):
    """
    Enriched round-level telemetry event capturing rich cognitive and motor metrics
    for ML-based dyslexia / dyspraxia profile generation.
    """
    event_id: str = Field(..., description="Unique identifier for this specific event")
    skill_id: str = Field(default="unknown", description="Skill ID being practiced")
    activity_id: str = Field(default="unknown", description="Activity ID being practiced")
    item_id: str = Field(default="unknown", description="Specific curriculum item ID, e.g., S2A1R01")
    item_version: int = Field(default=1)
    knowledge_component_id: str = Field(default="KC_UNKNOWN")
    prompt_modality: str = Field(default="visual")
    response_modality: str = Field(default="tap")
    research_role: str = Field(default="primary")
    difficulty_label: str = Field(default="medium")
    difficulty_b: float = Field(default=0.0)
    is_anchor: bool = Field(default=False)
    targets: List[str] = Field(default_factory=list)
    selected_answers: List[str] = Field(default_factory=list)
    error_type: str = Field(default="unknown_error")

    activity_name: str
    round_number: int = Field(..., ge=1)
    is_correct: bool
    score: int = Field(default=0, ge=0, le=100)

    # --- Attempt & Accuracy Tracking ---
    attempt_count: int = Field(default=1, ge=1)
    incorrect_attempt_count: int = Field(default=0, ge=0)
    first_attempt_correct: Optional[bool] = Field(default=None)
    final_correct: bool = Field(default=False)
    time_to_first_response_ms: int = Field(default=0, ge=0)
    time_to_correct_ms: int = Field(default=0, ge=0)

    # --- Dyslexia Cognitive Indicators ---
    first_touch_latency_ms: int = Field(
        default=0, ge=0,
        description="Time from round display to first screen touch (visual processing speed)"
    )
    total_round_latency_ms: int = Field(
        default=0, ge=0,
        description="Total time taken for the complete round"
    )
    misclick_count: int = Field(
        default=0, ge=0,
        description="Taps outside interactive target areas (motor precision)"
    )
    hesitation_count: int = Field(
        default=0, ge=0,
        description="Number of pauses > 2s without touch input (reading difficulty indicator)"
    )
    correction_count: int = Field(
        default=0, ge=0,
        description="Number of self-corrections made during the round"
    )
    hint_count: int = Field(
        default=0, ge=0,
        description="Number of hints requested or given during the round"
    )

    # --- Motor Analysis ---
    touch_path: List[TouchPoint] = Field(
        default_factory=list,
        description="Legacy: Normalized touch coordinate path for drag-velocity & tremor analysis"
    )
    
    # --- Component 2: Visual-Orthographic Engine ---
    target_stimulus: Optional[str] = None
    selected_stimulus: Optional[str] = None
    stimulus_rendered_ts: Optional[int] = None
    screen_width_px: Optional[int] = Field(default=None, description="Screen width in pixels for normalization")
    screen_height_px: Optional[int] = Field(default=None, description="Screen height in pixels for normalization")
    target_id: Optional[str] = Field(default=None, description="E.g., ba_letter")
    distractor_matrix: Optional[dict] = Field(default_factory=dict, description="E.g., {'visual': 'da_letter', 'phonetic': 'bha_letter'}")
    touch_stream: List[TouchStreamPoint] = Field(
        default_factory=list,
        description="Component 2: Action-based touch stream for deterministic kinematic extraction."
    )

    # --- Behavior Proxies ---
    audio_replay_count: int = Field(
        default=0, ge=0,
        description="Number of times auditory instructions were replayed"
    )
    is_abandoned: bool = Field(
        default=False,
        description="True if the child quit the round before finishing"
    )

    # --- Legacy compatibility (optional) ---
    timestamp: Optional[str] = None
    time_since_start_ms: Optional[int] = None


class TelemetrySessionSubmit(BaseModel):
    """Full session payload submitted after activity completion."""
    student_id: str
    session_id: str = Field(..., description="Unique identifier for the session instance")
    skill_id: str = Field(default="unknown", description="Skill ID being practiced")
    activity_id: str = Field(default="unknown", description="Activity ID being practiced")
    session_number: int = Field(default=1, ge=1)
    session_duration_seconds: int = Field(..., ge=0)
    events: List[TelemetryEvent]
    device_metrics: Optional[dict] = Field(default_factory=dict, description="Hardware metrics like OS and Model used for normalisation")
