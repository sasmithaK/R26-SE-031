from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional

class TelemetryData(BaseModel):
    first_touch_latency_ms: int = 0
    total_round_latency_ms: int = 0
    hesitation_count: int = 0
    misclick_count: int = 0
    audio_replay_count: int = 0
    scaffold_level_used: int = 0
    original_options_count: Optional[int] = None
    current_pair_id: Optional[str] = None
    incorrect_option_ids: Optional[List[str]] = None
    visible_option_ids: Optional[List[str]] = None
    selected_option_ids: Optional[List[str]] = None
    correct_option_ids: Optional[List[str]] = None
    supported_actions: Optional[List[str]] = None
    minimum_visible_options: int = 2
    scaffold_applications: Optional[List[Dict[str, Any]]] = None
    attempt_count: int = 0
    incorrect_attempt_count: int = 0
    first_attempt_correct: Optional[bool] = None
    correction_count: int = 0
    hint_count: int = 0
    item_role: Optional[str] = None
    equivalent_group_id: Optional[str] = None
    response_load_relation: Optional[str] = None
    target_ids: Optional[List[str]] = None
    selected_answers: Optional[List[str]] = None

class InteractionRequest(BaseModel):
    student_id: str
    session_id: str
    event_id: Optional[str] = None
    activity_id: str
    knowledge_component_id: str
    item_id: str
    is_correct: bool
    difficulty_b: float = Field(default=0.0)
    is_anchor: bool = Field(default=False)
    current_session_duration_sec: int
    fatigue_score: float = 0.0
    learner_profile: Optional[Dict[str, float]] = None
    skill_id: Optional[str] = None
    telemetry: Optional[TelemetryData] = None
    phase: str = Field(default="COMPLETE")

class NextAction(BaseModel):
    next_activity: str
    next_item: str
    difficulty: float
    difficulty_b: Optional[float] = None
    scaffold_level: int = Field(default=0)
    decision: str
    remove_option_ids: Optional[List[str]] = None
    highlight_correct: Optional[bool] = False
    next_phase: Optional[str] = "CORE"
    progress_core: Optional[int] = 0
    progress_total: Optional[int] = 5
    action_id: Optional[str] = None
    commands: List[Dict[str, Any]] = Field(default_factory=list)
    reason_codes: List[str] = Field(default_factory=list)
    policy_version: str = "C4_POLICY_V2"
    
class TutoringResponse(BaseModel):
    student_id: str
    updated_knowledge_state: Dict[str, float]
    previous_knowledge_state: Dict[str, float] = Field(default_factory=dict)
    next_action: NextAction
    response_quality: Optional[str] = None
    bkt_evidence: Optional[Dict[str, Any]] = None
    irt_evidence: Optional[Dict[str, Any]] = None
    selection_evidence: Optional[Dict[str, Any]] = None
    progression_evidence: Optional[Dict[str, Any]] = None
