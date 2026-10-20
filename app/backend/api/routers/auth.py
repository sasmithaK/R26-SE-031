"""
routers/auth.py
===============
Authentication endpoints: signup, login, refresh, me, change-password, verify-password.
"""

import secrets
from fastapi import UploadFile, File
from fastapi.responses import StreamingResponse
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
from bson import ObjectId
from fastapi import APIRouter, HTTPException, status, Depends, Request, BackgroundTasks
from email_validator import validate_email, EmailNotValidError
from datetime import datetime, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address

from shared.database import get_db
from schemas.auth import (
    UserCreate, UserUpdate, UserLogin, Token, TokenRefreshRequest,
    UserResponse, ChangePasswordRequest, VerifyPasswordRequest, GoogleLoginRequest, MicrosoftLoginRequest,
    RequestEmailUpdate, VerifyEmailUpdate, ToggleLoginAlertsRequest
)
from services.auth_utils import (
    get_password_hash, verify_password,
    create_access_token, create_refresh_token, verify_token, verify_google_token, verify_microsoft_token,
    generate_otp, send_otp_email, send_login_alert_email
)
from dependencies import get_current_user

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])
limiter = Limiter(key_func=get_remote_address)


@router.post("/signup", status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def signup(request: Request, user: UserCreate, background_tasks: BackgroundTasks):
    """Register a new parent user and send an OTP for email verification."""
    db = get_db()

    try:
        valid = validate_email(user.email, check_deliverability=False)
        email = valid.normalized
    except EmailNotValidError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid email: {str(e)}",
        )

    # Check if user already exists
    existing = await db.users.find_one({"email": email})
    if existing:
        if existing.get("is_verified") == False:
            # Resend OTP
            otp = generate_otp()
            await db.otps.update_one(
                {"email": email},
                {"$set": {"otp": otp, "expires_at": datetime.utcnow() + timedelta(minutes=10), "created_at": datetime.utcnow()}},
                upsert=True
            )
            background_tasks.add_task(send_otp_email, email.lower(), otp)
            return {"message": "User exists but unverified. A new OTP has been sent."}
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A verified user with this email already exists.",
            )

    # Create new unverified user record in pending state
    hashed_password = get_password_hash(user.password)
    otp = generate_otp()

    pending_user = {
        "name": user.name,
        "hashed_password": hashed_password,
        "role": user.role or "parent",
        "auth_provider": "local",
        "specialization": user.specialization,
        "clinic_name": user.clinic_name,
    }

    # Store OTP and pending user info
    await db.otps.update_one(
        {"email": email},
        {"$set": {
            "otp": otp, 
            "expires_at": datetime.utcnow() + timedelta(minutes=10),
            "pending_user": pending_user
        }},
        upsert=True
    )
    
    # Send email in background so API is instantly fast
    background_tasks.add_task(send_otp_email, email.lower(), otp)

    # We return a message instead of tokens, because they need to verify first
    return {"message": "OTP sent. Please verify your email to complete registration."}

from schemas.auth import VerifyEmailRequest


@router.delete("/cancel-signup/{email}")
async def cancel_signup(email: str):
    db = get_db()
    email = email.lower()
    user = await db.users.find_one({"email": email})
    if user and user.get("is_verified"):
        return {"status": "already verified"}
    await db.otps.delete_one({"email": email})
    return {"status": "deleted"}

@router.post("/verify-email", response_model=Token)

