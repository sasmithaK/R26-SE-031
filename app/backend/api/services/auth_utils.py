"""
services/auth_utils.py
======================
Password hashing, JWT creation and verification utilities.
"""

from datetime import datetime, timedelta, timezone
import jwt
from google.oauth2 import id_token
from google.auth.transport import requests
from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES, REFRESH_TOKEN_EXPIRE_MINUTES, SMTP_EMAIL, SMTP_PASSWORD
import smtplib
from email.message import EmailMessage
import urllib.request
import json
import bcrypt


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Check a plaintext password against a bcrypt hash."""
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """Hash a plaintext password with bcrypt."""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')


def create_access_token(data: dict, expires_delta: timedelta = None) -> str:
    """Create a short-lived JWT access token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(data: dict, expires_delta: timedelta = None) -> str:
    """Create a long-lived JWT refresh token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=REFRESH_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def verify_token(token: str) -> dict:
    """Decode and verify a JWT token. Returns payload dict or None."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

import os as _os

# Public OAuth client IDs (not secrets). Override with GOOGLE_CLIENT_IDS
# (comma-separated) when the Google Cloud project changes.
GOOGLE_CLIENT_IDS = [
    value.strip() for value in _os.getenv(
        "GOOGLE_CLIENT_IDS",
        "733315696908-tpau04bmsk824olg6m0a3coanojl147v.apps.googleusercontent.com,"
        "733315696908-p1b7u8vgcdkfj08kss6r9u0b5mgvt1uo.apps.googleusercontent.com,"
        "733315696908-le4r1kebs5o83a31d17ngbm4ve0vee4m.apps.googleusercontent.com",
    ).split(",") if value.strip()
]


def verify_google_token(token: str) -> dict:
    """Verify a Google ID token and return user info."""
    try:
        # Accept tokens generated for any configured client (Web, iOS, Android).
        idinfo = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            audience=GOOGLE_CLIENT_IDS,
        )
        return idinfo
    except ValueError as e:
        print(f"Google Token Verification Error: {e}")
        return None

def verify_microsoft_token(access_token: str) -> dict:
    """Verify a Microsoft access token by querying the Microsoft Graph API."""
    try:
        url = "https://graph.microsoft.com/v1.0/me"
        req = urllib.request.Request(url, headers={'Authorization': f'Bearer {access_token}'})
        
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                
                # Extract relevant fields
                return {
                    "email": data.get("mail") or data.get("userPrincipalName", ""),
                    "name": data.get("displayName", "Microsoft User")
                }
            else:
                return None
    except Exception as e:
        print(f"Microsoft Token Verification Error: {e}")
        return None

import secrets
import string

def generate_otp(length: int = 6) -> str:
    """Generate a numeric OTP with a cryptographically secure generator."""
    return "".join(secrets.choice(string.digits) for _ in range(length))

def send_login_alert_email(email_address: str, ip_address: str, device_name: str, time_str: str):
    """Sends an email notifying the user of a new login."""
    try:
        html_content = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
            <h2 style="color: #FF5A5F;">New Login Alert</h2>
            <p>We noticed a new login to your account.</p>
            <div style="background-color: #f4f4f4; padding: 15px; border-radius: 8px;">
                <p><strong>Time:</strong> {time_str}</p>
                <p><strong>IP Address:</strong> {ip_address}</p>
                <p><strong>Device:</strong> {device_name}</p>
            </div>
            <p>If this was you, you can safely ignore this email.</p>
            <p style="color: #d9534f; font-weight: bold;">If this wasn't you, please change your password immediately.</p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
            <p style="font-size: 12px; color: #888;">This is an automated security alert.</p>
        </div>
        """
        import os
        import requests
        
        api_key = os.getenv("BREVO_API_KEY")
        if not api_key:
            print("Warning: BREVO_API_KEY not found. Login alert email not sent.")
            return
            
        url = "https://api.brevo.com/v3/smtp/email"
        headers = {
            "accept": "application/json",
            "api-key": api_key,
            "content-type": "application/json"
        }
        
        sender_email = os.getenv("SMTP_EMAIL", "sipsara.app.support@gmail.com")
        
        payload = {
            "sender": {"email": sender_email, "name": "Sipsara Security"},
            "to": [{"email": email_address}],
            "subject": "Security Alert: New login to your account",
            "htmlContent": html_content
        }
        
        response = requests.post(url, headers=headers, json=payload)
        
        if response.status_code in [200, 201, 202]:
            print(f"Login alert email sent to {email_address} for IP {ip_address}")
        else:
            print(f"Failed to send login alert email: {response.text}")
            
    except Exception as e:
        print(f"Failed to send login alert email Exception: {str(e)}")

def send_otp_email(email_address: str, otp: str):
    """
    Send the OTP via email using SMTP. 
    If SMTP credentials are not configured, fallback to console print.
    """
    # OTP codes are secrets: print them only when explicitly debugging locally.
    import os as _os
    if _os.getenv("DEBUG_PRINT_OTP", "").lower() in {"1", "true", "yes"}:
        print(f"[DEBUG_PRINT_OTP] OTP for {email_address}: {otp}")
    
    import os
    import requests
    from fastapi import HTTPException
    
    api_key = os.getenv("BREVO_API_KEY")
    if not api_key:
        print("Warning: BREVO_API_KEY not found in environment. Email not sent.")
        raise HTTPException(status_code=500, detail="Email service is not configured (missing BREVO_API_KEY).")
        
    url = "https://api.brevo.com/v3/smtp/email"
    headers = {
        "accept": "application/json",
        "api-key": api_key,
        "content-type": "application/json"
    }
    
    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #4A90E2;">Sipsara Security Code</h2>
            <p>Hello,</p>
            <p>Please use the following 6-digit code to verify your account or reset your password.</p>
            <div style="background-color: #F8F9FA; padding: 20px; text-align: center; border-radius: 8px; margin: 24px 0;">
                <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #2C3E50;">{otp}</span>
            </div>
            <p>This code will expire in 10 minutes.</p>
            <p>If you didn't request this, you can safely ignore this email.</p>
        </body>
    </html>
    """
    
    sender_email = os.getenv("SMTP_EMAIL", "sipsara.app.support@gmail.com")
    
    payload = {
        "sender": {
            "name": "Sipsara Auth",
            "email": sender_email
        },
        "to": [{"email": email_address}],
        "subject": "Your Sipsara Security Code",
        "htmlContent": html_content
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=10)
        
        if response.status_code not in [200, 201, 202]:
            raise Exception(f"Brevo API error {response.status_code}: {response.text}")
            
        print(f"Successfully sent OTP email to {email_address} via Brevo")
        
    except Exception as e:
        print(f"Failed to send email to {email_address}: {e}")
        raise HTTPException(status_code=500, detail=f"Could not send OTP email: {str(e)}")
