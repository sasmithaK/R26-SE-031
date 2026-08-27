from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from contextlib import asynccontextmanager

from database import connect_to_mongo, close_mongo_connection
from routers.telemetry import router as telemetry_router
from routers.ml import router as ml_router

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

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "telemetry-analytics-v1"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8025"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
