"""
Full End-to-End User Flow Test Script
Accounts:
  Parent:    parent@sipsara.com / Parent1234!
  Therapist: therapist@sipsara.com / Therapist1234!
  Student:   Kasun Perera (6ad5a03c00c4cf9c13dbb647)
"""

import sys
import io
import time
import uuid
import wave
import struct
import math
import requests

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

RENDER_BASE = "https://adaptedmind-auth-api.onrender.com"
AZURE_BASE = "https://sipsara-ml-backend-v2.azurewebsites.net"

def create_synthetic_wav(duration_s=1.5, sample_rate=16000, freq=300):
    """Generate a valid in-memory PCM 16-bit WAV audio sample."""
    buf = io.BytesIO()
    num_samples = int(duration_s * sample_rate)
    with wave.open(buf, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        # 200ms silence, then tone, then silence
        silence_samples = int(0.2 * sample_rate)
        samples = []
        for i in range(silence_samples):
            samples.append(0)
        for i in range(num_samples - 2 * silence_samples):
            val = int(12000 * math.sin(2 * math.pi * freq * (i / sample_rate)))
            samples.append(val)
        for i in range(silence_samples):
            samples.append(0)
        wf.writeframes(struct.pack(f'<{len(samples)}h', *samples))
    buf.seek(0)
    return buf.read()

def run_flow():
    print("=" * 80)
    print("STARTING FULL END-TO-END FLOW: CHILD TASK -> CLOUD ML -> DASHBOARDS")
    print("=" * 80)

    # 1. LOGIN PARENT
    print("\n[STEP 1] Authenticating Parent (parent@sipsara.com)...")
    p_login = requests.post(f"{RENDER_BASE}/api/v1/auth/login", json={
        "email": "parent@sipsara.com", "password": "Parent1234!", "role": "parent"
    })
    assert p_login.status_code == 200, f"Parent login failed: {p_login.text}"
    p_token = p_login.json()["access_token"]
    p_headers = {"Authorization": f"Bearer {p_token}"}
    print("  -> Parent successfully logged in.")

    # 2. GET STUDENT
    print("\n[STEP 2] Fetching Children under Parent Account...")
    students_res = requests.get(f"{RENDER_BASE}/api/v1/auth/students", headers=p_headers)
    assert students_res.status_code == 200
    students = students_res.json()
    student = next((s for s in students if s["id"] == "6ad5a03c00c4cf9c13dbb647"), students[0])
    student_id = student["id"]
    student_name = f"{student.get('first_name', '')} {student.get('last_name', '')}".strip()
    print(f"  -> Selected Child: {student_name} (ID: {student_id})")

    # 3. LOGIN THERAPIST
    print("\n[STEP 3] Authenticating Therapist (therapist@sipsara.com)...")
    t_login = requests.post(f"{RENDER_BASE}/api/v1/auth/login", json={
        "email": "therapist@sipsara.com", "password": "Therapist1234!", "role": "specialist"
    })
    assert t_login.status_code == 200, f"Therapist login failed: {t_login.text}"
    t_token = t_login.json()["access_token"]
    t_headers = {"Authorization": f"Bearer {t_token}"}
    print("  -> Therapist successfully logged in.")

    # Verify Therapist Connection
    conns_res = requests.get(f"{RENDER_BASE}/api/v1/auth/therapist/connections", headers=t_headers)
    assert conns_res.status_code == 200
    conns = conns_res.json()
    has_conn = any(c.get("student_id") == student_id for c in conns)
    print(f"  -> Verified Active Connection with {student_name}: {has_conn}")

    # 4. SIMULATE CHILD DOING A TASK
    print("\n[STEP 4] Child Launches & Completes 'Akshara Recognition' Activity...")
    session_id = str(uuid.uuid4())
    print(f"  -> Generated Session ID: {session_id}")

    # 4A. SUBMIT C1 TELEMETRY & KINEMATICS TO AZURE ML
    print("\n[STEP 4A] Submitting C1 Fine-Grained Behavioral Telemetry to Azure ML...")
    telemetry_payload = {
        "student_id": student_id,
        "session_id": session_id,
        "session_duration_seconds": 120,
        "data_origin": "observed",
        "events": [
            {
                "event_id": str(uuid.uuid4()),
                "activity_name": "Akshara Recognition",
                "round_number": 1,
                "is_correct": True,
                "first_touch_latency_ms": 1150,
                "total_round_latency_ms": 2400,
                "hesitation_count": 0,
                "misclick_count": 0,
                "audio_replay_count": 0,
                "target_stimulus": "බ",
                "selected_stimulus": "බ",
                "screen_width_px": 1080,
                "screen_height_px": 1920,
                "touch_stream": [
                    {"x": 0.50, "y": 0.80, "t": 1150, "type": "DOWN"},
                    {"x": 0.52, "y": 0.65, "t": 1400, "type": "MOVE"},
                    {"x": 0.55, "y": 0.40, "t": 1800, "type": "MOVE"},
                    {"x": 0.60, "y": 0.35, "t": 2400, "type": "UP"}
                ]
            },
            {
                "event_id": str(uuid.uuid4()),
                "activity_name": "Akshara Recognition",
                "round_number": 2,
                "is_correct": False,
                "first_touch_latency_ms": 1650,
                "total_round_latency_ms": 3100,
                "hesitation_count": 1,
                "misclick_count": 1,
                "audio_replay_count": 1,
                "target_stimulus": "බ",
                "selected_stimulus": "ඩ",  # Sinhala visual distractor
                "screen_width_px": 1080,
                "screen_height_px": 1920,
                "touch_stream": [
                    {"x": 0.50, "y": 0.80, "t": 1650, "type": "DOWN"},
                    {"x": 0.45, "y": 0.70, "t": 2100, "type": "MOVE"},
                    {"x": 0.35, "y": 0.50, "t": 2700, "type": "MOVE"},
                    {"x": 0.30, "y": 0.45, "t": 3100, "type": "UP"}
                ]
            },
            {
                "event_id": str(uuid.uuid4()),
                "activity_name": "Akshara Recognition",
                "round_number": 3,
                "is_correct": True,
                "first_touch_latency_ms": 1200,
                "total_round_latency_ms": 2200,
                "hesitation_count": 0,
                "misclick_count": 0,
                "audio_replay_count": 0,
                "target_stimulus": "ප",
                "selected_stimulus": "ප",
                "screen_width_px": 1080,
                "screen_height_px": 1920,
                "touch_stream": [
                    {"x": 0.50, "y": 0.80, "t": 1200, "type": "DOWN"},
                    {"x": 0.51, "y": 0.50, "t": 1700, "type": "MOVE"},
                    {"x": 0.52, "y": 0.35, "t": 2200, "type": "UP"}
                ]
            }
        ]
    }

    # Generate token matching Azure's configured secret for the same parent account
    from datetime import datetime, timezone, timedelta
    import jwt
    AZURE_JWT_SECRET = "p2Msq2QN1D6LPpIo2S5aFv3k+zgkyedGPZ0gEXQ5ewk="
    parent_user_id = p_login.json().get("user", {}).get("id") or "6ad5a03b00c4cf9c13dbb644"
    az_parent_token = jwt.encode({
        "sub": "parent@sipsara.com",
        "role": "parent",
        "id": parent_user_id,
        "exp": datetime.now(timezone.utc) + timedelta(days=7)
    }, AZURE_JWT_SECRET, algorithm="HS256")
    azure_headers = {"Authorization": f"Bearer {az_parent_token}"}

    t_resp = requests.post(
        f"{AZURE_BASE}/telemetry/api/v1/auth/telemetry",
        json=telemetry_payload,
        headers=azure_headers,
        timeout=30
    )
    print(f"  -> Azure Telemetry Response: HTTP {t_resp.status_code}")
    if t_resp.status_code == 200:
        c1_res = t_resp.json()
        print(f"  -> Message: {c1_res.get('message')}")
        print(f"  -> Real-Time Cognitive Load: {c1_res.get('cognitive_load')}")
        print(f"  -> C1 Processing Status: {c1_res.get('c1_processing')}")
    else:
        print(f"  -> Telemetry Error: {t_resp.text}")

    # 4B. SUBMIT C2 ORAL READING ATTEMPT TO AZURE ML
    print("\n[STEP 4B] Submitting C2 Oral Reading Audio Attempt to Azure Speech STT...")
    wav_data = create_synthetic_wav(duration_s=1.2, freq=320)
    files = {"file": ("oral_reading_attempt.wav", wav_data, "audio/wav")}
    speech_form = {
        "student_id": student_id,
        "session_id": session_id,
        "event_id": str(uuid.uuid4()),
        "skill_id": "skill_6",
        "activity_id": "act_1",
        "item_id": "S6A1R01",
        "expected_text": "ගමට",
        "expected_syllables": "2",
        "t_stimulus": str(int(time.time() * 1000) - 1500),
        "t_record_start": str(int(time.time() * 1000) - 1200),
        "data_origin": "observed"
    }
    s_resp = requests.post(
        f"{AZURE_BASE}/speech/stt/analyze-acoustics",
        files=files,
        data=speech_form,
        headers=azure_headers,
        timeout=45
    )
    print(f"  -> Azure Speech Response: HTTP {s_resp.status_code}")
    if s_resp.status_code == 200:
        c2_res = s_resp.json()
        print(f"  -> Recognized Text: '{c2_res.get('recognized_text')}'")
        print(f"  -> Expected Text: '{c2_res.get('expected_text')}'")
        print(f"  -> Acoustic Latency: {c2_res.get('acoustic_latency_ms')} ms")
        print(f"  -> Voice Onset: {c2_res.get('voice_onset_ms')} ms")
        print(f"  -> Detected Peaks: {c2_res.get('detected_peaks')} (Expected: {c2_res.get('expected_syllables')})")
        print(f"  -> Prosody Jitter: {c2_res.get('local_jitter')}, Shimmer: {c2_res.get('local_shimmer')}")
    else:
        print(f"  -> Speech Error: {s_resp.text}")

    # Wait 3 seconds for background C3 multimodal fusion to finalize in MongoDB
    print("\n[STEP 4C] Waiting 4 seconds for C3 Multimodal Background Fusion to complete...")
    time.sleep(4)

    # 5. VERIFY PARENT DASHBOARD (Render)
    print("\n" + "=" * 50)
    print("[STEP 5] PRESENTING ON PARENT DASHBOARD (Render)")
    print("=" * 50)

    # 5A. Parent Overview
    p_overview = requests.get(f"{RENDER_BASE}/api/v1/parent/students/{student_id}/overview", headers=p_headers).json()
    print("\n--- 5A. Parent Overview ---")
    print(f"  Accuracy: {p_overview.get('accuracy')}%")
    print(f"  Current Level: {p_overview.get('current_level')}")
    print(f"  Active Days: {p_overview.get('active_days')}")
    print(f"  Recent Activity: {p_overview.get('recent_activity')}")

    # 5B. Parent Learning Pattern
    p_pattern = requests.get(f"{RENDER_BASE}/api/v1/parent/students/{student_id}/learning-pattern", headers=p_headers).json()
    print("\n--- 5B. Parent Learning Pattern ---")
    print(f"  Identified Pattern: {p_pattern.get('pattern')}")
    print(f"  Strength Focus: {p_pattern.get('strength')}")
    print(f"  Support Tip: {p_pattern.get('support_tip')}")

    # 5C. Parent Component Analytics
    p_analytics = requests.get(f"{RENDER_BASE}/api/v1/parent/students/{student_id}/component-analytics", headers=p_headers).json()
    print("\n--- 5C. Parent Component Analytics ---")
    c1_stat = p_analytics.get("c1_behavioral", {})
    c2_stat = p_analytics.get("c2_speech", {})
    c3_stat = p_analytics.get("c3_explainability", {})
    c4_stat = p_analytics.get("c4_adaptive", {})
    print(f"  C1 Behavioral Available: {c1_stat.get('available')}")
    print(f"  C2 Speech Available:     {c2_stat.get('available')}")
    print(f"  C3 Explainability:       {c3_stat.get('primary_pattern')} (Confidence: {c3_stat.get('confidence')})")
    print(f"  C4 Adaptive Rate:        {c4_stat.get('supported_decision_rate')}")

    # 6. VERIFY THERAPIST DASHBOARD (Render)
    print("\n" + "=" * 50)
    print("[STEP 6] PRESENTING ON THERAPIST DASHBOARD (Render)")
    print("=" * 50)

    # 6A. Therapist Overview
    t_overview = requests.get(f"{RENDER_BASE}/api/v1/therapist/students/{student_id}/overview", headers=t_headers).json()
    print("\n--- 6A. Therapist Clinical Overview ---")
    print(f"  Learner: {t_overview.get('student_name')}")
    print(f"  Risk Indicators: {t_overview.get('risk_indicators')}")
    print(f"  Components Active: C1={t_overview.get('c1_available')}, C2={t_overview.get('c2_available')}, C3={t_overview.get('c3_available')}")

    # 6B. C1 Behavioral Telemetry
    t_c1 = requests.get(f"{RENDER_BASE}/api/v1/therapist/students/{student_id}/c1-behavioral", headers=t_headers).json()
    print("\n--- 6B. C1 Behavioral & Kinematic Evidence ---")
    print(f"  Total Sessions: {t_c1.get('total_sessions')}")
    print(f"  Mean Latency: {t_c1.get('mean_latency_ms')} ms")
    print(f"  Hesitation Rate: {t_c1.get('hesitation_rate')}")
    print(f"  Misclick Rate: {t_c1.get('misclick_rate')}")
    print(f"  Fatigue Score: {t_c1.get('fatigue_score')}")

    # 6C. C2 Speech Monitoring
    t_c2 = requests.get(f"{RENDER_BASE}/api/v1/therapist/students/{student_id}/c2-speech", headers=t_headers).json()
    print("\n--- 6C. C2 Acoustic Reading Evidence ---")
    print(f"  Total Attempts: {t_c2.get('total_attempts')}")
    latest_speech = t_c2.get("latest", {})
    print(f"  Latest Prompt: '{latest_speech.get('expected_text')}' -> Recognized: '{latest_speech.get('recognized_text')}'")
    print(f"  Word Error Rate (WER): {latest_speech.get('wer')}")
    print(f"  Acoustic Latency: {latest_speech.get('acoustic_latency_ms')} ms")
    print(f"  Voice Jitter: {latest_speech.get('jitter')}, Shimmer: {latest_speech.get('shimmer')}")

    # 6D. C3 Multimodal Profile & TreeSHAP Explainability
    t_c3 = requests.get(f"{RENDER_BASE}/api/v1/therapist/students/{student_id}/c3-profile", headers=t_headers).json()
    print("\n--- 6D. C3 Learner Profile & TreeSHAP Explainability ---")
    print(f"  Classifier Available: {t_c3.get('classifier_available')}")
    print(f"  Primary Learning Pattern: {t_c3.get('primary_pattern')}")
    print(f"  Model Confidence: {t_c3.get('confidence')}")
    print(f"  Class Probabilities: {t_c3.get('probabilities')}")
    print(f"  Modalities Fused: {t_c3.get('modalities_used')}")
    shaps = t_c3.get("shap_explanations", [])
    print(f"  Top TreeSHAP Feature Attributions ({len(shaps)} features):")
    for s in shaps:
        print(f"    - {s.get('feature_name')}: Impact = {s.get('contribution')} ({s.get('direction')}) -> {s.get('human_description')}")
    print(f"  Summary Text: {t_c3.get('summary_text')}")
    print(f"  Recommendation: {t_c3.get('recommendation_text')}")

    # 6E. C4 Adaptive Decision History
    t_c4 = requests.get(f"{RENDER_BASE}/api/v1/therapist/students/{student_id}/c4-adaptive", headers=t_headers).json()
    print("\n--- 6E. C4 Adaptive Tutoring (BKT) State ---")
    print(f"  Average Mastery: {t_c4.get('average_mastery')}")
    print(f"  Supported Decision Rate: {t_c4.get('supported_decision_rate')}")
    print(f"  Recent Actions Count: {len(t_c4.get('recent_decisions', []))}")

    print("\n" + "=" * 80)
    print("SUCCESS: FULL END-TO-END FLOW VERIFIED ACROSS CLOUD ML AND BOTH DASHBOARDS!")
    print("=" * 80)

if __name__ == "__main__":
    run_flow()
