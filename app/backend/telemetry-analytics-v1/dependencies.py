from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from database import get_db
from auth_utils import verify_token
from bson import ObjectId

# Note: The token URL is meaningless here because this service doesn't issue tokens.
# It just reads the Bearer token from the header.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Decode JWT and return the authenticated user document from MongoDB."""
    decoded = verify_token(token)
    if not decoded or decoded.get("type") == "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    db = get_db()
    user = await db.users.find_one({"email": decoded["sub"]})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return user


async def require_owned_student(student_id: str, user: dict):
    """Allow only a parent or actively connected therapist to access a learner."""
    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid student_id")
    db = get_db()
    student = await db.students.find_one({"_id": student_oid})
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if str(student.get("parent_id")) == str(user.get("_id")):
        return student
    if user.get("role") in {"therapist", "specialist"}:
        connection = await db.therapist_connections.find_one({
            "student_id": student_id,
            "therapist_id": str(user.get("_id")),
            "status": "active",
        })
        if connection:
            return student
    raise HTTPException(status_code=403, detail="This account cannot access this student")
