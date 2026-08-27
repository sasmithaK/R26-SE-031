from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from database import get_db
from auth_utils import verify_token

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
