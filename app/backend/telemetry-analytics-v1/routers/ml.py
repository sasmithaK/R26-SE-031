"""
routers/ml.py
=============
Endpoints for collecting ground-truth clinician labels and triggering
the comparative machine learning training pipeline.
"""

from fastapi import APIRouter, HTTPException, status, Depends
from bson.objectid import ObjectId
from pydantic import BaseModel, Field

from database import get_db
from dependencies import get_current_user
from services.ml_comparative import train_and_compare

router = APIRouter(prefix="/api/v1/auth/ml", tags=["Machine Learning"])

class ClinicianLabelSubmit(BaseModel):
    label: str = Field(..., description="Must be 'Low Risk', 'Moderate Risk', or 'Needs Attention'")

@router.post("/label/{student_id}", status_code=status.HTTP_200_OK)
async def submit_clinician_label(
    student_id: str,
    req: ClinicianLabelSubmit,
    current_user: dict = Depends(get_current_user),
):
    """
    Submit a ground-truth clinical label for a student.
    Only specialists connected to the student can perform this action.
    This label is used to train the supervised ML models.
    """
    valid_labels = ["Low Risk", "Moderate Risk", "Needs Attention"]
    if req.label not in valid_labels:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid label. Must be one of {valid_labels}"
        )

    db = get_db()
    
    # Permission check: must be a specialist
    if current_user.get("role") != "specialist":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only specialists can submit ground-truth labels."
        )

    # Verify connection
    connection = await db.connections.find_one({
        "student_id": student_id,
        "specialist_id": str(current_user["_id"]),
    })
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not connected to this student."
        )

    # Upsert the label into the cognitive profile
    result = await db.cognitive_profiles.update_one(
        {"student_id": student_id},
        {"$set": {"clinician_label": req.label}},
        upsert=True
    )

    if result.matched_count == 0 and result.upserted_id is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student profile not found."
        )

    return {"message": "Clinician label saved successfully.", "label": req.label}


@router.post("/train", status_code=status.HTTP_200_OK)
async def train_models(current_user: dict = Depends(get_current_user)):
    """
    Trigger the comparative ML training pipeline.
    This fetches all cognitive profiles that have a `clinician_label`,
    extracts the feature vectors, and trains RF, XGBoost, and Stacking models.
    
    Returns the classification report (F1, Accuracy) for each model.
    """
    # Restrict to admins/specialists (for prototype, allow specialist)
    if current_user.get("role") != "specialist":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only specialists/admins can trigger model training."
        )

    db = get_db()
    
    # Find all profiles with a clinician label and a valid feature vector
    cursor = db.cognitive_profiles.find({
        "clinician_label": {"$exists": True},
        "feature_vector": {"$exists": True}
    })
    profiles = await cursor.to_list(length=5000)

    if len(profiles) < 15:
        return {
            "status": "insufficient_data",
            "message": f"Found only {len(profiles)} labelled samples. Need at least 15 for 5-Fold CV."
        }

    features_list = []
    labels_list = []
    
    for p in profiles:
        features_list.append(p["feature_vector"])
        labels_list.append(p["clinician_label"])

    try:
        # Run the training pipeline synchronously (can take a few seconds)
        results = train_and_compare(features_list, labels_list)
        return {
            "status": "success",
            "samples_trained": len(profiles),
            "results": results
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
