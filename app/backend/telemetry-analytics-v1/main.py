from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
from contextlib import asynccontextmanager

from database import connect_to_mongo, close_mongo_connection, get_db
from routers.telemetry import router as telemetry_router
from routers.ml import router as ml_router
from routers.c1 import router as c1_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    yield
    await close_mongo_connection()

app = FastAPI(
    title="Telemetry & ML Analytics Service",
    description="Microservice for cognitive profiling, risk assessment, and report generation.",
    version="1.0.0",
    lifespan=lifespan,
    root_path=os.getenv("ROOT_PATH", ""),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(telemetry_router)
app.include_router(ml_router)
app.include_router(c1_router)

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "telemetry-analytics-v1"}


@app.get("/ready")
async def readiness_check():
    """Verify C1 has both its shared JWT secret and MongoDB connection."""
    jwt_configured = bool(os.getenv("JWT_SECRET_KEY"))
    database_ready = False
    error_type = None
    try:
        await get_db().command("ping")
        database_ready = True
    except Exception as exc:
        error_type = type(exc).__name__

    ready = jwt_configured and database_ready
    return JSONResponse(
        status_code=200 if ready else 503,
        content={
            "ready": ready,
            "service": "telemetry-analytics-v1",
            "database": "ready" if database_ready else "unavailable",
            "jwt_secret": "configured" if jwt_configured else "missing",
            "error_type": error_type,
        },
    )

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8025"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
