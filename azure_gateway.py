import subprocess
import sys
import time
import os
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
import httpx
import uvicorn
import asyncio

# Setup paths and services
BASE = Path(__file__).parent
SERVICES = [
    {"name": "speech",     "path": "app/backend/speech-monitoring-v1",   "port": 8011},
    {"name": "telemetry",  "path": "app/backend/telemetry-analytics-v1", "port": 8014},
    {"name": "diagnostic", "path": "app/backend/diagnostic-fusion-v1",   "port": 8016},
    {"name": "tutoring",   "path": "app/backend/adaptive-tutoring-v1",   "port": 8017},
]

processes = []

def start_services():
    for svc in SERVICES:
        svc_path = BASE / svc["path"]
        main_py = svc_path / "main.py"
        
        if not main_py.exists():
            print(f"[ERROR] {svc['name']} not found at {main_py}")
            continue
            
        print(f"[START] {svc['name']} on port {svc['port']}...")
        env = os.environ.copy()
        env["PORT"] = str(svc["port"])
        
        p = subprocess.Popen(
            [sys.executable, str(main_py)],
            cwd=str(svc_path),
            env=env
        )
        processes.append(p)

# Start background services before the gateway starts
start_services()
time.sleep(5) # Give them time to spin up

# Create Gateway App
app = FastAPI(title="Azure ML Gateway")
client = httpx.AsyncClient(timeout=60.0)

async def proxy_request(request: Request, service_port: int, path: str):
    url = f"http://127.0.0.1:{service_port}/{path}"
    
    # Read the body
    body = await request.body()
    
    # Forward the request
    req = client.build_request(
        method=request.method,
        url=url,
        headers=request.headers.raw,
        content=body
    )
    
    response = await client.send(req, stream=True)
    
    return StreamingResponse(
        response.aiter_raw(),
        status_code=response.status_code,
        headers=response.headers
    )

@app.api_route("/speech/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_speech(request: Request, path: str):
    return await proxy_request(request, 8011, path)

@app.api_route("/telemetry/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_telemetry(request: Request, path: str):
    return await proxy_request(request, 8014, path)

@app.api_route("/diagnostic/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_diagnostic(request: Request, path: str):
    return await proxy_request(request, 8016, path)

@app.api_route("/tutoring/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_tutoring(request: Request, path: str):
    return await proxy_request(request, 8017, path)

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Azure ML Gateway is running"}

if __name__ == "__main__":
    try:
        uvicorn.run("azure_gateway:app", host="0.0.0.0", port=8080)
    finally:
        for p in processes:
            p.terminate()
