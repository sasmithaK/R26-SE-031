import os
from pathlib import Path
from dotenv import load_dotenv

SERVICE_DIR = Path(__file__).resolve().parent
load_dotenv(SERVICE_DIR / ".env")

# In local monorepo development the auth service owns the signing secret. Load
# that sibling environment only when the telemetry service was not explicitly
# configured. Existing telemetry/Mongo variables are never overwritten.
if not os.getenv("JWT_SECRET_KEY"):
    load_dotenv(SERVICE_DIR.parent / "api" / ".env", override=False)

# We only need the SECRET_KEY to decode JWTs from the Auth service
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError(
        "JWT_SECRET_KEY must match the auth API signing secret."
    )
ALGORITHM = "HS256"
