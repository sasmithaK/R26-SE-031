from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
import asyncio
from contextlib import asynccontextmanager

from database import connect_to_mongo, close_mongo_connection, get_db
from routers.stt import router as stt_router
from routers.tts import router as tts_router
from services.stt_service import (
    get_stt_status,
    mark_stt_preloading,
    preload_stt_engine,
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_mongo()
    app.state.stt_preload_task = None
    if os.getenv("PRELOAD_STT", "true").lower() in {"1", "true", "yes"}:
        # Warm the model in a worker thread so health/readiness can respond.
        mark_stt_preloading()
        app.state.stt_preload_task = asyncio.create_task(
            asyncio.to_thread(preload_stt_engine)
        )
    yield
    # Shutdown
    await close_mongo_connection()

app = FastAPI(
    title="Speech Monitoring & Analysis Service",
    description="Quality-aware Sinhala STT, grapheme alignment, oral-reading fluency, and evidence fusion",
    version="3.0.0",
    lifespan=lifespan,
    root_path=os.getenv("ROOT_PATH", ""),
)

# Allow CORS for local dev and production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(stt_router)
app.include_router(tts_router)

# Static mounting removed, TTS audio now served via GridFS

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "speech-monitoring-v1",
        "stt": get_stt_status(),
    }


@app.get("/ready")
async def readiness_check():
    from fastapi.responses import JSONResponse

    stt = get_stt_status()
    database_ready = False
    auth_configured = bool(os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET"))
    error_type = None
    try:
        await get_db().command("ping")
        database_ready = True
    except Exception as exc:
        error_type = type(exc).__name__

    ready = stt["status"] == "ready" and database_ready and auth_configured
    return JSONResponse(
        status_code=200 if ready else 503,
        content={
            "ready": ready,
            "service": "speech-monitoring-v1",
            "stt": stt,
            "database": "ready" if database_ready else "unavailable",
            "authentication": "configured" if auth_configured else "JWT_SECRET_KEY is missing",
            "error_type": error_type,
        },
    )

if __name__ == "__main__":
    import uvicorn
    # Run on port 8020
    port = int(os.getenv("PORT", "8020"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
