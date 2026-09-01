from pydantic import BaseModel, Field
from typing import List, Optional, Literal

class AcousticFeatures(BaseModel):
    acoustic_latency_ms: float = Field(..., description="Time taken to access the word from memory (ms)")
    peak_count_delta: float = Field(..., description="|Detected Peaks - Expected Syllables|")
    intra_word_silence_ratio: float = Field(..., description="Percentage of silence inside vocalization block")
    local_jitter: float = Field(..., description="Instability in pitch/frequency")
    local_shimmer: float = Field(..., description="Instability in amplitude/loudness")

class KinematicFeatures(BaseModel):
    time_to_first_touch_ms: float = Field(..., description="Time to first interaction (ms)")
    orthographic_confusion_index: float = Field(..., description="Index measuring visual confusion (e.g. between similar letters)")
    path_efficiency_ratio: float = Field(..., description="Efficiency of the touch trajectory (0-1, higher=more direct)")  # matches comp2_kinematics.py output
    dimensionless_jerk: float = Field(..., description="Smoothness of movement, high implies hesitation")
    dwell_time_ms: float = Field(..., description="Time spent hovering or dwelling on targets (ms)")

class Demographics(BaseModel):
    age: int = Field(..., description="Age of the child")
    gender: int = Field(..., description="Gender: 0 for female, 1 for male")
    time_of_day_hour: int = Field(..., description="Hour of the day the session occurred (0-23)")

class FusionRequest(BaseModel):
    student_id: str = Field(..., description="Unique ID for the student")
    c1_audio_vector: AcousticFeatures
    c2_kinematic_vector: KinematicFeatures
    student_age_months: int = Field(..., ge=60, le=95, description="Age in months; synthetic training support is ages 5–7")
    gender: int = Field(..., ge=0, le=1, description="Legacy training covariate; not a diagnostic claim")
    time_of_day_hour: int = Field(..., ge=0, le=23)
    session_id: Optional[str] = None
    item_id: Optional[str] = None
    data_origin: Literal["synthetic", "observed", "unspecified"] = "unspecified"
    dataset_id: Optional[str] = None

class LearnerProfileOutput(BaseModel):
    class_probabilities: dict
    primary_pattern: str
    confidence: float
    modalities_used: list
    base_prevalence_risk: Optional[float] = None  # No population prevalence has been estimated.
    final_predicted_risk: float

class ShapExplanation(BaseModel):
    feature_name: str
    value: float
    shap_impact: str
    human_readable: str

class ShapExplanationsData(BaseModel):
    top_contributing_features: List[ShapExplanation]

class FusionResponse(BaseModel):
    student_id: str
    component: str = "Component_3_XAI_Fusion"
    learner_profile: LearnerProfileOutput
    shap_explanations: ShapExplanationsData
    llm_summary: Optional[str] = None
    llm_recommendations: Optional[str] = None
    model_version: str = "C3-v1.0"
    data_origin: str = "unspecified"
    dataset_id: Optional[str] = None
    validation_status: str = "synthetic_only"
    attribution_units: str = "predicted-class raw model margin; not percentage or causal effect"
