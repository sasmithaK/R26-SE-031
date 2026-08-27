from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from contextlib import asynccontextmanager

from database import connect_to_mongo, close_mongo_connection
from routers.stt import router as stt_router
from routers.tts import router as tts_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_mongo()
    yield
    # Shutdown
    await close_mongo_connection()

app = FastAPI(
    title="Speech Monitoring & Analysis Service",
    description="Microservice for STT, TTS, and Acoustic Hesitation Analysis",
    version="1.0.0",
    lifespan=lifespan,
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
    return {"status": "ok", "service": "speech-monitoring-v1"}

if __name__ == "__main__":
    import uvicorn
    # Run on port 8020
    port = int(os.getenv("PORT", "8020"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
