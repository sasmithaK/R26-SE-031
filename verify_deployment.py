import httpx
import uuid
import json
import time
import io
import wave
import struct
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

def create_synthetic_wav():
    """Create a minimal 1-second 16kHz mono WAV file in memory."""
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(16000)
        import math
        samples = []
        for i in range(16000):
            val = int(32767.0 * 0.5 * math.sin(2.0 * math.pi * 440.0 * i / 16000))
            samples.append(struct.pack('<h', val))
        wav_file.writeframes(b''.join(samples))
    buf.seek(0)
    return buf.read()

def run_all_verifications():
    print("=" * 80)
    print("STARTING COMPREHENSIVE BACKEND ENDPOINT VERIFICATION")
    print(f"Azure Gateway: {AZURE_BASE}")
    print(f"Render Auth/Gateway: {RENDER_BASE}")
    print("=" * 80)

    # Use robust client timeout
    timeout_cfg = httpx.Timeout(connect=20.0, read=120.0, write=30.0, pool=20.0)

    with httpx.Client(timeout=timeout_cfg) as client:
        # =====================================================================
        # 1. INFRASTRUCTURE & HEALTH CHECKS
        # =====================================================================
        print("\n--- 1. Infrastructure & Service Health Checks ---")
        health_checks = [
            ("Azure Gateway Root", f"{AZURE_BASE}/health"),
            ("C2 Speech Health", f"{AZURE_BASE}/speech/health"),
            ("C2 Speech Ready", f"{AZURE_BASE}/speech/ready"),
            ("C1 Telemetry Health", f"{AZURE_BASE}/telemetry/health"),
            ("C1 Telemetry Ready", f"{AZURE_BASE}/telemetry/ready"),
            ("C3 Diagnostic Health", f"{AZURE_BASE}/diagnostic/health"),
            ("C4 Tutoring Health", f"{AZURE_BASE}/tutoring/health"),
            ("C5 Auth Health", f"{RENDER_BASE}/health"),
            ("C5 Auth Ready", f"{RENDER_BASE}/ready"),
        ]
        for name, url in health_checks:
            try:
                r = client.get(url)
                passed = r.status_code == 200
                record(name, url.replace(AZURE_BASE, "").replace(RENDER_BASE, ""), "GET", r.status_code, 200, passed, r.text)
            except Exception as e:
                record(name, url, "GET", 0, 200, False, str(e))

        # =====================================================================
        # 2. C5 AUTHENTICATION & TOKENS
        # =====================================================================
        print("\n--- 2. C5 Authentication & Token Verification ---")
        parent_token = None
        specialist_token = None
        parent_refresh = None
        parent_user_id = None
        specialist_user_id = None

        # Parent Login
        try:
            r = client.post(f"{RENDER_BASE}/api/v1/auth/login", json={
                "email": "test_verifier_parent@sipsara.org",
                "password": "TestPassword123!",
                "role": "parent"
            })
            passed = r.status_code == 200 and "access_token" in r.json()
            if passed:
                data = r.json()
                parent_token = data["access_token"]
                parent_refresh = data["refresh_token"]
            record("C5 Auth", "/api/v1/auth/login [Parent]", "POST", r.status_code, 200, passed, "Token acquired")
        except Exception as e:
            record("C5 Auth", "/api/v1/auth/login [Parent]", "POST", 0, 200, False, str(e))

        # Specialist Login
        try:
            r = client.post(f"{RENDER_BASE}/api/v1/auth/login", json={
                "email": "test_verifier_specialist@sipsara.org",
                "password": "TestPassword123!",
                "role": "specialist"
            })
            passed = r.status_code == 200 and "access_token" in r.json()
            if passed:
                specialist_token = r.json()["access_token"]
            record("C5 Auth", "/api/v1/auth/login [Specialist]", "POST", r.status_code, 200, passed, "Token acquired")
        except Exception as e:
            record("C5 Auth", "/api/v1/auth/login [Specialist]", "POST", 0, 200, False, str(e))

        p_headers = {"Authorization": f"Bearer {parent_token}"} if parent_token else {}
        s_headers = {"Authorization": f"Bearer {specialist_token}"} if specialist_token else {}

        # Parent /me (Protected)
        try:
            r = client.get(f"{RENDER_BASE}/api/v1/auth/me", headers=p_headers)
            passed = r.status_code == 200 and r.json().get("email") == "test_verifier_parent@sipsara.org"
            if passed:
                parent_user_id = r.json().get("id")
            record("C5 Auth", "/api/v1/auth/me [Parent]", "GET", r.status_code, 200, passed, r.text)
        except Exception as e:
            record("C5 Auth", "/api/v1/auth/me [Parent]", "GET", 0, 200, False, str(e))

        # Specialist /me (Protected)
        try:
            r = client.get(f"{RENDER_BASE}/api/v1/auth/me", headers=s_headers)
            passed = r.status_code == 200 and r.json().get("email") == "test_verifier_specialist@sipsara.org"
            if passed:
                specialist_user_id = r.json().get("id")
            record("C5 Auth", "/api/v1/auth/me [Specialist]", "GET", r.status_code, 200, passed, r.text)
        except Exception as e:
            record("C5 Auth", "/api/v1/auth/me [Specialist]", "GET", 0, 200, False, str(e))

        # Refresh Token Endpoint
        try:
            r = client.post(f"{RENDER_BASE}/api/v1/auth/refresh", json={"refresh_token": parent_refresh})
            passed = r.status_code == 200 and "access_token" in r.json()
            record("C5 Auth", "/api/v1/auth/refresh", "POST", r.status_code, 200, passed, "Token refreshed")
        except Exception as e:
            record("C5 Auth", "/api/v1/auth/refresh", "POST", 0, 200, False, str(e))

        # Curriculum Activities
        try:
            r = client.get(f"{RENDER_BASE}/api/v1/auth/activities/skill_1")
            passed = r.status_code == 200
            record("C5 Curriculum", "/api/v1/auth/activities/skill_1", "GET", r.status_code, 200, passed, f"Activities count: {len(r.json()) if passed else 0}")
        except Exception as e:
            record("C5 Curriculum", "/api/v1/auth/activities/skill_1", "GET", 0, 200, False, str(e))

        # =====================================================================
        # 3. STUDENT CREATION & RESOLUTION
        # =====================================================================
        print("\n--- 3. Student Creation & Listing ---")
        student_id = None
        try:
            r = client.get(f"{RENDER_BASE}/api/v1/auth/students", headers=p_headers)
            students = r.json() if r.status_code == 200 else []
            if len(students) > 0:
                student_id = students[0]["id"]
                record("C5 Students", "/api/v1/auth/students", "GET", r.status_code, 200, True, f"Existing student: {student_id}")
            else:
                # Create a student via the API
                create_payload = {
                    "first_name": "Kavindu",
                    "last_name": "Perera",
                    "grade": "Grade 1",
                    "daily_limit": "No Limit",
                    "assessment_results": [True] * 14,
                    "comprehensive_assessment_results": {"Visual-Orthographic": [True] * 5},
                    "avatar_url": "assets/avatars/avatar1.png",
                    "consent_given": True,
                    "consent_parent_name": "Parent Verifier",
                    "consent_date": "2026-10-18"
                }
                r_create = client.post(f"{RENDER_BASE}/api/v1/auth/students", json=create_payload, headers=p_headers)
                passed = r_create.status_code == 201 and "id" in r_create.json()
                if passed:
                    student_id = r_create.json()["id"]
                record("C5 Students", "/api/v1/auth/students", "POST", r_create.status_code, 201, passed, f"Created student: {student_id}")
        except Exception as e:
            record("C5 Students", "/api/v1/auth/students", "GET/POST", 0, 200, False, str(e))

        # =====================================================================
        # 4. C5 PARENT DASHBOARD ENDPOINTS
        # =====================================================================
        print("\n--- 4. C5 Parent Dashboard Endpoints ---")
        if student_id:
            parent_dash_endpoints = [
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
            for desc, path in parent_dash_endpoints:
                try:
                    r = client.get(f"{RENDER_BASE}{path}", headers=p_headers)
                    passed = r.status_code == 200
                    record("C5 Parent Dash", path, "GET", r.status_code, 200, passed, r.text[:60])
                except Exception as e:
                    record("C5 Parent Dash", path, "GET", 0, 200, False, str(e))
        else:
            print("Skipping Parent Dashboard tests: No student available")

        # Starter baseline status
        if student_id:
            try:
                r = client.get(f"{RENDER_BASE}/api/v1/learning/starter-baseline/{student_id}", headers=p_headers)
                passed = r.status_code in [200, 404]
                record("C5 Baseline", f"/api/v1/learning/starter-baseline/{student_id}", "GET", r.status_code, 200, passed, r.text[:60])
            except Exception as e:
                record("C5 Baseline", f"/api/v1/learning/starter-baseline/{student_id}", "GET", 0, 200, False, str(e))

        # =====================================================================
        # 5. C5 SPECIALIST & THERAPIST DASHBOARDS
        # =====================================================================
        print("\n--- 5. C5 Specialist & Therapist Endpoints ---")
        try:
            r = client.get(f"{RENDER_BASE}/api/v1/auth/therapist/connections", headers=s_headers)
            passed = r.status_code == 200
            record("C5 Specialist", "/api/v1/auth/therapist/connections", "GET", r.status_code, 200, passed, r.text)
        except Exception as e:
            record("C5 Specialist", "/api/v1/auth/therapist/connections", "GET", 0, 200, False, str(e))

        try:
            r = client.get(f"{RENDER_BASE}/api/v1/auth/therapist/dashboard-summary", headers=s_headers)
            passed = r.status_code == 200
            record("C5 Specialist", "/api/v1/auth/therapist/dashboard-summary", "GET", r.status_code, 200, passed, r.text)
        except Exception as e:
            record("C5 Specialist", "/api/v1/auth/therapist/dashboard-summary", "GET", 0, 200, False, str(e))

        try:
            r = client.get(f"{RENDER_BASE}/api/v1/specialists/lookup/TEST99")
            passed = r.status_code == 200
            record("C5 Specialist", "/api/v1/specialists/lookup/TEST99", "GET", r.status_code, 200, passed, r.text)
        except Exception as e:
            record("C5 Specialist", "/api/v1/specialists/lookup/TEST99", "GET", 0, 200, False, str(e))

        # =====================================================================
        # 6. C4 ADAPTIVE TUTORING (Azure)
        # =====================================================================
        print("\n--- 6. C4 Adaptive Tutoring (Azure) ---")
        tutoring_payload = {
            "student_id": student_id or "STU123",
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
            r = client.post(f"{AZURE_BASE}/tutoring/update_interaction", json=tutoring_payload)
            passed = r.status_code == 200 and "next_action" in r.json()
            record("C4 Tutoring", "/tutoring/update_interaction", "POST", r.status_code, 200, passed, 
                   f"Next item: {r.json().get('next_action', {}).get('next_item') if passed else r.text[:60]}")
        except Exception as e:
            record("C4 Tutoring", "/tutoring/update_interaction", "POST", 0, 200, False, str(e))

        # =====================================================================
        # 7. C3 DIAGNOSTIC FUSION (Azure)
        # =====================================================================
        print("\n--- 7. C3 Diagnostic Fusion (Azure) ---")
        diagnostic_payload = {
            "student_id": student_id or "STU123",
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
            r = client.post(f"{AZURE_BASE}/diagnostic/diagnose", json=diagnostic_payload)
            passed = r.status_code == 200 and "learner_profile" in r.json()
            data = r.json() if passed else {}
            record("C3 Diagnostic", "/diagnostic/diagnose", "POST", r.status_code, 200, passed,
                   f"Primary: {data.get('learner_profile', {}).get('primary_pattern')} SHAP: {len(data.get('shap_explanations', {}).get('top_contributing_features', []))} features")
        except Exception as e:
            record("C3 Diagnostic", "/diagnostic/diagnose", "POST", 0, 200, False, str(e))

        # =====================================================================
        # 8. C1 BEHAVIORAL TELEMETRY ANALYTICS (Azure)
        # =====================================================================
        print("\n--- 8. C1 Behavioral Telemetry Analytics (Azure) ---")
        # Token signed with Azure's JWT_SECRET_KEY
        azure_auth_payload = {
            "sub": "test_verifier_parent@sipsara.org",
            "role": "parent",
            "id": parent_user_id or "6ad48611b981b30e3a9cc286",
            "exp": datetime.now(timezone.utc) + timedelta(days=7)
        }
        azure_jwt = jwt.encode(azure_auth_payload, AZURE_JWT_SECRET, algorithm="HS256")
        azure_headers = {"Authorization": f"Bearer {azure_jwt}"}

        session_id = str(uuid.uuid4())
        session_payload = {
            "session_id": session_id,
            "student_id": str(student_id) if student_id else "STU123",
            "skill_id": "Skill_1",
            "activity_id": "1.1",
            "started_at": "2026-10-18T08:00:00Z",
            "completed_at": "2026-10-18T08:05:00Z",
            "session_duration_seconds": 300,
            "data_origin": "synthetic",
            "events": [
                {
                    "event_id": str(uuid.uuid4()),
                    "round_id": "round_1",
                    "activity_name": "Letter Matching",
                    "round_number": 1,
                    "activity_id": "Skill_1",
                    "item_id": "S1A1R01",
                    "target_stimulus": "අ",
                    "selected_stimulus": "අ",
                    "is_correct": True,
                    "first_touch_latency_ms": 1100,
                    "total_round_latency_ms": 2800,
                    "hesitation_count": 0,
                    "misclick_count": 0,
                    "dwell_time_ms": 250,
                    "touch_stream": []
                }
            ]
        }
        try:
            r = client.post(f"{AZURE_BASE}/telemetry/api/v1/c1/session", json=session_payload, headers=azure_headers)
            passed = r.status_code in [200, 201]
            record("C1 Telemetry", "/telemetry/api/v1/c1/session", "POST", r.status_code, 201, passed, r.text[:60])
        except Exception as e:
            record("C1 Telemetry", "/telemetry/api/v1/c1/session", "POST", 0, 201, False, str(e))

        target_sid = student_id or "STU123"
        for ep_desc, ep_url in [
            ("History", f"/telemetry/api/v1/c1/student/{target_sid}/history"),
            ("Summary", f"/telemetry/api/v1/c1/students/{target_sid}/summary"),
            ("Trend", f"/telemetry/api/v1/c1/students/{target_sid}/trend"),
            ("State", f"/telemetry/api/v1/c1/students/{target_sid}/state"),
        ]:
            try:
                r = client.get(f"{AZURE_BASE}{ep_url}", headers=azure_headers)
                passed = r.status_code in [200, 404]
                record("C1 Telemetry", ep_url, "GET", r.status_code, 200, passed, r.text[:60])
            except Exception as e:
                record("C1 Telemetry", ep_url, "GET", 0, 200, False, str(e))

        # =====================================================================
        # 9. C5 UNIFIED LEARNING ORCHESTRATOR (Render)
        # =====================================================================
        print("\n--- 9. C5 Unified Learning Pipeline (Render) ---")
        learning_payload = {
            "student_id": student_id or "STU123",
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
            r = client.post(f"{RENDER_BASE}/api/v1/learning/interaction", json=learning_payload)
            passed = r.status_code == 200 and "next_action" in r.json()
            record("C5 Learning", "/api/v1/learning/interaction", "POST", r.status_code, 200, passed,
                   f"Next activity: {r.json().get('next_action', {}).get('next_activity') if passed else r.text[:60]}")
        except Exception as e:
            record("C5 Learning", "/api/v1/learning/interaction", "POST", 0, 200, False, str(e))

        # =====================================================================
        # 10. C2 SPEECH MONITORING ACOUSTIC ANALYSIS (Azure)
        # =====================================================================
        if student_id:
            print("\n--- 10. C2 Speech Monitoring (Azure) ---")
            try:
                wav_data = create_synthetic_wav()
                files = {"file": ("test.wav", wav_data, "audio/wav")}
                form_data = {
                    "student_id": str(student_id),
                    "session_id": str(uuid.uuid4()),
                    "skill_id": "Skill_1",
                    "activity_id": "1.1",
                    "item_id": "S1A1R01",
                    "expected_text": "අ",
                    "data_origin": "synthetic",
                }
                r = client.post(
                    f"{AZURE_BASE}/speech/stt/analyze-acoustics",
                    data=form_data,
                    files=files,
                    headers=p_headers,
                )
                passed = r.status_code in [200, 201]
                record("C2 Speech", "/speech/stt/analyze-acoustics", "POST", r.status_code, 200, passed, r.text[:80])
            except Exception as e:
                record("C2 Speech", "/speech/stt/analyze-acoustics", "POST", 0, 200, False, str(e))

    # Summary
    total = len(results)
    passed_count = sum(1 for r in results if r["passed"])
    failed_count = total - passed_count
    print("\n" + "=" * 80)
    print(f"VERIFICATION SUMMARY: {passed_count}/{total} PASSED ({failed_count} FAILED)")
    print("=" * 80)

if __name__ == "__main__":
    run_all_verifications()
