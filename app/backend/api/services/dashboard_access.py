"""Apply student ownership/active therapist relationship to every dashboard route."""
from bson import ObjectId
from fastapi import Depends, HTTPException
from dependencies import get_current_user
from shared.database import get_db

async def require_dashboard_access(student_id: str, current_user=Depends(get_current_user)):
    db = get_db()
    if not ObjectId.is_valid(student_id):
        raise HTTPException(404, "Student not found")
    student = await db.students.find_one({"_id": ObjectId(student_id)})
    if not student:
        raise HTTPException(404, "Student not found")
    user_id = str(current_user["_id"])
    if str(student.get("parent_id")) == user_id:
        return student
    if current_user.get("role") in ["specialist", "therapist"]:
        link = await db.therapist_connections.find_one({"student_id": student_id, "therapist_id": user_id, "status": "active"})
        if link:
            return student
    raise HTTPException(403, "No access to this student's dashboard")
