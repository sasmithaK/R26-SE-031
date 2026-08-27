from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional

class InteractionRequest(BaseModel):
    student_id: str
    knowledge_component_id: str
    is_correct: bool
    current_session_duration_sec: int

class NextAction(BaseModel):
    next_kc_id: str
    scaffold_level: int = Field(default=0, description="0 = None, 1 = Color hints, 2 = Audio repeats")
    terminate_session: bool

class TutoringResponse(BaseModel):
    student_id: str
    updated_knowledge_state: Dict[str, float]
    next_action: NextAction
