import subprocess
import time
import requests
import os

def test():
    # Start uvicorn
    proc = subprocess.Popen(
        ["uvicorn", "main:app", "--port", "8001", "--host", "0.0.0.0", "--log-level", "debug"],
        cwd="monitoring-service",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    
    time.sleep(5) # Wait for startup
    
    print("Sending request...")
    try:
        r = requests.post(
            'http://localhost:8001/api/v1/telemetry', 
            json={
                'student_id': 'STU_DEMO_01', 
                'task_id': 't1', 
                'hesitation_time_ms': 5000, 
                'swipe_velocity': 100, 
                'correction_rate': 0, 
                'error_count': 1, 
                'hesitation_count': 1
            },
            timeout=5
        )
        print(f"Status: {r.status_code}")
        print(f"Response: {r.text}")
    except Exception as e:
        print(f"Request failed: {e}")
    
    # Read output
    time.sleep(2)
    proc.terminate()
    out, _ = proc.communicate()
    print("\n--- SERVER LOGS ---")
    print(out)

if __name__ == "__main__":
    test()