@limiter.limit("5/minute")
async def verify_email(request: Request, req: VerifyEmailRequest, background_tasks: BackgroundTasks):
    """Verify email via OTP and return JWT tokens on success."""
    db = get_db()
    email = req.email.lower()
    db = get_db()
    
    # Find OTP normally
    otp_record = await db.otps.find_one({"email": email, "otp": req.otp})
    if not otp_record:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP.")
        
    from datetime import datetime
    if datetime.utcnow() > otp_record["expires_at"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP has expired.")
        
    # Check if this OTP contains pending user data (meaning it's a Signup Verification)
    pending = otp_record.get("pending_user")
    
    if pending:
        # Create the user permanently in the DB now that they verified!
        user_doc = {
            "name": pending["name"],
            "email": email,
            "hashed_password": pending["hashed_password"],
            "role": pending["role"],
            "is_verified": True
        }
        
        if pending.get("specialization"):
            user_doc["specialization"] = pending["specialization"]
        if pending.get("clinic_name"):
            user_doc["clinic_name"] = pending["clinic_name"]
        
        if pending.get("role") == "specialist":
            import string
            # Generate a professional 6-character alphanumeric clinic code
            user_doc["clinic_code"] = "".join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
        
        # Upsert just in case they were somehow inserted but unverified before we changed architecture
        await db.users.update_one(
            {"email": email},
            {"$set": user_doc},
            upsert=True
        )
        user_doc = await db.users.find_one({"email": email})
    else:
        # Fallback for old unverified accounts doing a standard verify
        user_doc = await db.users.find_one_and_update(
            {"email": email},
            {"$set": {"is_verified": True}},
            return_document=True
        )
    
    if not user_doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
        
    # Delete OTP
    await db.otps.delete_one({"email": email})
    
    # Issue Tokens
    token_data = {
        "sub": user_doc["email"],
        "role": user_doc.get("role", "parent"),
        "id": str(user_doc["_id"]),
    }
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)


    await _handle_login_alert(db, user_doc, request, background_tasks, None, None)
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")



async def _handle_login_alert(db, user_doc, request: Request, background_tasks: BackgroundTasks, device_id: str = None, device_name: str = None):
    # Try to get the real IP if behind a proxy like Render
    forwarded_for = request.headers.get("x-forwarded-for")
    ip_address = forwarded_for.split(",")[0].strip() if forwarded_for else (request.client.host if request.client else "Unknown IP")

    # Fallback to User-Agent if device_name not provided by frontend
    if not device_name:
        device_name = request.headers.get("user-agent", "Unknown Device")
        
    if not device_id:
        # Fallback to legacy IP-based logic for older app versions
        last_ip = user_doc.get("last_login_ip")
        alerts_enabled = user_doc.get("login_alerts_enabled", True)
        
        if alerts_enabled and last_ip and last_ip != ip_address:
            now_str = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
            background_tasks.add_task(send_login_alert_email, user_doc["email"], ip_address, device_name, now_str)
            
        if last_ip != ip_address:
            await db.users.update_one({"_id": user_doc["_id"]}, {"$set": {"last_login_ip": ip_address}})
        return

    # Modern Device-Based Logic
    alerts_enabled = user_doc.get("login_alerts_enabled", True)
    known_devices = user_doc.get("known_devices", [])
    
    # Check if this device is recognized
    is_known = any(d.get("device_id") == device_id for d in known_devices)
    
    if not is_known:
        if alerts_enabled and len(known_devices) > 0:
            now_str = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
            background_tasks.add_task(send_login_alert_email, user_doc["email"], ip_address, device_name, now_str)
            
        # Add to known devices
        new_device_entry = {
            "device_id": device_id,
            "device_name": device_name,
            "first_seen": datetime.utcnow()
        }
        await db.users.update_one(
            {"_id": user_doc["_id"]},
            {"$push": {"known_devices": new_device_entry}, "$set": {"last_login_ip": ip_address}}
        )
    else:
        # Update last_login_ip anyway
        await db.users.update_one({"_id": user_doc["_id"]}, {"$set": {"last_login_ip": ip_address}})



from schemas.auth import ForgotPasswordRequest
@router.post("/resend-otp")
async def resend_otp(request: Request, req: ForgotPasswordRequest, background_tasks: BackgroundTasks):
    """Resend OTP for either signup or forgot password."""
    email = req.email.lower()
    db = get_db()
    otp_record = await db.otps.find_one({"email": email})
    if not otp_record:
        # If no record exists, just return success to avoid email enumeration
        return {"message": "OTP resent successfully."}
        
    from services.auth_utils import generate_otp, send_otp_email
    from datetime import datetime, timedelta
    otp = generate_otp()
    
    await db.otps.update_one(
        {"email": email},
        {"$set": {"otp": otp, "expires_at": datetime.utcnow() + timedelta(minutes=10)}}
    )
    
    background_tasks.add_task(send_otp_email, email, otp)
    return {"message": "OTP resent successfully."}

