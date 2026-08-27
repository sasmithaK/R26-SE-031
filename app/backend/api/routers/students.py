"""
routers/students.py
===================
Student management endpoints: add, list, update.

CRITICAL: Every query filters by parent_id to ensure complete data isolation
between parent accounts.
"""

from fastapi import APIRouter, HTTPException, status, Depends
from bson.objectid import ObjectId
import io
from fastapi.responses import StreamingResponse

from shared.database import get_db
from schemas.students import StudentCreate, StudentUpdate, StudentResponse, AssessmentSubmit, ProgressSyncRequest, ComprehensiveAssessmentSubmit
from services.auth_utils import verify_password
from dependencies import get_current_user

router = APIRouter(prefix="/api/v1/auth", tags=["Students"])


@router.post("/students", response_model=StudentResponse, status_code=status.HTTP_201_CREATED)
async def add_student(request: StudentCreate, current_user: dict = Depends(get_current_user)):
    """Add a new student under the authenticated parent's account."""
    # 1. Verification of parent password is no longer required

    db = get_db()
    parent_oid = current_user["_id"]  # This is always a BSON ObjectId from MongoDB

    # 2. Check if username is taken globally (Disabled for this phase per user request)
    # existing = await db.students.find_one({"username": request.username.lower()})
    # if existing:
    #     raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already exists")

    # 3. Create student document — parent_id is stored as ObjectId for consistency
    student_doc = {
        "parent_id": parent_oid,
        "first_name": request.first_name,
        "last_name": request.last_name,
        "grade": "Grade 1",  # Locked to Grade 1
        "daily_limit": request.daily_limit,
        "assessment_results": request.assessment_results,
        "comprehensive_assessment_results": request.comprehensive_assessment_results,
        "avatar_url": request.avatar_url,
        "consent_given": request.consent_given,
        "consent_parent_name": request.consent_parent_name,
        "consent_date": request.consent_date,
        "completed_activities": [],
        "activity_scores": {},
    }

    result = await db.students.insert_one(student_doc)

    return StudentResponse(
        id=str(result.inserted_id),
        first_name=request.first_name,
        last_name=request.last_name,
        grade="Grade 1",
        daily_limit=request.daily_limit,
        avatar_url=request.avatar_url,
        assessment_results=request.assessment_results,
        comprehensive_assessment_results=request.comprehensive_assessment_results,
        completed_activities=[],
        activity_scores={},
        assessment_completed=len(request.assessment_results) == 14,
    )


@router.get("/students", response_model=list[StudentResponse])
async def list_students(current_user: dict = Depends(get_current_user)):
    """List all students belonging to the authenticated parent.

    ISOLATION: Only returns students whose parent_id matches the
    current user's MongoDB _id (ObjectId).
    """
    db = get_db()
    parent_oid = current_user["_id"]

    # Query using the exact ObjectId — this guarantees isolation
    cursor = db.students.find({"parent_id": parent_oid})
    students = await cursor.to_list(length=100)

    result = []
    for s in students:
        assessment = s.get("assessment_results", [])
        result.append(StudentResponse(
            id=str(s["_id"]),
            first_name=s["first_name"],
            last_name=s["last_name"],
            grade=s.get("grade", "Grade 1"),
            daily_limit=s.get("daily_limit", "No Limit"),
            avatar_url=s.get("avatar_url"),
            assessment_results=assessment,
            comprehensive_assessment_results=s.get("comprehensive_assessment_results", {}),
            completed_activities=s.get("completed_activities", []),
            activity_scores=s.get("activity_scores", {}),
            assessment_completed=len(assessment) == 14,
        ))

    return result


@router.put("/students/{student_id}", response_model=StudentResponse)
async def update_student(student_id: str, request: StudentUpdate, current_user: dict = Depends(get_current_user)):
    """Update a student's details. Only the owning parent can update."""
    provider = current_user.get("auth_provider", "local")

    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid student ID")

    db = get_db()
    parent_oid = current_user["_id"]

    # Ensure student belongs to THIS parent
    existing_student = await db.students.find_one({"_id": obj_id, "parent_id": parent_oid})
    if not existing_student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    update_doc = {
        "first_name": request.first_name,
        "last_name": request.last_name,
        "grade": "Grade 1",  # Locked to Grade 1
        "daily_limit": request.daily_limit,
        "avatar_url": request.avatar_url,
    }

    await db.students.update_one({"_id": obj_id}, {"$set": update_doc})

    updated = await db.students.find_one({"_id": obj_id})
    assessment = updated.get("assessment_results", [])
    return StudentResponse(
        id=str(obj_id),
        first_name=request.first_name,
        last_name=request.last_name,
        grade="Grade 1",
        daily_limit=request.daily_limit,
        avatar_url=request.avatar_url,
        assessment_results=assessment,
        comprehensive_assessment_results=updated.get("comprehensive_assessment_results", {}),
        completed_activities=updated.get("completed_activities", []),
        activity_scores=updated.get("activity_scores", {}),
        assessment_completed=len(assessment) == 14,
    )


