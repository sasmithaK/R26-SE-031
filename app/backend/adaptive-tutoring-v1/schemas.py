from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional

class InteractionRequest(BaseModel):
    student_id: str
    session_id: str
    activity_id: str
    knowledge_component_id: str
    item_id: str
    is_correct: bool
    difficulty_b: float = Field(default=0.0)
    is_anchor: bool = Field(default=False)
    current_session_duration_sec: int
    fatigue_score: float = 0.0
    learner_profile: Optional[Dict[str, float]] = None

class NextAction(BaseModel):
    next_activity: str
    next_item: str
    difficulty: float
    scaffold_level: int = Field(default=0)
    decision: str
    
class TutoringResponse(BaseModel):
    student_id: str
    updated_knowledge_state: Dict[str, float]
    previous_knowledge_state: Dict[str, float] = Field(default_factory=dict)
    next_action: NextAction
