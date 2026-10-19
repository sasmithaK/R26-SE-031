import httpx
import uuid
import json
import time
import jwt
from datetime import datetime, timezone, timedelta

AZURE_BASE = "https://sipsara-ml-backend-v2.azurewebsites.net"
RENDER_BASE = "https://adaptedmind-auth-api.onrender.com"
AZURE_JWT_SECRET = "p2Msq2QN1D6LPpIo2S5aFv3k+zgkyedGPZ0gEXQ5ewk="

results = []

def record(service, endpoint, method, status, expected_status, passed, detail=""):
    results.append({
        "service": service,
        "endpoint": endpoint,
        "method": method,
        "status": status,
        "expected": expected_status,
        "passed": passed,
        "detail": detail
    })
    mark = "PASS" if passed else "FAIL"
    print(f"[{mark}] [{service}] {method:4} {endpoint} -> HTTP {status} (Expected {expected_status}) {detail[:80]}")

def make_request(method, url, **kwargs):
    """Execute HTTP request with independent client and retries to avoid socket poisoning."""
    max_retries = 3
    timeout = httpx.Timeout(connect=25.0, read=90.0, write=30.0, pool=25.0)
    for attempt in range(max_retries):
        try:
            with httpx.Client(timeout=timeout) as client:
                return client.request(method, url, **kwargs)
        except (httpx.ConnectError, httpx.ConnectTimeout) as e:
            if attempt == max_retries - 1:
                raise
            time.sleep(2.0 * (attempt + 1))
        except Exception:
            raise