@router.post("/login", response_model=Token)
@limiter.limit("10/minute")
async def login(request: Request, user: UserLogin, background_tasks: BackgroundTasks):
    """Authenticate and return JWT tokens."""
    db = get_db()

    user_doc = await db.users.find_one({"email": user.email.lower()})
    if not user_doc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    if user_doc.get("role") != user.role:
        expected = "Therapist" if user_doc.get("role") == "specialist" else "Parent"
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"This email is registered as a {expected}. Please select {expected} to log in."
        )

    if user_doc.get("auth_provider", "local") != "local" or not user_doc.get("hashed_password"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This account uses social login (Google/Microsoft). Please sign in using your OAuth provider.",
        )

    if not verify_password(user.password, user_doc["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    if user_doc.get("is_verified") == False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Please verify your email address before logging in.",
        )

    token_data = {
        "sub": user_doc["email"],
        "role": user_doc.get("role", "parent"),
        "id": str(user_doc["_id"]),
    }
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)


    await _handle_login_alert(db, user_doc, request, background_tasks, None, None)
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")

@router.post("/google", response_model=Token)
@limiter.limit("10/minute")
async def google_login(request: Request, login_req: GoogleLoginRequest, background_tasks: BackgroundTasks):
    """Authenticate via Google ID token and return JWT tokens."""
    db = get_db()

    # Verify the token with Google
    idinfo = verify_google_token(login_req.id_token)
    if not idinfo:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = idinfo.get("email", "").lower()
    name = idinfo.get("name", "User")
    
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google token did not contain an email address",
        )

    # Check if user already exists
    user_doc = await db.users.find_one({"email": email})
    
    if user_doc and user_doc.get("role") != login_req.role:
        expected = "Therapist" if user_doc.get("role") == "specialist" else "Parent"
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"This email is registered as a {expected}. Please select {expected} to log in."
        )
        
    if user_doc and user_doc.get("role") != login_req.role:
        expected = "Therapist" if user_doc.get("role") == "specialist" else "Parent"
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"This email is registered as a {expected}. Please select {expected} to log in."
        )
        
    if not user_doc:
        # Implicitly sign up the user
        user_doc = {
            "name": name,
            "email": email,
            "hashed_password": None,
            "role": login_req.role or "parent",
            "auth_provider": "google",
        }
        if login_req.specialization:
            user_doc["specialization"] = login_req.specialization
        if login_req.clinic_name:
            user_doc["clinic_name"] = login_req.clinic_name
            
        if user_doc["role"] == "specialist":
            import string
            user_doc["clinic_code"] = "".join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
            
        result = await db.users.insert_one(user_doc)
        user_id = str(result.inserted_id)
    else:
        user_id = str(user_doc["_id"])

    token_data = {
        "sub": email,
        "role": user_doc.get("role", "parent"),
        "id": user_id,
    }
    
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)


    await _handle_login_alert(db, user_doc, request, background_tasks, login_req.device_id, login_req.device_name)
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")

