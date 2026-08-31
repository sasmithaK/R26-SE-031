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

class InteractionRequest(BaseModel):
    student_id: str
    session_id: str
    activity_id: str
    knowledge_component_id: str
    item_id: str
    is_correct: bool
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
    scaffold_level: int = Field(default=0)
    decision: str
    remove_option_ids: Optional[List[str]] = None
    highlight_correct: Optional[bool] = False
    next_phase: Optional[str] = "CORE"
    progress_core: Optional[int] = 0
    progress_total: Optional[int] = 5
    
class TutoringResponse(BaseModel):
    student_id: str
    updated_knowledge_state: Dict[str, float]
    next_action: NextAction
    response_quality: Optional[str] = None
    bkt_evidence: Optional[Dict[str, Any]] = None
    irt_evidence: Optional[Dict[str, Any]] = None
    selection_evidence: Optional[Dict[str, Any]] = None
    progression_evidence: Optional[Dict[str, Any]] = None
