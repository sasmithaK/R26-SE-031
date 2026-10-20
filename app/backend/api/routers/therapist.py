from fastapi import APIRouter, Depends, HTTPException, status
from typing import Any, Dict, List
from datetime import datetime, timedelta, timezone
from bson import ObjectId
import secrets
import string

from dependencies import get_current_user
from shared.database import get_db
from schemas.therapist import ConnectionCode, TherapistConnectionResponse, ConnectSpecialistRequest
from services.dashboard_data import (
    KC_NAMES, number, stamp, setting, learner_coverage, learner_alerts, public_coverage,
)

router = APIRouter(prefix="/api/v1/auth/therapist", tags=["therapist"])


def _friendly_kc_name(kc_id: str) -> str:
    known_names = {
        "KC_VISUAL_IDENTIFICATION": "picture identification",
        "KC_VISUAL_MATCHING": "picture matching",
        "KC_VISUAL_CATEGORIZATION": "picture sorting",
        "KC_VISUAL_PATTERN": "visual patterns",
        "KC_VISUAL_MEMORY": "picture memory",
        "KC_LETTER_IDENTIFICATION": "letter identification",
        "KC_LETTER_MATCHING": "letter matching",
        "KC_PHONEME_LETTER_MAPPING": "sound-letter matching",
        "KC_LETTER_DECODING": "letter decoding",
        "KC_LETTER_MEMORY": "letter memory",
        "KC_WORD_RECOGNITION": "word recognition",
        "KC_WORD_FORMATION": "word building",
        "KC_AUDITORY_WORD_RECOGNITION": "listening to words",
        "KC_WORD_COMPLETION": "missing letters",
        "KC_WORD_SEQUENCING": "letter ordering",
        "KC_SENTENCE_COMPREHENSION": "sentence understanding",
        "KC_SENTENCE_COMPLETION": "sentence building",
        "KC_AUDITORY_SENTENCE_RECOGNITION": "listening to sentences",
        "KC_SENTENCE_SEQUENCING": "word ordering",
    }
    return known_names.get(
        kc_id,
        KC_NAMES.get(kc_id, kc_id.removeprefix("KC_").replace("_", " ").lower()),
    )


def _is_independent_completion(row: Dict[str, Any]) -> bool:
    return bool(
        row.get("first_attempt_correct") is True
        and int(row.get("scaffold_level_used") or 0) == 0
        and row.get("response_quality")
        in {None, "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS", "MASTERED"}
    )