@router.post("/microsoft", response_model=Token)
@limiter.limit("10/minute")
async def microsoft_login(request: Request, login_req: MicrosoftLoginRequest, background_tasks: BackgroundTasks):
    """Authenticate via Microsoft Access token and return JWT tokens."""
    db = get_db()

    # Verify the token with Microsoft Graph API
    user_info = verify_microsoft_token(login_req.access_token)
    if not user_info:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Microsoft token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = user_info.get("email", "").lower()
    name = user_info.get("name", "User")
    
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Microsoft token did not contain an email address",
        )

    # Check if user already exists
    user_doc = await db.users.find_one({"email": email})
    
    if user_doc and user_doc.get("role") != login_req.role:
        expected = "Therapist" if user_doc.get("role") == "specialist" else "Parent"
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"This email is registered as a {expected}. Please select {expected} to log in."
        )
        
    if user_doc and user_doc.get("role") != login_req.role:
        expected = "Therapist" if user_doc.get("role") == "specialist" else "Parent"
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"This email is registered as a {expected}. Please select {expected} to log in."
        )
        
    if not user_doc:
        # Implicitly sign up the user
        user_doc = {
            "name": name,
            "email": email,
            "hashed_password": None,
            "role": login_req.role or "parent",
            "auth_provider": "microsoft",
        }
        if login_req.specialization:
            user_doc["specialization"] = login_req.specialization
        if login_req.clinic_name:
            user_doc["clinic_name"] = login_req.clinic_name
            
        if user_doc["role"] == "specialist":
            import string
            user_doc["clinic_code"] = "".join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
            
        result = await db.users.insert_one(user_doc)
        user_id = str(result.inserted_id)
    else:
        user_id = str(user_doc["_id"])

    token_data = {
        "sub": email,
        "role": user_doc.get("role", "parent"),
        "id": user_id,
    }
    
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)


    await _handle_login_alert(db, user_doc, request, background_tasks, login_req.device_id, login_req.device_name)
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")

@router.post("/refresh", response_model=Token)
@limiter.limit("10/minute")
async def refresh_token_endpoint(request: Request, token_req: TokenRefreshRequest, background_tasks: BackgroundTasks):
    """Exchange a refresh token for new access + refresh tokens."""
    decoded = verify_token(token_req.refresh_token)
    if not decoded or decoded.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    # Re-read the account before rotating credentials.  Apart from preventing
    # deleted accounts from renewing a session, this supplies the authoritative
    # role/id instead of trusting claims from a month-long refresh token.
    db = get_db()
    user_doc = await db.users.find_one({"email": decoded["sub"]})
    if not user_doc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    token_data = {
        "sub": user_doc["email"],
        "role": user_doc.get("role", "parent"),
        "id": str(user_doc["_id"]),
    }
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)

    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: dict = Depends(get_current_user)):
    """Return the authenticated user's profile."""
    return UserResponse(
        id=str(current_user["_id"]),
        name=current_user["name"],
        email=current_user["email"],
        role=current_user.get("role", "parent"),
        login_alerts_enabled=current_user.get("login_alerts_enabled", True),
        profile_picture_url=current_user.get("profile_picture_url"),
        clinic_code=current_user.get("clinic_code"),
        specialization=current_user.get("specialization"),
        clinic_name=current_user.get("clinic_name"),
    )
@router.put("/me", response_model=UserResponse)
async def update_me(request: UserUpdate, current_user: dict = Depends(get_current_user)):
    """Update the authenticated user's profile (name only)."""
    db = get_db()
    
    update_data = {}
    if request.name is not None:
        update_data["name"] = request.name.strip()
    if request.specialization is not None:
        update_data["specialization"] = request.specialization.strip()
    if request.clinic_name is not None:
        update_data["clinic_name"] = request.clinic_name.strip()
        
    if update_data:
        user_doc = await db.users.find_one_and_update(
            {"_id": current_user["_id"]},
            {"$set": update_data},
            return_document=True
        )
    else:
        user_doc = current_user

    return UserResponse(
        id=str(user_doc["_id"]),
        name=user_doc["name"],
        email=user_doc["email"],
        role=user_doc.get("role", "parent"),
        login_alerts_enabled=user_doc.get("login_alerts_enabled", True),
        profile_picture_url=user_doc.get("profile_picture_url"),
        clinic_code=user_doc.get("clinic_code"),
        specialization=user_doc.get("specialization"),
        clinic_name=user_doc.get("clinic_name"),
    )