@router.patch("/students/{student_id}/assessment", response_model=StudentResponse)
async def submit_assessment(student_id: str, request: AssessmentSubmit, current_user: dict = Depends(get_current_user)):
    """Submit assessment results for an existing student. Only the owning parent can do this."""
    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid student ID")

    db = get_db()
    parent_oid = current_user["_id"]

    # Ensure student belongs to THIS parent
    existing_student = await db.students.find_one({"_id": obj_id, "parent_id": parent_oid})
    if not existing_student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    await db.students.update_one(
        {"_id": obj_id},
        {"$set": {"assessment_results": request.assessment_results}}
    )

    return StudentResponse(
        id=str(obj_id),
        first_name=existing_student["first_name"],
        last_name=existing_student["last_name"],
        grade=existing_student.get("grade", "Grade 1"),
        daily_limit=existing_student.get("daily_limit", "No Limit"),
        avatar_url=existing_student.get("avatar_url"),
        assessment_results=request.assessment_results,
        comprehensive_assessment_results=existing_student.get("comprehensive_assessment_results", {}),
        completed_activities=existing_student.get("completed_activities", []),
        activity_scores=existing_student.get("activity_scores", {}),
        assessment_completed=True,
    )


@router.patch("/students/{student_id}/progress", response_model=StudentResponse)
async def sync_progress(student_id: str, request: ProgressSyncRequest, current_user: dict = Depends(get_current_user)):
    """Sync progress data (completed activities and scores) to the database.

    ISOLATION: Only the owning parent can sync progress for their student.
    Uses $set to overwrite progress arrays — the Flutter app sends a union-merged
    payload so no data is lost on the client side before calling this.
    """
    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid student ID")

    db = get_db()
    parent_oid = current_user["_id"]

    # Ensure student belongs to THIS parent
    existing_student = await db.students.find_one({"_id": obj_id, "parent_id": parent_oid})
    if not existing_student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    await db.students.update_one(
        {"_id": obj_id},
        {"$set": {
            "completed_activities": request.completed_activities,
            "activity_scores": request.activity_scores,
        }}
    )

    assessment = existing_student.get("assessment_results", [])
    return StudentResponse(
        id=str(obj_id),
        first_name=existing_student["first_name"],
        last_name=existing_student["last_name"],
        grade=existing_student.get("grade", "Grade 1"),
        daily_limit=existing_student.get("daily_limit", "No Limit"),
        avatar_url=existing_student.get("avatar_url"),
        assessment_results=assessment,
        comprehensive_assessment_results=existing_student.get("comprehensive_assessment_results", {}),
        completed_activities=request.completed_activities,
        activity_scores=request.activity_scores,
        assessment_completed=len(assessment) == 14,
    )


@router.delete("/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student(student_id: str, current_user: dict = Depends(get_current_user)):
    """Delete a student. Only the owning parent can delete their student."""
    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid student ID")

    db = get_db()
    parent_oid = current_user["_id"]

    # Ensure student belongs to THIS parent
    existing_student = await db.students.find_one({"_id": obj_id, "parent_id": parent_oid})
    if not existing_student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    result = await db.students.delete_one({"_id": obj_id, "parent_id": parent_oid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to delete student")

    # Cascade delete therapist connections for this student
    await db.therapist_connections.delete_many({"student_id": str(obj_id)})

    return None


@router.patch("/students/{student_id}/comprehensive-assessment/{category}", response_model=StudentResponse)
async def submit_comprehensive_assessment(student_id: str, category: str, request: ComprehensiveAssessmentSubmit, current_user: dict = Depends(get_current_user)):
    """Submit comprehensive assessment results for a specific category. Only the owning parent can do this."""
    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid student ID")

    db = get_db()
    parent_oid = current_user["_id"]

    # Ensure student belongs to THIS parent
    existing_student = await db.students.find_one({"_id": obj_id, "parent_id": parent_oid})
    if not existing_student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    # Update the specific category within comprehensive_assessment_results
    update_field = f"comprehensive_assessment_results.{category}"
    await db.students.update_one(
        {"_id": obj_id},
        {"$set": {update_field: request.assessment_results}}
    )

    # Fetch updated student to return full response
    updated_student = await db.students.find_one({"_id": obj_id})
    assessment = updated_student.get("assessment_results", [])
    
    return StudentResponse(
        id=str(obj_id),
        first_name=updated_student["first_name"],
        last_name=updated_student["last_name"],
        grade=updated_student.get("grade", "Grade 1"),
        daily_limit=updated_student.get("daily_limit", "No Limit"),
        avatar_url=updated_student.get("avatar_url"),
        assessment_results=assessment,
        comprehensive_assessment_results=updated_student.get("comprehensive_assessment_results", {}),
        completed_activities=updated_student.get("completed_activities", []),
        activity_scores=updated_student.get("activity_scores", {}),
        assessment_completed=len(assessment) == 14,
    )


