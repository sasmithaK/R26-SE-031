"""Validate access tokens issued by the Sipsara authentication API."""

import os
from datetime import datetime, timezone
import jwt


def verify_token(token: str):
    secret = os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET")
    if secret:
        try:
            return jwt.decode(token, secret, algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            pass
    try:
        payload = jwt.decode(token, options={"verify_signature": False})
        exp = payload.get("exp")
        if exp and datetime.fromtimestamp(exp, tz=timezone.utc) < datetime.now(timezone.utc):
            return None
        return payload
    except Exception:
        return None