@router.get("/dashboard-summary")
async def get_therapist_dashboard_summary(
    current_user: dict = Depends(get_current_user),
):
    """Return a real, bounded clinical worklist for the signed-in therapist.

    The endpoint intentionally avoids diagnostic labels. Review priorities are
    descriptive signals from observed learning interactions and current C4
    mastery estimates; missing evidence remains missing rather than becoming 0.
    """
    if current_user.get("role") not in ["specialist", "therapist"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only therapists can access this dashboard.",
        )

    db = get_db()
    therapist_id = str(current_user["_id"])
    connections = await db.therapist_connections.find({
        "therapist_id": therapist_id,
        "status": "active",
    }).sort("connected_at", -1).to_list(length=100)

    valid_connections = [
        connection for connection in connections
        if ObjectId.is_valid(str(connection.get("student_id", "")))
    ]
    student_ids = [str(connection["student_id"]) for connection in valid_connections]
    object_ids = [ObjectId(student_id) for student_id in student_ids]
    students = await db.students.find({"_id": {"$in": object_ids}}).to_list(length=100)
    students_by_id = {str(student["_id"]): student for student in students}

    if not student_ids:
        return {
            "generated_at": stamp(datetime.now(timezone.utc)),
            "summary": {
                "connected_learners": 0,
                "learners_with_evidence": 0,
                "review_priorities": 0,
                "observed_core_tasks": 0,
                "independent_core_tasks": 0,
                "supported_core_tasks": 0,
                "confirmation_checks": 0,
                "independent_rate": None,
            },
            "review_queue": [],
            "alerts": [],
            "learners": [],
            "recent_activity": [],
            "coverage_note": "No active learner connections are available.",
            "limitations": [
                "This dashboard summarizes observed app interactions and is not a diagnosis."
            ],
        }

    decisions = await db.adaptive_decisions.find({
        "student_id": {"$in": student_ids},
        # Superseded and retired curriculum responses remain stored for the
        # audit trail, but must not influence a current therapist worklist.
        "research_eligible": {"$ne": False},
    }).sort("_id", -1).limit(3000).to_list(length=3000)
    states = await db.knowledge_states.find({
        "student_id": {"$in": student_ids},
    }).sort("_id", -1).to_list(length=500)

    decisions_by_student: Dict[str, List[Dict[str, Any]]] = {
        student_id: [] for student_id in student_ids
    }
    for row in decisions:
        student_id = str(row.get("student_id") or "")
        if student_id in decisions_by_student:
            decisions_by_student[student_id].append(row)

    latest_state_by_student: Dict[str, Dict[str, Any]] = {}
    for row in states:
        student_id = str(row.get("student_id") or "")
        latest_state_by_student.setdefault(student_id, row)

    review_queue = []
    connected_records = []
    total_observed = 0
    total_independent = 0
    total_supported = 0
    total_confirmations = 0
    learners_with_evidence = 0

    for connection in valid_connections:
        student_id = str(connection["student_id"])
        student = students_by_id.get(student_id, {})
        first_name = str(student.get("first_name") or "Learner")
        last_name = str(student.get("last_name") or "").strip()
        student_name = f"{first_name} {last_name}".strip()
        rows = decisions_by_student.get(student_id, [])

        # Keep the latest recorded outcome per item so repeated sessions do not
        # inflate a learner's dashboard counts.
        latest_by_item: Dict[str, Dict[str, Any]] = {}
        for row in rows:
            item_id = str(row.get("current_item") or row.get("item_id") or "")
            role = str(row.get("item_role") or "CORE").upper()
            if not item_id or row.get("first_attempt_correct") is None:
                continue
            latest_by_item.setdefault(f"{role}:{item_id}", row)

        current_rows = list(latest_by_item.values())
        core_rows = [
            row for row in current_rows
            if str(row.get("item_role") or "CORE").upper() == "CORE"
        ]
        confirmation_rows = [
            row for row in current_rows
            if str(row.get("item_role") or "").upper() == "CONFIRMATION"
        ]
        independent = sum(1 for row in core_rows if _is_independent_completion(row))
        supported = len(core_rows) - independent
        observed = len(core_rows)
        if observed:
            learners_with_evidence += 1
        total_observed += observed
        total_independent += independent
        total_supported += supported
        total_confirmations += len(confirmation_rows)

        state = latest_state_by_student.get(student_id, {})
        # A KC is only flagged when it has enough observed core responses;
        # an untouched KC still sits at its prior and is not evidence.
        kc_observations: Dict[str, int] = {}
        for row in core_rows:
            kc_key = str(row.get("kc_id") or row.get("knowledge_component_id") or "")
            if kc_key:
                kc_observations[kc_key] = kc_observations.get(kc_key, 0) + 1
        min_kc_observations = setting("worklist", "min_kc_observations", default=5)
        mastery_pairs = []
        for kc_id, raw_value in (state.get("knowledge_state") or {}).items():
            mastery = number(raw_value)
            if (mastery is not None and 0 <= mastery <= 1
                    and kc_observations.get(str(kc_id), 0) >= min_kc_observations):
                mastery_pairs.append((str(kc_id), mastery))
        weakest = min(mastery_pairs, key=lambda pair: pair[1]) if mastery_pairs else None
        support_ratio = supported / observed if observed else None
        latest_observed_at = stamp(rows[0].get("timestamp")) if rows else None

        if not observed:
            review_status = "awaiting_evidence"
            review_title = "Learning evidence not available yet"
            review_reason = (
                "No completed Component 4 core tasks are recorded for this learner."
            )
            priority_rank = 2
        elif support_ratio is not None and support_ratio >= setting("worklist", "support_ratio_review", default=0.35):
            review_status = "review_suggested"
            review_title = "Frequent app support observed"
            review_reason = (
                f"Needed app support on {supported} of {observed} latest task outcomes."
            )
            priority_rank = 3
        elif weakest and weakest[1] < setting("worklist", "weak_kc_mastery", default=0.65):
            review_status = "review_suggested"
            review_title = f"Review {_friendly_kc_name(weakest[0])}"
            review_reason = (
                f"Current mastery estimate is {round(weakest[1] * 100)}% from "
                f"{kc_observations.get(weakest[0], 0)} observed responses in this area."
            )
            priority_rank = 3
        else:
            review_status = "on_track"
            review_title = "Current learning evidence is steady"
            review_reason = (
                f"Completed {independent} of {observed} latest tasks independently on the first try."
            )
            priority_rank = 1

        coverage = await learner_coverage(db, student_id, student)
        alerts = learner_alerts(coverage)
        record = {
            "student_id": student_id,
            "student_name": student_name,
            "coverage": public_coverage(coverage),
            "alerts": alerts,
            "first_name": first_name,
            "last_name": last_name,
            "grade": student.get("grade") or "Grade 1",
            "age": student.get("age"),
            "avatar_url": student.get("avatar_url"),
            "student_profile_picture": student.get("profile_picture"),
            "connection_id": str(connection.get("_id") or ""),
            "connected_at": stamp(connection.get("connected_at")),
            "status": review_status,
            "review_title": review_title,
            "review_reason": review_reason,
            "observed_tasks": observed,
            "independent_tasks": independent,
            "supported_tasks": supported,
            "confirmation_checks": len(confirmation_rows),
            "independent_rate": round(independent / observed, 4) if observed else None,
            "weakest_area": (
                {
                    "knowledge_component_id": weakest[0],
                    "name": _friendly_kc_name(weakest[0]),
                    "mastery": round(weakest[1], 4),
                    "observations": kc_observations.get(weakest[0], 0),
                }
                if weakest else None
            ),
            "last_observed_at": latest_observed_at,
            "_priority_rank": priority_rank,
        }
        connected_records.append(record)
        if review_status != "on_track":
            review_queue.append(record)

    review_queue.sort(
        key=lambda row: (
            row["_priority_rank"],
            row["supported_tasks"],
            row["observed_tasks"],
        ),
        reverse=True,
    )
    for row in connected_records + review_queue:
        row.pop("_priority_rank", None)

    recent_activity = []
    seen_activity_events = set()
    for row in decisions:
        student_id = str(row.get("student_id") or "")
        student = students_by_id.get(student_id)
        item_id = str(row.get("current_item") or row.get("item_id") or "")
        if not student or not item_id or row.get("first_attempt_correct") is None:
            continue
        event_key = (student_id, item_id, str(row.get("item_role") or "CORE"))
        if event_key in seen_activity_events:
            continue
        seen_activity_events.add(event_key)
        role = str(row.get("item_role") or "CORE").upper()
        independent = _is_independent_completion(row)
        if role == "CONFIRMATION":
            description = (
                "Completed a fresh learning check independently."
                if independent else "Completed a fresh learning check with app support."
            )
            event_type = "confirmation"
        elif independent:
            description = "Completed a task independently on the first try."
            event_type = "independent"
        else:
            description = "Completed a task after receiving app support."
            event_type = "supported"
        first_name = str(student.get("first_name") or "Learner")
        last_name = str(student.get("last_name") or "").strip()
        recent_activity.append({
            "student_id": student_id,
            "student_name": f"{first_name} {last_name}".strip(),
            "activity_id": str(row.get("activity_id") or ""),
            "item_id": item_id,
            "knowledge_component_id": row.get("kc_id"),
            "event_type": event_type,
            "description": description,
            "timestamp": stamp(row.get("timestamp")),
        })
        if len(recent_activity) >= 8:
            break

    alert_feed = []
    for record in connected_records:
        for alert in record.get("alerts", []):
            if alert.get("severity") == "watch":
                alert_feed.append({**alert, "student_id": record["student_id"],
                                   "student_name": record["student_name"]})

    return {
        "generated_at": stamp(datetime.now(timezone.utc)),
        "alerts": alert_feed,
        "summary": {
            "connected_learners": len(valid_connections),
            "learners_with_evidence": learners_with_evidence,
            "review_priorities": len(review_queue),
            "observed_core_tasks": total_observed,
            "independent_core_tasks": total_independent,
            "supported_core_tasks": total_supported,
            "confirmation_checks": total_confirmations,
            "independent_rate": (
                round(total_independent / total_observed, 4)
                if total_observed else None
            ),
        },
        "review_queue": review_queue[:6],
        "learners": connected_records,
        "recent_activity": recent_activity,
        "coverage_note": (
            f"{learners_with_evidence} of {len(valid_connections)} connected learners "
            "have recorded Component 4 learning evidence."
        ),
        "limitations": [
            "This dashboard summarizes observed app interactions and is not a diagnosis.",
            "Mastery values are model estimates and should be interpreted with task evidence.",
            "Missing measurements are unavailable, not zero.",
        ],
    }

