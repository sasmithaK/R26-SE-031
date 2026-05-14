#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
start_services.py
=================
Enhanced service startup with error diagnostics and per-service startup.

Usage:
    python start_services.py              # Start all services
    python start_services.py --c1         # Start only C1
    python start_services.py --c2         # Start only C2
    python start_services.py --test       # Test connections to all services
"""

import subprocess
import sys
import time
import os
from pathlib import Path
import socket

# Force UTF-8 output on Windows
if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Try to load environment
try:
    from dotenv import load_dotenv
    load_dotenv()
except:
    pass

BASE = Path(__file__).parent

SERVICES = [
    {"name": "C1-CBME", "path": "monitoring-service-v2", "port": 8011, "desc": "Cognitive Behavioral Monitoring Engine"},
    {"name": "C2-AVLI", "path": "visual-service-v2", "port": 8014, "desc": "Adaptive Visual Learning Interface"},
    {"name": "C3-PLCE", "path": "content-service-v2", "port": 8012, "desc": "Content Engine"},
    {"name": "C4-IIGE", "path": "intervention-service-v2", "port": 8013, "desc": "Intervention Engine"},
]

def check_port_available(port):
    """Check if a port is available."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.bind(('127.0.0.1', port))
            return True
        except OSError:
            return False

def test_service(port):
    """Test if a service is responding on a given port."""
    try:
        import urllib.request
        import urllib.error
        response = urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2)
        return response.status == 200
    except (urllib.error.URLError, urllib.error.HTTPError, Exception):
        return False

def start_service(service):
    """Start a single service."""
    svc_path = BASE / service["path"]
    main_py = svc_path / "main.py"

    if not main_py.exists():
        print(f"[ERROR] {service['name']}: Entry point not found at {main_py}")
        return None

    # Check if port is available
    if not check_port_available(service["port"]):
        print(f"[ERROR] {service['name']}: Port {service['port']} is already in use")
        print(f"  Kill the existing process: lsof -ti:{service['port']} | xargs kill -9")
        return None

    print(f"[START] {service['name']:<8} ({service['desc']}) on port {service['port']}...")

    try:
        log_dir = BASE / "logs"
        log_dir.mkdir(exist_ok=True)
        log_file = open(log_dir / f"{service['path']}.log", "w", encoding="utf-8")

        p = subprocess.Popen(
            [sys.executable, str(main_py)],
            cwd=str(svc_path),
            stdout=log_file,
            stderr=subprocess.STDOUT,
            env=os.environ.copy()
        )

        # Give it a moment to start
        time.sleep(2)

        # Check if it's still running
        if p.poll() is not None:
            print(f"[FAIL] {service['name']}: Process exited with code {p.returncode}")
            log_file.seek(0)
            error_text = log_file.read()
            if error_text:
                print(f"  Error output:")
                for line in error_text.split('\n')[-10:]:
                    if line.strip():
                        print(f"    {line}")
            log_file.close()
            return None

        # Test the service
        if test_service(service['port']):
            print(f"[OK] {service['name']}: Running and responding on port {service['port']}")
            return p
        else:
            print(f"[WAIT] {service['name']}: Running (PID {p.pid}) but not yet responding on port {service['port']}")
            print(f"  Waiting for service to initialize...")
            time.sleep(3)
            if test_service(service['port']):
                print(f"[OK] {service['name']}: Now responding")
                return p
            else:
                print(f"[WAIT] {service['name']}: Still initializing... (check logs/{service['path']}.log)")
                return p

    except Exception as e:
        print(f"[FAIL] {service['name']}: Failed to start: {e}")
        return None

def run_all():
    """Start all services."""
    print("\n" + "=" * 70)
    print("  R26-SE-031-V2 MICROSERVICES -- STARTUP")
    print("=" * 70)

    processes = []

    for service in SERVICES:
        p = start_service(service)
        if p:
            processes.append((service, p))
        print()

    print("=" * 70)
    print(f"  {len(processes)}/{len(SERVICES)} services started successfully")
    print("=" * 70)

    if len(processes) == 0:
        print("  [FAIL] No services started. Check the logs/ directory for errors.")
        return

    print("\n  Active services:")
    for service, p in processes:
        status = "[OK] RUNNING" if p.poll() is None else "[FAIL] STOPPED"
        print(f"    {service['name']:<8} (PID {p.pid:<5}) {status} on port {service['port']}")

    print("\n  Logs available in: ./logs/")
    print("  Press Ctrl+C to stop all services")
    print("=" * 70 + "\n")

    try:
        while True:
            # Monitor processes
            for service, p in processes:
                if p.poll() is not None:
                    print(f"\n[ALERT] {service['name']} has crashed (exit code {p.returncode})")
                    print(f"  Check logs/{service['path']}.log for details")
            time.sleep(5)
    except KeyboardInterrupt:
        print("\n\n  Stopping all services...")
        for service, p in processes:
            print(f"  Terminating {service['name']}...")
            p.terminate()
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                p.kill()
        print("  All services stopped.")

def test_all():
    """Test connections to all services."""
    print("\n" + "=" * 70)
    print("  R26-SE-031-V2 MICROSERVICES -- CONNECTION TEST")
    print("=" * 70 + "\n")

    results = []
    for service in SERVICES:
        port = service['port']
        if test_service(port):
            print(f"[OK] {service['name']:<8} http://127.0.0.1:{port}/health")
            results.append(True)
        else:
            print(f"[FAIL] {service['name']:<8} http://127.0.0.1:{port}/health -- NOT RESPONDING")
            results.append(False)

    print("\n" + "=" * 70)
    passed = sum(results)
    print(f"  {passed}/{len(SERVICES)} services responding")
    print("=" * 70 + "\n")

    if passed < len(SERVICES):
        print("  To start services, run: python start_services.py")

def start_single(service_name):
    """Start a single service by name."""
    service_name = service_name.lstrip('-').upper()

    service = None
    for svc in SERVICES:
        if svc['name'].replace('-', '').upper() == service_name or svc['path'].split('-')[0].upper() == service_name:
            service = svc
            break

    if not service:
        print(f"[ERROR] Unknown service: {service_name}")
        print(f"  Available: C1, C2, C3, C4")
        return

    print("\n" + "=" * 70)
    print(f"  R26-SE-031-V2 MICROSERVICE -- {service['name']}")
    print("=" * 70 + "\n")

    p = start_service(service)

    if not p:
        return

    print(f"\n[OK] {service['name']} is running on port {service['port']}")
    print(f"  Health check: http://127.0.0.1:{service['port']}/health")
    print(f"  Logs: ./logs/{service['path']}.log")
    print("\n  Press Ctrl+C to stop\n")

    try:
        while p.poll() is None:
            time.sleep(1)
        print(f"\n[FAIL] {service['name']} has stopped")
    except KeyboardInterrupt:
        print(f"\n  Stopping {service['name']}...")
        p.terminate()
        p.wait()
        print(f"  {service['name']} stopped")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg == "--test":
            test_all()
        elif arg.startswith("--c"):
            start_single(arg)
        else:
            print(f"[ERROR] Unknown argument: {arg}")
            print("Usage: python start_services.py [--test|--c1|--c2|--c3|--c4]")
    else:
        run_all()
