import os
from dotenv import load_dotenv

load_dotenv()

# We only need the SECRET_KEY to decode JWTs from the Auth service
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "super-secret-key-for-development-only")
ALGORITHM = "HS256"
