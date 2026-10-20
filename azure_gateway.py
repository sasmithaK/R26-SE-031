import subprocess
import sys
import time
import os
import fcntl
import socket

from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, StreamingResponse
import httpx
import uvicorn
import asyncio

# Setup paths and services
BASE = Path(__file__).parent
SERVICES = [
    {"name": "speech",     "path": "app/backend/speech-monitoring-v1",   "port": 9011},
    {"name": "telemetry",  "path": "app/backend/telemetry-analytics-v1", "port": 9014},
    {"name": "diagnostic", "path": "app/backend/diagnostic-fusion-v1",   "port": 9016},
    {"name": "tutoring",   "path": "app/backend/adaptive-tutoring-v1",   "port": 9017},
]

processes = []


def wait_for_port_free(port: int, timeout: int = 30) -> bool:
    """
    Waits up to `timeout` seconds for a port to become available.
    Tries both fuser and lsof to kill the occupying process.
    Verifies freedom via socket connect test (avoids claiming the port).
    Fixes: [Errno 98] address already in use on Azure container restarts.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        is_free = False
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(1.0)
            try:
                s.connect(("127.0.0.1", port))
                is_free = False  # Connected successfully = port is IN USE
            except ConnectionRefusedError:
                is_free = True   # Connection refused = port is FREE
            except Exception:
                is_free = False
                
        if is_free:
            return True
            
        print(f"[WAIT] Port {port} still occupied — attempting to release...")
        os.system(f"fuser -k {port}/tcp > /dev/null 2>&1")
        os.system(f"lsof -ti:{port} | xargs kill -9 > /dev/null 2>&1")
        time.sleep(2)
        
    print(f"[ERROR] Port {port} still in use after {timeout}s — skipping service")
    return False

PID_FILE = "/tmp/azure_gateway_services.pids"

def cleanup_orphaned_services():
    if os.path.exists(PID_FILE):
        print("[INIT] Cleaning up orphaned microservices from previous run...")
        try:
            with open(PID_FILE, "r") as f:
                pids = f.read().splitlines()
            for pid_str in pids:
                if not pid_str.strip(): continue
                try:
                    pid = int(pid_str)
                    os.kill(pid, 9) # SIGKILL
                    print(f"  -> Killed orphaned process PID {pid}")
                except ProcessLookupError:
                    pass # Process already dead
                except Exception as e:
                    print(f"  -> Failed to kill PID {pid}: {e}")
            os.remove(PID_FILE)
        except Exception as e:
            print(f"[ERROR] Failed to clean up PIDs: {e}")

def start_services():
    cleanup_orphaned_services()
    
    for svc in SERVICES:
        svc_path = BASE / svc["path"]
        main_py = svc_path / "main.py"
        
        if not main_py.exists():
            print(f"[ERROR] {svc['name']} not found at {main_py}")
            continue
            
        print(f"[START] {svc['name']} on port {svc['port']}...")
        env = os.environ.copy()
        env["PORT"] = str(svc["port"])
        env["ROOT_PATH"] = f"/{svc['name']}"
        
        # Wait for port to be free before launching — prevents [Errno 98] crash
        if not wait_for_port_free(svc["port"]):
            continue  # Skip this service, log already printed
        
        p = subprocess.Popen(
            [sys.executable, str(main_py)],
            cwd=str(svc_path),
            env=env,
            # Inherit container streams so verbose ML logs cannot fill a pipe
            # and deadlock the service.
            stdout=None,
            stderr=None,
            text=True,
        )
        processes.append(p)
        
    # Save new PIDs to file for future cleanup
    try:
        with open(PID_FILE, "w") as f:
            for p in processes:
                f.write(f"{p.pid}\n")
    except Exception as e:
        print(f"[ERROR] Failed to save PID file: {e}")

# Ensure only one gateway worker owns the background services. An advisory
# lock is released automatically if the process dies, unlike a stale sentinel.
LOCK_FILE = "/tmp/azure_gateway_services.lock"
lock_fd = os.open(LOCK_FILE, os.O_CREAT | os.O_RDWR)
owns_service_lock = False
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    owns_service_lock = True
    print("[INIT] Gateway worker starting background services...")
    start_services()
    time.sleep(3)  # Give them time to bind their ports.
except BlockingIOError:
    print("[INIT] Services already started by another worker.")

from fastapi.middleware.cors import CORSMiddleware

# Create Gateway App
app = FastAPI(title="Azure ML Gateway")

# Enable CORS for Swagger UI cross-origin requests from Render
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = httpx.AsyncClient(
    timeout=httpx.Timeout(connect=10.0, read=300.0, write=60.0, pool=10.0)
)

async def proxy_request(request: Request, service_port: int, path: str):
    query_str = f"?{request.url.query}" if request.url.query else ""
    url = f"http://127.0.0.1:{service_port}/{path}{query_str}"
    
    # Read the body
    body = await request.body()
    
    # Filter hop-by-hop headers from client request
    excluded_req_headers = {"host", "content-length"}
    req_headers = [
        (name, value) for (name, value) in request.headers.raw
        if name.lower().decode("latin-1") not in excluded_req_headers
    ]
    
    try:
        # Forward the request
        req = client.build_request(
            method=request.method,
            url=url,
            headers=req_headers,
            content=body
        )
        
        response = await client.send(req, stream=True)
        
        excluded_resp_headers = {"content-encoding", "content-length", "transfer-encoding", "connection"}
        resp_headers = {
            k: v for k, v in response.headers.items()
            if k.lower() not in excluded_resp_headers
        }
        
        return StreamingResponse(
            response.aiter_raw(),
            status_code=response.status_code,
            headers=resp_headers
        )
    except httpx.TimeoutException:
        return JSONResponse(
            status_code=504,
            content={
                "error": "upstream_timeout",
                "message": "The ML service took too long to respond. Please retry.",
                "retryable": True,
            },
        )
    except httpx.HTTPError as exc:
        return JSONResponse(
            status_code=502,
            content={
                "error": "upstream_unavailable",
                "message": "The ML service is temporarily unavailable.",
                "retryable": True,
                "error_type": type(exc).__name__,
            },
        )

@app.api_route("/speech/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH"])
async def proxy_speech(request: Request, path: str):
    return await proxy_request(request, 9011, path)

@app.api_route("/telemetry/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH"])
async def proxy_telemetry(request: Request, path: str):
    return await proxy_request(request, 9014, path)

@app.api_route("/diagnostic/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH"])
async def proxy_diagnostic(request: Request, path: str):
    return await proxy_request(request, 9016, path)

@app.api_route("/tutoring/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH"])
async def proxy_tutoring(request: Request, path: str):
    return await proxy_request(request, 9017, path)



def get_non_blocking_output(p):
    if not p.stdout:
        return ""
    fd = p.stdout.fileno()
    fl = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    try:
        return p.stdout.read()
    except:
        return ""

@app.get("/health")
def health_check():
    status = {}
    healthy = len(processes) == len(SERVICES)
    for i, p in enumerate(processes):
        p.poll()
        if p.returncode is not None:
            status[SERVICES[i]["name"]] = f"crashed:{p.returncode}"
            healthy = False
        else:
            status[SERVICES[i]["name"]] = "running"
    
    env_vars = {
        "MONGODB_URL": "SET" if os.getenv("MONGODB_URL") else "MISSING",
        "GEMINI_API_KEY": "SET" if os.getenv("GEMINI_API_KEY") else "MISSING"
    }
    return JSONResponse(
        status_code=200 if healthy else 503,
        content={"status": "ok" if healthy else "degraded", "message": "Azure ML Gateway process status",
                 "details": status, "env": env_vars},
    )


@app.get("/ready")
async def readiness_check():
    if len(processes) != len(SERVICES) or any(p.poll() is not None for p in processes):
        return JSONResponse(status_code=503, content={"ready": False, "services": "process_failure"})
    checks = {}
    async with httpx.AsyncClient(timeout=3.0) as health_client:
        for service in SERVICES:
            try:
                endpoint = "health" if service["name"] == "tutoring" else "ready"
                response = await health_client.get(
                    f"http://127.0.0.1:{service['port']}/{endpoint}"
                )
                checks[service["name"]] = "ready" if response.is_success else f"not_ready:{response.status_code}"
            except httpx.HTTPError as exc:
                checks[service["name"]] = f"unreachable:{type(exc).__name__}"
    ready = all(value == "ready" for value in checks.values())
    return JSONResponse(status_code=200 if ready else 503, content={"ready": ready, "services": checks})


if __name__ == "__main__":
    try:
        # Passing the object avoids importing this module a second time and
        # losing the child-process state shown by /health.
        uvicorn.run(app, host="0.0.0.0", port=8080)
    finally:
        if owns_service_lock:
            for p in processes:
                p.terminate()
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)