def run_tests():
    print("=" * 80)
    print("LIVE BACKEND ENDPOINT VERIFICATION SUITE")
    print(f"Azure Host:  {AZURE_BASE}")
    print(f"Render Host: {RENDER_BASE}")
    print("=" * 80)

    # -----------------------------------------------------------------
    # 1. HEALTH CHECKS
    # -----------------------------------------------------------------
    print("\n--- 1. Health & Readiness Endpoints ---")
    health_endpoints = [
        ("Azure Gateway Root", f"{AZURE_BASE}/health"),
        ("C2 Speech Monitoring Health", f"{AZURE_BASE}/speech/health"),
        ("C2 Speech Monitoring Ready", f"{AZURE_BASE}/speech/ready"),
        ("C1 Telemetry Analytics Health", f"{AZURE_BASE}/telemetry/health"),
        ("C1 Telemetry Analytics Ready", f"{AZURE_BASE}/telemetry/ready"),
        ("C3 Diagnostic Fusion Health", f"{AZURE_BASE}/diagnostic/health"),
        ("C4 Adaptive Tutoring Health", f"{AZURE_BASE}/tutoring/health"),
        ("C5 Auth Service Health", f"{RENDER_BASE}/health"),
        ("C5 Auth Service Ready", f"{RENDER_BASE}/ready"),
    ]

    for name, url in health_endpoints:
        try:
            r = make_request("GET", url)
            passed = r.status_code == 200
            ep_short = url.replace(AZURE_BASE, "").replace(RENDER_BASE, "")
            record(name, ep_short, "GET", r.status_code, 200, passed, r.text)
        except Exception as e:
            record(name, url, "GET", 0, 200, False, str(e))

    # -----------------------------------------------------------------
    # 2. C5 AUTHENTICATION (Render)
    # -----------------------------------------------------------------
    print("\n--- 2. C5 Auth Endpoints (Render) ---")
    parent_token = None
    specialist_token = None
    parent_user_id = None
    parent_refresh = None

    # Parent login
    try:
        r = make_request("POST", f"{RENDER_BASE}/api/v1/auth/login", json={
            "email": "test_verifier_parent@sipsara.org",
            "password": "TestPassword123!",
            "role": "parent"
        })
        passed = r.status_code == 200 and "access_token" in r.json()
        if passed:
            data = r.json()
            parent_token = data["access_token"]
            parent_refresh = data["refresh_token"]
        record("C5 Auth", "/api/v1/auth/login [Parent]", "POST", r.status_code, 200, passed, "Success")
    except Exception as e:
        record("C5 Auth", "/api/v1/auth/login [Parent]", "POST", 0, 200, False, str(e))

    # Specialist login
    try:
        r = make_request("POST", f"{RENDER_BASE}/api/v1/auth/login", json={
            "email": "test_verifier_specialist@sipsara.org",
            "password": "TestPassword123!",
            "role": "specialist"
        })
        passed = r.status_code == 200 and "access_token" in r.json()
        if passed:
            specialist_token = r.json()["access_token"]
        record("C5 Auth", "/api/v1/auth/login [Specialist]", "POST", r.status_code, 200, passed, "Success")
    except Exception as e:
        record("C5 Auth", "/api/v1/auth/login [Specialist]", "POST", 0, 200, False, str(e))

    p_headers = {"Authorization": f"Bearer {parent_token}"} if parent_token else {}
    s_headers = {"Authorization": f"Bearer {specialist_token}"} if specialist_token else {}

    # Parent /me
    try:
        r = make_request("GET", f"{RENDER_BASE}/api/v1/auth/me", headers=p_headers)
        passed = r.status_code == 200 and r.json().get("email") == "test_verifier_parent@sipsara.org"
        if passed:
            parent_user_id = r.json().get("id")
        record("C5 Auth", "/api/v1/auth/me [Parent]", "GET", r.status_code, 200, passed, r.text)
    except Exception as e:
        record("C5 Auth", "/api/v1/auth/me [Parent]", "GET", 0, 200, False, str(e))

    # Token Refresh
    if parent_refresh:
        try:
            r = make_request("POST", f"{RENDER_BASE}/api/v1/auth/refresh", json={"refresh_token": parent_refresh})
            passed = r.status_code == 200 and "access_token" in r.json()
            record("C5 Auth", "/api/v1/auth/refresh", "POST", r.status_code, 200, passed, "Token Refreshed")
        except Exception as e:
            record("C5 Auth", "/api/v1/auth/refresh", "POST", 0, 200, False, str(e))

    # Curriculum Activities
    try:
        r = make_request("GET", f"{RENDER_BASE}/api/v1/auth/activities/skill_1")
        passed = r.status_code == 200
        record("C5 Curriculum", "/api/v1/auth/activities/skill_1", "GET", r.status_code, 200, passed, f"{len(r.json())} activities loaded")
    except Exception as e:
        record("C5 Curriculum", "/api/v1/auth/activities/skill_1", "GET", 0, 200, False, str(e))

    # Specialist Lookup
    try:
        r = make_request("GET", f"{RENDER_BASE}/api/v1/specialists/lookup/TEST99")
        passed = r.status_code == 200
        record("C5 Specialist", "/api/v1/specialists/lookup/TEST99", "GET", r.status_code, 200, passed, r.text)
    except Exception as e:
        record("C5 Specialist", "/api/v1/specialists/lookup/TEST99", "GET", 0, 200, False, str(e))

    # Specialist Connections & Dashboard Summary
    try:
        r = make_request("GET", f"{RENDER_BASE}/api/v1/auth/therapist/connections", headers=s_headers)
        passed = r.status_code == 200
        record("C5 Specialist", "/api/v1/auth/therapist/connections", "GET", r.status_code, 200, passed, r.text)
    except Exception as e:
        record("C5 Specialist", "/api/v1/auth/therapist/connections", "GET", 0, 200, False, str(e))

    try:
        r = make_request("GET", f"{RENDER_BASE}/api/v1/auth/therapist/dashboard-summary", headers=s_headers)
        passed = r.status_code == 200
        record("C5 Specialist", "/api/v1/auth/therapist/dashboard-summary", "GET", r.status_code, 200, passed, r.text)
    except Exception as e:
        record("C5 Specialist", "/api/v1/auth/therapist/dashboard-summary", "GET", 0, 200, False, str(e))

    # -----------------------------------------------------------------
    # 3. STUDENT MANAGEMENT & DASHBOARD ENDPOINTS (Render)
    # -----------------------------------------------------------------
    print("\n--- 3. Student Registration & Dashboard Endpoints (Render) ---")
    student_id = None
    try:
        r_list = make_request("GET", f"{RENDER_BASE}/api/v1/auth/students", headers=p_headers)
        students = r_list.json() if r_list.status_code == 200 else []
        if len(students) > 0:
            student_id = students[0]["id"]
            record("C5 Students", "/api/v1/auth/students", "GET", 200, 200, True, f"Found existing student ID: {student_id}")
        else:
            s_payload = {
                "first_name": "Kavindu",
                "last_name": "Perera",
                "grade": "Grade 1",
                "daily_limit": "No Limit",
                "assessment_results": [True] * 14,
                "comprehensive_assessment_results": {"Visual-Orthographic": [True, False, True]},
                "completed_activities": ["Skill_1"],
                "activity_scores": {"Skill_1": 85},
                "avatar_url": "assets/avatars/avatar1.png",
                "consent_given": True,
                "consent_parent_name": "Parent Verifier",
                "consent_date": "2026-10-18"
            }
            r_create = make_request("POST", f"{RENDER_BASE}/api/v1/auth/students", json=s_payload, headers=p_headers)
            passed = r_create.status_code == 201 and "id" in r_create.json()
            if passed:
                student_id = r_create.json()["id"]
            record("C5 Students", "/api/v1/auth/students", "POST", r_create.status_code, 201, passed, f"Created student ID: {student_id}")
    except Exception as e:
        record("C5 Students", "/api/v1/auth/students", "GET/POST", 0, 200, False, str(e))

    if student_id:
        parent_dash = [
            ("Overview", f"/api/v1/parent/students/{student_id}/overview"),
            ("Skills", f"/api/v1/parent/students/{student_id}/skills"),
            ("Learning Pattern", f"/api/v1/parent/students/{student_id}/learning-pattern"),
            ("Activity History", f"/api/v1/parent/students/{student_id}/activity-history"),
            ("Progress", f"/api/v1/parent/students/{student_id}/progress"),
            ("Fluency", f"/api/v1/parent/students/{student_id}/fluency"),
            ("Component Analytics", f"/api/v1/parent/students/{student_id}/component-analytics"),
            ("Adaptive Insights", f"/api/v1/parent/students/{student_id}/adaptive-insights"),
            ("Assessment Summary", f"/api/v1/parent/students/{student_id}/assessment-summary"),
            ("Research Evidence", f"/api/v1/parent/students/{student_id}/research-evidence"),
        ]
        for desc, ep_path in parent_dash:
            try:
                r = make_request("GET", f"{RENDER_BASE}{ep_path}", headers=p_headers)
                passed = r.status_code == 200
                record("C5 Parent Dash", ep_path, "GET", r.status_code, 200, passed, r.text[:60])
            except Exception as e:
                record("C5 Parent Dash", ep_path, "GET", 0, 200, False, str(e))

        # Starter Baseline
        try:
            r = make_request("GET", f"{RENDER_BASE}/api/v1/learning/starter-baseline/{student_id}", headers=p_headers)
            passed = r.status_code in [200, 404]
            record("C5 Baseline", f"/api/v1/learning/starter-baseline/{student_id}", "GET", r.status_code, 200, passed, r.text[:60])
        except Exception as e:
            record("C5 Baseline", f"/api/v1/learning/starter-baseline/{student_id}", "GET", 0, 200, False, str(e))

    # -----------------------------------------------------------------
    # 4. C4 ADAPTIVE TUTORING (Azure)
    # -----------------------------------------------------------------
    print("\n--- 4. C4 Adaptive Tutoring (Azure) ---")
    tutoring_payload = {
        "student_id": student_id or "STU_VERIFY",
        "session_id": str(uuid.uuid4()),
        "activity_id": "2.1",
        "knowledge_component_id": "KC_LETTER_IDENTITY",
        "item_id": "S2A1R01",
        "is_correct": True,
        "difficulty_b": 0.0,
        "current_session_duration_sec": 120,
        "fatigue_score": 0.1,
        "telemetry": {
            "first_touch_latency_ms": 1200,
            "total_round_latency_ms": 3200,
            "hesitation_count": 0,
            "misclick_count": 0
        }
    }
    try:
        r = make_request("POST", f"{AZURE_BASE}/tutoring/update_interaction", json=tutoring_payload)
        passed = r.status_code == 200 and "next_action" in r.json()
        record("C4 Tutoring", "/tutoring/update_interaction", "POST", r.status_code, 200, passed,
               f"Next item: {r.json().get('next_action', {}).get('next_item') if passed else r.text[:60]}")
    except Exception as e:
        record("C4 Tutoring", "/tutoring/update_interaction", "POST", 0, 200, False, str(e))

    # -----------------------------------------------------------------
    # 5. C3 DIAGNOSTIC FUSION & XAI ENGINE (Azure)
    # -----------------------------------------------------------------
    print("\n--- 5. C3 Diagnostic Fusion (Azure) ---")
    diagnostic_payload = {
        "student_id": student_id or "STU_VERIFY",
        "c1_audio_vector": {
            "acoustic_latency_ms": 1200.0,
            "peak_count_delta": 0.5,
            "intra_word_silence_ratio": 0.12,
            "local_jitter": 0.025,
            "local_shimmer": 0.035
        },
        "c2_kinematic_vector": {
            "time_to_first_touch_ms": 1400.0,
            "orthographic_confusion_index": 1.2,
            "path_efficiency_ratio": 0.88,
            "dimensionless_jerk": 45.0,
            "dwell_time_ms": 350.0
        },
        "student_age_months": 72,
        "gender": 1,
        "time_of_day_hour": 14,
        "data_origin": "observed"
    }
    try:
        r = make_request("POST", f"{AZURE_BASE}/diagnostic/diagnose", json=diagnostic_payload)
        passed = r.status_code == 200 and "learner_profile" in r.json()
        data = r.json() if passed else {}
        record("C3 Diagnostic", "/diagnostic/diagnose", "POST", r.status_code, 200, passed,
               f"Profile: {data.get('learner_profile', {}).get('primary_pattern')} SHAP: {len(data.get('shap_explanations', {}).get('top_contributing_features', []))} features")
    except Exception as e:
        record("C3 Diagnostic", "/diagnostic/diagnose", "POST", 0, 200, False, str(e))

    # -----------------------------------------------------------------
    # 6. C1 BEHAVIORAL TELEMETRY ANALYTICS (Azure)
    # -----------------------------------------------------------------
    print("\n--- 6. C1 Behavioral Telemetry Analytics (Azure) ---")
    azure_auth = jwt.encode({
        "sub": "test_verifier_parent@sipsara.org",
        "role": "parent",
        "id": parent_user_id or "6ad48611b981b30e3a9cc286",
        "exp": datetime.now(timezone.utc) + timedelta(days=7)
    }, AZURE_JWT_SECRET, algorithm="HS256")
    azure_headers = {"Authorization": f"Bearer {azure_auth}"}

    c1_session = {
        "session_id": str(uuid.uuid4()),
        "student_id": student_id or "STU_VERIFY",
        "session_duration_seconds": 180,
        "events": [
            {
                "event_id": str(uuid.uuid4()),
                "activity_name": "Akshara Recognition",
                "round_number": 1,
                "is_correct": True,
                "first_touch_latency_ms": 1100,
                "total_round_latency_ms": 2800,
                "hesitation_count": 0,
                "misclick_count": 0
            }
        ]
    }
    try:
        r = make_request("POST", f"{AZURE_BASE}/telemetry/api/v1/c1/session", json=c1_session, headers=azure_headers)
        passed = r.status_code in [200, 201]
        record("C1 Telemetry", "/telemetry/api/v1/c1/session", "POST", r.status_code, 201, passed, r.text[:60])
    except Exception as e:
        record("C1 Telemetry", "/telemetry/api/v1/c1/session", "POST", 0, 201, False, str(e))

    target_sid = student_id or "STU_VERIFY"
    for ep_desc, ep_url in [
        ("History", f"/telemetry/api/v1/c1/student/{target_sid}/history"),
        ("Summary", f"/telemetry/api/v1/c1/students/{target_sid}/summary"),
        ("Trend", f"/telemetry/api/v1/c1/students/{target_sid}/trend"),
        ("State", f"/telemetry/api/v1/c1/students/{target_sid}/state"),
    ]:
        try:
            r = make_request("GET", f"{AZURE_BASE}{ep_url}", headers=azure_headers)
            passed = r.status_code in [200, 404]
            record("C1 Telemetry", ep_url, "GET", r.status_code, 200, passed, r.text[:60])
        except Exception as e:
            record("C1 Telemetry", ep_url, "GET", 0, 200, False, str(e))

    # -----------------------------------------------------------------
    # 7. C5 UNIFIED LEARNING PIPELINE (Render)
    # -----------------------------------------------------------------
    print("\n--- 7. C5 Unified Learning Pipeline (Render) ---")
    learning_payload = {
        "student_id": student_id or "STU_VERIFY",
        "session_id": str(uuid.uuid4()),
        "activity_id": "Skill_2",
        "item_id": "S2A1R01",
        "knowledge_component_id": "KC_LETTER_IDENTITY",
        "response": {
            "selected_character": "ආ",
            "is_correct": True
        },
        "telemetry": {
            "first_touch_latency_ms": 1150,
            "total_round_latency_ms": 3100,
            "hesitation_count": 0,
            "misclick_count": 0,
            "touch_stream": []
        }
    }
    try:
        r = make_request("POST", f"{RENDER_BASE}/api/v1/learning/interaction", json=learning_payload)
        passed = r.status_code == 200 and "next_action" in r.json()
        record("C5 Learning", "/api/v1/learning/interaction", "POST", r.status_code, 200, passed,
               f"Next activity: {r.json().get('next_action', {}).get('next_activity') if passed else r.text[:60]}")
    except Exception as e:
        record("C5 Learning", "/api/v1/learning/interaction", "POST", 0, 200, False, str(e))

    # Overall Summary
    total = len(results)
    passed_count = sum(1 for r in results if r["passed"])
    failed_count = total - passed_count
    print("\n" + "=" * 80)
    print(f"VERIFICATION RESULTS: {passed_count}/{total} PASSED ({failed_count} FAILED)")
    print("=" * 80)

if __name__ == "__main__":
    run_tests()