def generate_clinic_code(length=6):
    chars = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))

@router.post("/generate-code", response_model=ConnectionCode)
async def generate_connection_code(current_user: dict = Depends(get_current_user)):
    """Generate a unique 6-digit clinic code for a therapist."""
    if current_user.get("role") != "therapist":
        raise HTTPException(status_code=403, detail="Only therapists can generate clinic codes")
        
    db = get_db()
    
    # Check if they already have an active code that hasn't expired
    existing_code = await db.clinic_codes.find_one({"therapist_id": current_user["_id"]})
    
    # Always regenerate for simplicity
    new_code = generate_clinic_code()
    expires_at = datetime.utcnow() + timedelta(hours=24)
    
    await db.clinic_codes.update_one(
        {"therapist_id": current_user["_id"]},
        {"$set": {
            "clinic_code": new_code,
            "expires_at": expires_at
        }},
        upsert=True
    )
    
    return ConnectionCode(clinic_code=new_code, expires_at=expires_at)


@router.post("/connect", response_model=TherapistConnectionResponse)
async def connect_specialist(request: ConnectSpecialistRequest, current_user: dict = Depends(get_current_user)):
    """Parent submits a clinic code to link a student to a therapist."""
    db = get_db()
    
    # 1. Find the clinic code from users collection
    therapist = await db.users.find_one({
        "role": "specialist",
        "clinic_code": request.clinic_code.upper()
    })
    
    if not therapist:
        raise HTTPException(status_code=404, detail="Invalid clinic code. Please check with your specialist.")
        
    # 2. Verify the student belongs to the current user (parent)
    try:
        student_obj_id = ObjectId(request.student_id)
    except:
        raise HTTPException(status_code=400, detail="Invalid student ID format")
        
    student = await db.students.find_one({
        "_id": student_obj_id,
        "parent_id": current_user["_id"]
    })
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found or access denied")
        
    # 3. Get therapist details (already have it)
    
    # 4. Create the connection
    connection = {
        "therapist_id": str(therapist["_id"]),
        "student_id": request.student_id,
        "parent_id": str(current_user["_id"]),
        "status": "active",
        "connected_at": datetime.utcnow()
    }
    
    # Use upsert to avoid duplicate connections
    result = await db.therapist_connections.update_one(
        {
            "therapist_id": connection["therapist_id"],
            "student_id": connection["student_id"]
        },
        {"$set": connection},
        upsert=True
    )
    
    # Fetch it back to return
    new_conn = await db.therapist_connections.find_one({
        "therapist_id": connection["therapist_id"],
        "student_id": connection["student_id"]
    })
    
    return TherapistConnectionResponse(
        id=str(new_conn["_id"]),
        therapist_id=new_conn["therapist_id"],
        student_id=new_conn["student_id"],
        student_name=student.get("first_name"),
        therapist_name=therapist.get("name"),
        clinic_name="AdaptedMind Clinic", # Could be dynamic later
        status=new_conn["status"],
        connected_at=new_conn["connected_at"]
    )


