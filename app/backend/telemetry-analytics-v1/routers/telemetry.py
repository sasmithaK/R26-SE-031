"""
routers/telemetry.py
====================
Telemetry ingestion and ML-powered cognitive analytics endpoints.

Endpoints:
  POST /api/v1/auth/telemetry          — Ingest an enriched telemetry session
  GET  /api/v1/auth/telemetry/{sid}    — Retrieve raw telemetry history
  GET  /api/v1/auth/telemetry/{sid}/analytics  — ML cognitive profile + risk report
"""

from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.responses import StreamingResponse
import io
from bson.objectid import ObjectId
from datetime import datetime, timezone

from database import get_db
from dependencies import get_current_user
from schemas.telemetry import TelemetrySessionSubmit
from services.ml_pipeline import generate_cognitive_profile, generate_comp2_profile
from services.ml_engine import CognitiveLoadClassifier
from services.report_generator import generate_pdf_report
from services.assessment_report_generator import generate_assessment_report

router = APIRouter(prefix="/api/v1/auth", tags=["Telemetry"])


# ---------------------------------------------------------------------------
# POST /telemetry  — Ingest enriched telemetry session
# ---------------------------------------------------------------------------

@router.post("/telemetry", status_code=status.HTTP_201_CREATED)
async def submit_telemetry(
    req: TelemetrySessionSubmit,
    current_user: dict = Depends(get_current_user),
):
    """
    Ingest a telemetry session payload after activity completion.

    The parent JWT is used to verify ownership of the student_id before
    storing any data — full data isolation is maintained.
    """
    db = get_db()

    try:
        student_oid = ObjectId(req.student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    # Ownership check — parent can only submit for their own students
    student = await db.students.find_one(
        {"_id": student_oid, "parent_id": current_user["_id"]}
    )
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found or does not belong to your account.",
        )

    # Persist to dedicated telemetry_events collection (not the students collection)
    session_doc = req.model_dump()
    session_doc["student_id"] = str(student_oid)
    session_doc["submitted_at"] = datetime.now(timezone.utc).isoformat()

    await db.telemetry_events.insert_one(session_doc)
    
    # Assess real-time cognitive load
    events_list = session_doc.get("events", [])
    cognitive_load = CognitiveLoadClassifier.classify(events_list)

    return {
        "message": "Telemetry session logged successfully.",
        "cognitive_load": cognitive_load
    }


# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}  — Raw telemetry history
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}")
async def get_telemetry(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Retrieve raw telemetry session history for a student.

    Access is granted to: (a) the owning parent, or (b) a connected specialist.
    """
    db = get_db()

    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    if current_user.get("role") == "specialist":
        connection = await db.connections.find_one({
            "student_id": student_id,
            "specialist_id": str(current_user["_id"]),
        })
        if not connection:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not connected to this student.",
            )
    else:
        student = await db.students.find_one(
            {"_id": student_oid, "parent_id": current_user["_id"]}
        )
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found.",
            )

    cursor = db.telemetry_events.find(
        {"student_id": student_id}
    ).sort("submitted_at", -1).limit(200)

    sessions = await cursor.to_list(length=200)
    for s in sessions:
        s["id"] = str(s["_id"])
        del s["_id"]

    return sessions


# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}/analytics  — ML Cognitive Profile
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}/analytics")
async def get_cognitive_analytics(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Run the ML Analytics Pipeline over all telemetry sessions for a student
    and return a structured cognitive profile including:
      - 4 cognitive index scores (0-100)
      - Dyslexia subtype risk classification
      - Personalized intervention recommendations

    Access is granted to: (a) the owning parent, or (b) a connected specialist.
    """
    db = get_db()

    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    # Permission check
    if current_user.get("role") == "specialist":
        connection = await db.connections.find_one({
            "student_id": student_id,
            "specialist_id": str(current_user["_id"]),
        })
        if not connection:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not connected to this student.",
            )
    else:
        student = await db.students.find_one(
            {"_id": student_oid, "parent_id": current_user["_id"]}
        )
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found.",
            )

    # Retrieve up to 500 most recent sessions for the pipeline
    cursor = db.telemetry_events.find(
        {"student_id": student_id}
    ).sort("submitted_at", -1).limit(500)
    sessions = await cursor.to_list(length=500)

    if not sessions:
        return {
            "student_id": student_id,
            "status": "insufficient_data",
            "message": "Complete at least one activity to generate a cognitive profile.",
            "data_points": 0,
        }

    # Fetch assessment_risk_score
    comp_results = student.get("comprehensive_assessment_results", {})
    total_yes = sum(sum(1 for a in ans if a is True) for ans in comp_results.values() if isinstance(ans, list))
    total_q = sum(len(ans) for ans in comp_results.values() if isinstance(ans, list))
    assessment_risk_score = total_yes / max(total_q, 1)

    # Run ML pipeline
    profile = generate_cognitive_profile(sessions, assessment_risk_score=assessment_risk_score)

    # Persist / upsert the latest cognitive profile for this student
    await db.cognitive_profiles.update_one(
        {"student_id": student_id},
        {
            "$set": {
                **profile,
                "student_id": student_id,
                "last_updated": datetime.now(timezone.utc).isoformat(),
            }
        },
        upsert=True,
    )

    return {
        "student_id": student_id,
        "status": "ok",
        **profile,
    }

# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}/comp2  — Component 2 Feature Vector (Integration)
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}/comp2")
async def get_comp2_analytics(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Returns the Component 2 specific visual-orthographic kinematic feature vector.
    Used for integration with Component 3 (Fusion Engine).
    """
    db = get_db()
    
    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )
        
    cursor = db.telemetry_events.find(
        {"student_id": student_id}
    ).sort("submitted_at", -1).limit(500)
    sessions = await cursor.to_list(length=500)
    
    if not sessions:
        return {
            "student_id": student_id,
            "status": "insufficient_data",
            "message": "Complete at least one visual orthographic activity."
        }
        
    comp2_profile = generate_comp2_profile(sessions)
    
    return comp2_profile

# ---------------------------------------------------------------------------
# GET /telemetry/{student_id}/report/pdf  — Clinical PDF Report
# ---------------------------------------------------------------------------

@router.get("/telemetry/{student_id}/report/pdf")
async def get_clinical_report_pdf(
    student_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Generate a formatted clinical PDF report of the student's telemetry and cognitive profile.
    """
    db = get_db()
    
    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid student ID format.",
        )

    # Permission check
    if current_user.get("role") == "specialist":
        connection = await db.connections.find_one({
            "student_id": student_id,
            "specialist_id": str(current_user["_id"]),
        })
        if not connection:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not connected to this student.",
            )
    else:
        student = await db.students.find_one(
            {"_id": student_oid, "parent_id": current_user["_id"]}
        )
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found.",
            )
            
    # Need student name
    student_name = student.get("first_name", "Unknown") if 'student' in locals() else "Student"
    if 'student' not in locals():
        student = await db.students.find_one({"_id": student_oid})
        student_name = student.get("first_name", "Unknown") if student else "Unknown"
        
    # Get profile
    profile = await db.cognitive_profiles.find_one({"student_id": student_id})
    if not profile:
        raise HTTPException(status_code=404, detail="No cognitive profile found for this student. Complete an activity first.")
        
    # Get sessions
    cursor = db.telemetry_events.find({"student_id": student_id}).sort("submitted_at", -1)
    sessions = await cursor.to_list(length=500)
    
    pdf_bytes = generate_pdf_report(student_name, profile, sessions)
    
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=Clinical_Report_{student_id}.pdf"}
    )

# ---------------------------------------------------------------------------
# GET /telemetry/export/csv  — Data Lake ML Export
# ---------------------------------------------------------------------------
import csv

@router.get("/telemetry/export/csv")
async def export_telemetry_csv(
    current_user: dict = Depends(get_current_user),
):
    """
    Export all raw telemetry flattened for Data Lake / ML training.
    In production, restrict this to Admin/Data Scientists only.
    """
    # Simple permission check
    if current_user.get("role") not in ("admin", "specialist"):
        raise HTTPException(status_code=403, detail="Not authorized to export data lake.")
        
    db = get_db()
    cursor = db.telemetry_events.find({}).sort("submitted_at", -1)
    
    # We will flatten the session and events
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Headers
    headers = [
        "session_id", "student_id", "submitted_at", "session_duration",
        "activity_name", "round_number", "is_correct", "score",
        "first_touch_latency_ms", "total_round_latency_ms", "misclick_count",
        "hesitation_count", "audio_replay_count",
        "is_abandoned", "device_os", "device_model"
    ]
    writer.writerow(headers)
    
    async for session in cursor:
        s_id = str(session["_id"])
        st_id = session.get("student_id", "")
        sub_at = session.get("submitted_at", "")
        dur = session.get("session_duration_seconds", 0)
        
        dev = session.get("device_metrics", {})
        d_os = dev.get("os", "unknown")
        d_mod = dev.get("model", "unknown")
        
        for e in session.get("events", []):
            row = [
                s_id, st_id, sub_at, dur,
                e.get("activity_name", ""),
                e.get("round_number", 0),
                e.get("is_correct", False),
                e.get("score", 0),
                e.get("first_touch_latency_ms", 0),
                e.get("total_round_latency_ms", 0),
                e.get("misclick_count", 0),
                e.get("hesitation_count", 0),
                e.get("audio_replay_count", 0),
                e.get("is_abandoned", False),
                d_os, d_mod
            ]
            writer.writerow(row)
            
            return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=sipsara_telemetry_datalake.csv"}
    )

# ---------------------------------------------------------------------------
# GET /students/{student_id}/assessment/report/pdf
# ---------------------------------------------------------------------------
@router.get("/students/{student_id}/assessment/report/pdf")
async def get_assessment_report_pdf(student_id: str, current_user: dict = Depends(get_current_user)):
    """Generate and return a PDF report of the student's comprehensive assessment answers."""
    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid student ID")

    db = get_db()
    
    # Allow either the parent or the assigned therapist to access this
    student = await db.students.find_one({"_id": obj_id})
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
        
    is_parent = student.get("parent_id") == current_user["_id"]
    is_therapist = current_user.get("role") == "therapist" and student.get("therapist_id") == current_user["_id"]
    
    if not (is_parent or is_therapist):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to view this student's assessment")
        
    pdf_bytes = generate_assessment_report(student)
    
    return StreamingResponse(
        io.BytesIO(pdf_bytes), 
        media_type="application/pdf", 
        headers={"Content-Disposition": f"attachment; filename=Assessment_Report_{student_id}.pdf"}
    )


