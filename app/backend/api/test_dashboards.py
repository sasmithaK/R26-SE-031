from fastapi.testclient import TestClient
from main import app
import asyncio

student_id = "STU001"

with TestClient(app) as client:
    print("--- Testing Parent Dashboard APIs ---")
    endpoints_parent = [
        f"/api/v1/parent/students/{student_id}/overview",
        f"/api/v1/parent/students/{student_id}/skills",
        f"/api/v1/parent/students/{student_id}/learning-pattern",
        f"/api/v1/parent/students/{student_id}/activity-history"
    ]

    for ep in endpoints_parent:
        print(f"Testing {ep} ...")
        try:
            response = client.get(ep)
            print(f"Status Code: {response.status_code}")
            if response.status_code != 200:
                print(f"Error: {response.json()}")
        except Exception as e:
            print(f"Exception: {e}")
            
    print("\n--- Testing Therapist Dashboard APIs ---")
    endpoints_therapist = [
        f"/api/v1/therapist/students/{student_id}/overview",
        f"/api/v1/therapist/students/{student_id}/behavior",
        f"/api/v1/therapist/students/{student_id}/kinematics",
        f"/api/v1/therapist/students/{student_id}/profile",
        f"/api/v1/therapist/students/{student_id}/knowledge",
        f"/api/v1/therapist/students/{student_id}/adaptive-history"
    ]

    for ep in endpoints_therapist:
        print(f"Testing {ep} ...")
        try:
            response = client.get(ep)
            print(f"Status Code: {response.status_code}")
            if response.status_code != 200:
                print(f"Error: {response.json()}")
        except Exception as e:
            print(f"Exception: {e}")
