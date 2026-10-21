"""Authentication and child ownership checks for C2 analysis routes."""

from bson import ObjectId
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from auth_utils import verify_token
from database import get_db

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(token: str = Depends(oauth2_scheme)):
    payload = verify_token(token)
    subject = payload.get("sub") if payload else None
    if not subject or payload.get("type") == "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid access token")
    user = await get_db().users.find_one({"email": subject})
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account not found")
    return user


async def require_owned_student(student_id: str, user: dict):
    try:
        student_oid = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid student_id")
    student = await get_db().students.find_one({"_id": student_oid})
    if not student or str(student.get("parent_id")) != str(user.get("_id")):
        raise HTTPException(status_code=403, detail="This account cannot submit data for this student")
    return student
