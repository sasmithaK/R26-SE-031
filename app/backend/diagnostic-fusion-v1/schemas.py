from pydantic import BaseModel, Field
from typing import List, Optional

class AcousticFeatures(BaseModel):
    acoustic_latency_ms: float = Field(..., description="Time taken to access the word from memory (ms)")
    peak_count_delta: float = Field(..., description="|Detected Peaks - Expected Syllables|")
    intra_word_silence_ratio: float = Field(..., description="Percentage of silence inside vocalization block")
    local_jitter: float = Field(..., description="Instability in pitch/frequency")
    local_shimmer: float = Field(..., description="Instability in amplitude/loudness")

class KinematicFeatures(BaseModel):
    time_to_first_touch_ms: float = Field(..., description="Time to first interaction (ms)")
    orthographic_confusion_index: float = Field(..., description="Index measuring visual confusion (e.g. between similar letters)")
    path_efficiency: float = Field(..., description="Efficiency of the touch trajectory")
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
    student_age_months: int = Field(..., description="Crucial baseline anchor")

class ClinicalAssessment(BaseModel):
    base_prevalence_risk: float
    final_predicted_risk: float
    predicted_subtype: str
    subtype_class_id: int

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
    risk_score: float
    clinical_subtype: str
    shap_explanations: ShapExplanationsData