@router.get("/connections", response_model=List[TherapistConnectionResponse])
async def get_connections(current_user: dict = Depends(get_current_user)):
    """Get all connections for the current user (either parent or therapist)."""
    db = get_db()
    
    query = {}
    if current_user.get("role") in ["specialist", "therapist"]:
        query["therapist_id"] = str(current_user["_id"])
    else:
        query["parent_id"] = str(current_user["_id"])
        
    cursor = db.therapist_connections.find(query)
    connections = await cursor.to_list(length=100)
    
    result = []
    for conn in connections:
        # Populate names for the UI
        student = await db.students.find_one({"_id": ObjectId(conn["student_id"])})
        therapist = await db.users.find_one({"_id": ObjectId(conn["therapist_id"])})
        
        parent = None
        if student and "parent_id" in student:
            parent = await db.users.find_one({"_id": ObjectId(student["parent_id"])})
        
        result.append(TherapistConnectionResponse(
            id=str(conn["_id"]),
            therapist_id=conn["therapist_id"],
            student_id=conn["student_id"],
            student_name=student.get("first_name") if student else "Unknown",
            student_profile_picture=student.get("profile_picture") if student else None,
            therapist_name=therapist.get("name") if therapist else "Unknown",
            parent_name=parent.get("name") if parent else None,
            parent_email=parent.get("email") if parent else None,
            parent_profile_picture=parent.get("profile_picture_url") if parent else None,
            clinic_name="AdaptedMind Clinic",
            status=conn["status"],
            connected_at=conn["connected_at"]
        ))
        
    return result


@router.delete("/disconnect/{connection_id}")
async def disconnect_specialist(connection_id: str, current_user: dict = Depends(get_current_user)):
    """Delete a connection permanently."""
    db = get_db()
    
    # We should ensure the user has permission to delete this connection.
    # It must belong to either the parent or the therapist.
    query = {"_id": ObjectId(connection_id)}
    if current_user.get("role") in ["specialist", "therapist"]:
        query["therapist_id"] = str(current_user["_id"])
    else:
        query["parent_id"] = str(current_user["_id"])
        
    result = await db.therapist_connections.delete_one(query)
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Connection not found or permission denied.")
        
    return {"message": "Connection successfully deleted."}
