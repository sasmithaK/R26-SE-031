import jwt
from config import SECRET_KEY, ALGORITHM

def verify_token(token: str) -> dict:
    """Decode and verify a JWT token. Returns payload dict or None."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
