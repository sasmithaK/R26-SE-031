"""
auth-service-v1/main.py
========================
C5 — Authentication & Student Management Service
FastAPI application — Port 8015

This is the app factory. All route logic lives in routers/.
"""

import os
import sys
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

# Allow importing from shared/
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from shared.database import connect_to_mongo, close_mongo_connection
from config import PORT, CORS_ORIGINS

# Import routers
from routers.auth import router as auth_router, limiter as auth_limiter
from routers.students import router as students_router
from routers.specialists import router as specialists_router
from routers.activities import router as activities_router
from routers.therapist import router as therapist_router
from routers.parent_dashboard import router as parent_dashboard_router
from routers.therapist_dashboard import router as therapist_dashboard_router
from routers.learning import router as learning_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown: connect and disconnect from MongoDB."""
    await connect_to_mongo()
    yield
    await close_mongo_connection()


app = FastAPI(
    title="C5 — Authentication & Student Management Service",
    description="Handles parent registration, login, and student profile management.",
    version="2.0.0",
    lifespan=lifespan,
    docs_url=None, # Disable default docs to use centralized one
)

# --- Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Rate Limiting ---
app.state.limiter = auth_limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# --- Register Routers ---
app.include_router(auth_router)
app.include_router(students_router)
app.include_router(specialists_router)
app.include_router(activities_router)
app.include_router(therapist_router)
app.include_router(parent_dashboard_router)
app.include_router(therapist_dashboard_router)
app.include_router(learning_router)

# Mount static folder (Moved to speech-monitoring-v1)


# --- Health Check ---
@app.get("/health")
def health():
    return {"status": "ok", "service": "C5-Auth"}

# --- Centralized OpenAPI Docs ---
@app.get("/docs", include_in_schema=False)
async def custom_swagger_ui_html():
    speech_url = os.getenv("SPEECH_API_URL", "http://localhost:8020")
    telemetry_url = os.getenv("TELEMETRY_API_URL", "http://localhost:8025")
    fusion_url = os.getenv("FUSION_API_URL", "http://localhost:9016")
    tutoring_url = os.getenv("TUTORING_API_URL", "http://localhost:9017")
    
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title="Sipsara - Centralized API Docs",
        swagger_ui_parameters={
            "urls": [
                {"url": "/openapi.json", "name": "C5 - Auth & Student Management"},
                {"url": f"{speech_url}/openapi.json", "name": "C2 - Speech Monitoring"},
                {"url": f"{telemetry_url}/openapi.json", "name": "C4 - Telemetry Analytics"},
                {"url": f"{fusion_url}/openapi.json", "name": "C3 - Diagnostic Fusion"},
                {"url": f"{tutoring_url}/openapi.json", "name": "C1 - Adaptive Tutoring"},
            ]
        }
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=False)
# Trigger Render deployment
