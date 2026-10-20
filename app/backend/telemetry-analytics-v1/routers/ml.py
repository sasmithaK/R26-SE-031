"""
routers/ml.py
=============
Research endpoint that compares candidate C1 classifiers on *professional
feedback*: patterns that connected therapists recorded while reviewing the
dashboard (``professional_feedback`` collection, written by the dashboard API).

Nothing here is used at runtime. Trained artifacts go to a staging folder and
are never hot-swapped into the live model registry.
"""

from fastapi import APIRouter, HTTPException, status, Depends

from database import get_db
from dependencies import get_current_user
from services.ml_comparative import train_and_compare, PATTERN_LABELS

router = APIRouter(prefix="/api/v1/auth/ml", tags=["Machine Learning (research)"])

MIN_LABELLED_SAMPLES = 15  # needed for stratified 5-fold cross-validation


@router.post("/train", status_code=status.HTTP_200_OK)
async def train_models(current_user: dict = Depends(get_current_user)):
    """Compare RF, XGBoost, logistic regression and stacking on expert-labelled C1 sessions."""
    if current_user.get("role") not in {"specialist", "therapist"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only specialists can trigger research model training.",
        )

    db = get_db()
    rows = await db.professional_feedback.find({
        "component": "c1",
        "professional_pattern": {"$in": list(PATTERN_LABELS)},
        "feature_snapshot": {"$exists": True},
    }).to_list(length=5000)

    if len(rows) < MIN_LABELLED_SAMPLES:
        return {
            "status": "insufficient_data",
            "labelled_samples": len(rows),
            "message": f"Need at least {MIN_LABELLED_SAMPLES} professionally labelled sessions for 5-fold CV.",
        }

    try:
        results = train_and_compare(
            [row["feature_snapshot"] for row in rows],
            [row["professional_pattern"] for row in rows],
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=type(exc).__name__)
    return {"status": "success", "samples_trained": len(rows), "results": results}
