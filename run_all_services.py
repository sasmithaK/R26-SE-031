"""
run_all_services.py
===================
Master runner for the R26-SE-031-V2 microservice architecture.
Starts Monitoring, Visual, Content, and Intervention services concurrently.
"""

import subprocess
import sys
import time
import os
from pathlib import Path

# Set environment variables from .env if possible
from dotenv import load_dotenv
load_dotenv()

BASE = Path(__file__).parent
SERVICES = [
    {"name": "C1 Monitoring", "path": "monitoring-service-v1", "port": 8011},
    {"name": "C2 Visual",     "path": "visual-service-v1",     "port": 8014},
    {"name": "C3 Content",    "path": "content-service-v1",    "port": 8012},
    {"name": "C4 Intervention", "path": "intervention-service-v1", "port": 8013},
]

def run():
    processes = []
    
    print("=" * 60)
    print("  STARTING R26-SE-031-V2 MICROSERVICES")
    print("=" * 60)
    
    # Ensure log directory exists
    log_dir = BASE / "logs"
    log_dir.mkdir(exist_ok=True)
    
    for svc in SERVICES:
        svc_path = BASE / svc["path"]
        main_py = svc_path / "main.py"
        
        if not main_py.exists():
            print(f"  [ERROR] {svc['name']} entry point not found at {main_py}")
            continue
            
        print(f"  [START] {svc['name']:<15} on port {svc['port']}...")
        
        # Open log file
        log_file = open(log_dir / f"{svc['path']}.log", "w", encoding="utf-8")
        
        # Start process
        p = subprocess.Popen(
            [sys.executable, str(main_py)],
            cwd=str(svc_path),
            stdout=log_file,
            stderr=subprocess.STDOUT,
            env=os.environ.copy()
        )
        processes.append((svc["name"], p, log_file))
        
    print("-" * 60)
    print("  All services initiated. Waiting for health checks...")
    time.sleep(5) # Give them a moment to start
    
    print("\n  SERVICE STATUS:")
    for name, p, _ in processes:
        status = "RUNNING" if p.poll() is None else f"FAILED (Exit Code: {p.returncode})"
        print(f"    {name:<15}: {status}")
        
    print("-" * 60)
    print("  Use Ctrl+C to stop all services.")
    print(f"  Logs are available in {log_dir}")
    print("=" * 60)
    
    try:
        while True:
            # Check if any process died
            for name, p, _ in processes:
                if p.poll() is not None:
                    print(f"\n  [CRITICAL] {name} has stopped! Exit code: {p.returncode}")
                    # Optionally restart or exit
            time.sleep(10)
    except KeyboardInterrupt:
        print("\n  [STOP] Terminating all services...")
        for name, p, log_file in processes:
            p.terminate()
            log_file.close()
        print("  All services stopped.")

if __name__ == "__main__":
    run()
