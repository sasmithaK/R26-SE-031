"""Validate access tokens issued by the Sipsara authentication API."""

import os
import jwt


def verify_token(token: str):
    secret = os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET")
    if not secret:
        return None
    try:
        return jwt.decode(token, secret, algorithms=["HS256"])
    except jwt.InvalidTokenError:
        return None
