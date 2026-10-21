from pydantic import BaseModel, EmailStr, Field
from typing import Optional

class UserCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=8, description="Password must be at least 8 characters long")
    role: Optional[str] = "student"

class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class TokenRefreshRequest(BaseModel):
    refresh_token: str
class UserResponse(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: str

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8)

class StudentCreate(BaseModel):
    first_name: str
    last_name: str
    username: str
    grade: str
    daily_limit: str
    parent_password: str
    assessment_results: list[bool]
    avatar_url: Optional[str] = None

class StudentUpdate(BaseModel):
    first_name: str
    last_name: str
    username: str
    grade: str
    daily_limit: str
    parent_password: str
    avatar_url: Optional[str] = None

class StudentResponse(BaseModel):
    id: str
    first_name: str
    last_name: str
    username: str
    grade: str
    daily_limit: str
    avatar_url: Optional[str] = None