@router.post("/request-email-update")
async def request_email_update(req: RequestEmailUpdate, background_tasks: BackgroundTasks, current_user: dict = Depends(get_current_user)):
    """Request an email update by sending an OTP to the new email."""
    db = get_db()
    new_email = req.new_email.strip().lower()

    if new_email == current_user["email"]:
        raise HTTPException(status_code=400, detail="New email cannot be the same as current email.")

    # Check if new email is already in use
    existing_user = await db.users.find_one({"email": new_email})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email is already registered")

    # Generate OTP
    otp = generate_otp()

    # Save OTP to db.otps (associated with the NEW email)
    await db.otps.update_one(
        {"email": new_email},
        {"$set": {"otp": otp, "expires_at": datetime.utcnow() + timedelta(minutes=10), "created_at": datetime.utcnow()}},
        upsert=True
    )

    # Send OTP email
    background_tasks.add_task(send_otp_email, new_email, otp)
    return {"message": "OTP sent to new email"}


@router.post("/verify-email-update", response_model=Token)
async def verify_email_update(req: VerifyEmailUpdate, current_user: dict = Depends(get_current_user)):
    """Verify OTP and update email."""
    db = get_db()
    new_email = req.new_email.strip().lower()

    otp_record = await db.otps.find_one({"email": new_email, "otp": req.otp})
    if not otp_record:
        raise HTTPException(status_code=400, detail="Invalid OTP")

    if datetime.utcnow() > otp_record["expires_at"]:
        raise HTTPException(status_code=400, detail="OTP expired")

    # Update user's email
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"email": new_email}}
    )

    # Clean up OTP
    await db.otps.delete_one({"email": new_email})

    # Issue NEW Tokens with the updated email
    token_data = {
        "sub": new_email,
        "role": current_user.get("role", "parent"),
        "id": str(current_user["_id"]),
    }
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)


    await _handle_login_alert(db, user_doc, request, background_tasks, None, None)
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")


@router.post("/change-password")
async def change_password(request: ChangePasswordRequest, current_user: dict = Depends(get_current_user)):
    """Change the authenticated user's password."""
    if not verify_password(request.old_password, current_user["hashed_password"]):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect old password")

    if request.old_password == request.new_password:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="New password cannot be the same as the current password")

    hashed_new = get_password_hash(request.new_password)

    db = get_db()
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"hashed_password": hashed_new}},
    )

    return {"status": "success", "message": "Password changed successfully"}


@router.post("/verify-password")
async def verify_user_password(request: VerifyPasswordRequest, current_user: dict = Depends(get_current_user)):
    """Verify the authenticated user's password (e.g. before sensitive actions)."""
    provider = current_user.get("auth_provider", "local")
    if provider in ["google", "microsoft"] or not current_user.get("hashed_password"):
        return {"status": "success", "message": "Social user authenticated"}

    if not verify_password(request.password, current_user["hashed_password"]):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect password")
    return {"status": "success", "message": "Password is correct"}

# import moved to top
from schemas.auth import ForgotPasswordRequest, ResetPasswordRequest

@router.post("/forgot-password")
@limiter.limit("3/minute")
async def forgot_password(request: Request, req: ForgotPasswordRequest):
    """Initiate password reset process."""
    db = get_db()
    email = req.email.lower()
    db = get_db()
    
    user = await db.users.find_one({"email": email})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with this email address."
        )
    # Check if this is an OAuth account
    hashed_pwd = user.get("hashed_password", "")
    if user.get("auth_provider", "local") != "local" or not hashed_pwd:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You signed up using a social account (Google/Microsoft). Please log in using that button.",
        )
        
    # Generate OTP
    from services.auth_utils import generate_otp, send_otp_email
    otp = generate_otp()
    
    # Store OTP in DB with 10 min expiration
    await db.otps.update_one(
        {"email": email},
        {"$set": {"otp": otp, "expires_at": datetime.utcnow() + timedelta(minutes=10)}},
        upsert=True
    )
    
    # Send email (prints to console currently)
    send_otp_email(email, otp)
    
    return {"message": "If that email exists, an OTP has been sent."}


