"""JWT verification and student access checks shared with the Sipsara API."""

import os
from pathlib import Path

import jwt
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from database import get_db

SERVICE_DIR = Path(__file__).resolve().parent
load_dotenv(SERVICE_DIR / ".env")
if not (os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET")):
    load_dotenv(SERVICE_DIR.parent / "api" / ".env", override=False)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(token: str = Depends(oauth2_scheme)):
    secret = os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET")
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="JWT_SECRET_KEY is not configured",
        )
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid access token")

    subject = payload.get("sub")
    if not subject or payload.get("type") == "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid access token")
    user = await get_db().users.find_one({"email": subject})
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account not found")
    return user


async def require_student_access(student_id: str, user: dict) -> None:
    from bson import ObjectId

    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid student_id")

    db = get_db()
    student = await db.students.find_one({"_id": student_oid})
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    user_id = str(user.get("_id", ""))
    if str(student.get("parent_id", "")) == user_id:
        return

    if user.get("role") in {"therapist", "specialist"}:
        connection = await db.therapist_connections.find_one({
            "student_id": student_id,
            "therapist_id": user_id,
            "status": "active",
        })
        if connection:
            return

    raise HTTPException(status_code=403, detail="This account cannot access this student")