@router.post("/reset-password")
@limiter.limit("5/minute")
async def reset_password(request: Request, req: ResetPasswordRequest):
    """Reset the password using the OTP."""
    db = get_db()
    email = req.email.lower()
    db = get_db()
    
    # Find OTP normally
    otp_record = await db.otps.find_one({"email": email, "otp": req.otp})
    if not otp_record:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP.")
        
    if datetime.utcnow() > otp_record["expires_at"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP has expired.")
        
    # Update Password and mark as verified (since they proved ownership via OTP)
    new_hashed = get_password_hash(req.new_password)
    await db.users.update_one(
        {"email": email},
        {"$set": {
            "hashed_password": new_hashed,
            "is_verified": True
        }}
    )
    
    # Delete OTP so it can't be reused
    await db.otps.delete_one({"email": email})
    
    return {"message": "Password successfully reset."}

@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_account(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's account and all associated students."""
    db = get_db()
    user_id = current_user["_id"]

    # Delete all associated students first
    await db.students.delete_many({"parent_id": user_id})

    # Delete the user account
    result = await db.users.delete_one({"_id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to delete account")

    return None

@router.put("/settings/login-alerts", response_model=UserResponse)
async def toggle_login_alerts(request: ToggleLoginAlertsRequest, current_user: dict = Depends(get_current_user)):
    """Enable or disable login alerts."""
    db = get_db()
    
    user_doc = await db.users.find_one_and_update(
        {"_id": current_user["_id"]},
        {"$set": {"login_alerts_enabled": request.enabled}},
        return_document=True
    )
    
    return UserResponse(
        id=str(user_doc["_id"]),
        name=user_doc["name"],
        email=user_doc["email"],
        role=user_doc.get("role", "parent"),
        login_alerts_enabled=user_doc.get("login_alerts_enabled", True)
    )


@router.post("/profile/picture")
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    db = get_db()
    fs = AsyncIOMotorGridFSBucket(db)
    
    # Optional: Delete old profile picture if exists
    old_pic_url = current_user.get("profile_picture_url")
    if old_pic_url and "/api/v1/auth/profile/picture/" in old_pic_url:
        old_file_id = old_pic_url.split("/")[-1]
        try:
            await fs.delete(ObjectId(old_file_id))
        except Exception:
            pass
            
    # Upload new file
    file_id = await fs.upload_from_stream(
        file.filename,
        file.file,
        metadata={"contentType": file.content_type, "user_id": str(current_user["_id"])}
    )
    
    # Determine the base URL dynamically or just use relative path
    # Using relative path because frontend prepends base URL? Wait.
    # Frontend base URL is /api/v1/auth. So we can just return the file_id.
    # Actually, returning full path /api/v1/auth/profile/picture/{file_id} is better.
    new_url = f"/api/v1/auth/profile/picture/{str(file_id)}"
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"profile_picture_url": new_url}}
    )
    
    return {"message": "Profile picture updated", "profile_picture_url": new_url}

@router.get("/profile/picture/{file_id}")
async def get_profile_picture(file_id: str):
    db = get_db()
    fs = AsyncIOMotorGridFSBucket(db)
    
    try:
        grid_out = await fs.open_download_stream(ObjectId(file_id))
        
        async def file_iterator():
            while True:
                chunk = await grid_out.readchunk()
                if not chunk:
                    break
                yield chunk
                
        return StreamingResponse(
            file_iterator(),
            media_type=grid_out.metadata.get("contentType", "image/jpeg") if grid_out.metadata else "image/jpeg"
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Image not found")

@router.delete("/profile/picture")
async def delete_profile_picture(current_user: dict = Depends(get_current_user)):
    db = get_db()
    fs = AsyncIOMotorGridFSBucket(db)
    
    old_pic_url = current_user.get("profile_picture_url")
    if old_pic_url and "/api/v1/auth/profile/picture/" in old_pic_url:
        old_file_id = old_pic_url.split("/")[-1]
        try:
            await fs.delete(ObjectId(old_file_id))
        except Exception:
            pass
            
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"profile_picture_url": ""}}
    )
    return {"message": "Profile picture deleted successfully"}
