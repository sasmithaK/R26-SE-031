#!/usr/bin/env python3
"""
R26-SE-031 Complete Integration Test Suite
===========================================

Tests all backend services and their endpoints.
Run with: python tests/test_api_e2e.py
"""

import json
import sys
import time
from urllib import error, request
from typing import Dict, Any, List, Tuple

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

DEFAULT_TIMEOUT_SECONDS = 30

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# SERVICE ENDPOINTS
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

SERVICES = {
    'C1': 'http://127.0.0.1:8011/api/v1',
    'C2': 'http://127.0.0.1:8014/api/v1',
    'C3': 'http://127.0.0.1:8012/api/v1',
    'C4': 'http://127.0.0.1:8013/api/v1',
}


def service_root(base_url: str) -> str:
    """Health endpoints are mounted at service root, not under /api/v1."""
    return base_url.removesuffix('/api/v1')


class SimpleResponse:
    def __init__(self, status_code: int, body: str):
        self.status_code = status_code
        self._body = body

    def json(self) -> Dict[str, Any]:
        return json.loads(self._body or "{}")


def http_request(
    method: str,
    url: str,
    json_body: Dict[str, Any] | None = None,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> SimpleResponse:
    body = None
    headers = {}
    if json_body is not None:
        body = json.dumps(json_body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = request.Request(url, data=body, headers=headers, method=method)
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            return SimpleResponse(resp.status, resp.read().decode("utf-8"))
    except error.HTTPError as exc:
        return SimpleResponse(exc.code, exc.read().decode("utf-8"))

ENDPOINTS = {
    'C1': [
        ('GET', '/health', 'Health check'),
        ('POST', '/telemetry', 'Telemetry ingestion'),
        ('GET', '/mbsv/test_student', 'Get MBSV'),
        ('GET', '/monitoring/baseline/test_student', 'Get baseline'),
    ],
    'C2': [
        ('GET', '/health', 'Health check'),
        ('POST', '/ui/typography', 'Request typography'),
        ('POST', '/ui/reward', 'Send reward feedback'),
    ],
    'C3': [
        ('GET', '/health', 'Health check'),
        ('POST', '/mastery/update', 'Update mastery'),
        ('GET', '/mastery/test_student', 'Get mastery vector'),
        ('GET', '/content/next/test_student', 'Get content recommendation'),
    ],
    'C4': [
        ('GET', '/health', 'Health check'),
        ('POST', '/intervention/check', 'Check intervention'),
        ('GET', '/intervention/sm2/schedule/test_student', 'Get SM-2 schedule'),
    ],
}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# TEST FUNCTIONS
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

def test_service_health(service_name: str, base_url: str) -> Tuple[bool, str]:
    """Test if service is responding to health checks."""
    try:
        resp = http_request("GET", f"{service_root(base_url)}/health", timeout=DEFAULT_TIMEOUT_SECONDS)
        if resp.status_code == 200:
            return True, "âœ“ Service running"
        else:
            return False, f"âœ— Health returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— Connection failed: {str(e)}"


def test_c1_telemetry(base_url: str) -> Tuple[bool, str]:
    """Test C1 telemetry ingestion."""
    try:
        payload = {
            "student_id": "test_student",
            "session_id": "test_session",
            "task_id": "test_task",
            "timestamp_ms": int(time.time() * 1000),
            "event_type": "TAP",
            "session_latency_ms": 1500,
            "hesitation_ms": 800,
            "correction_rate": 0.1,
            "replay_count": 0,
            "hint_request_count": 0,
            "touch_events": [
                {"x": 100, "y": 200, "pressure": 0.5, "timestamp_ms": int(time.time() * 1000)}
            ],
        }

        resp = http_request("POST", f"{base_url}/telemetry", json_body=payload, timeout=DEFAULT_TIMEOUT_SECONDS)

        if resp.status_code == 200:
            data = resp.json()
            if 'mbsv' in data:
                return True, "âœ“ Telemetry processed, MBSV computed"
            else:
                return False, "âœ— No MBSV in response"
        else:
            return False, f"âœ— Telemetry returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— Telemetry error: {str(e)}"


def test_c1_mbsv_retrieval(base_url: str) -> Tuple[bool, str]:
    """Test C1 MBSV retrieval."""
    try:
        resp = http_request("GET", f"{base_url}/mbsv/test_student", timeout=DEFAULT_TIMEOUT_SECONDS)

        if resp.status_code == 200:
            data = resp.json()
            required_fields = [
                'visual_strain_index', 'cognitive_load_index', 'phonological_strain_index',
                'engagement_index', 'session_fatigue_index'
            ]

            mbsv = data.get('mbsv', {})
            missing = [f for f in required_fields if f not in mbsv]

            if missing:
                return False, f"âœ— Missing fields: {missing}"
            else:
                return True, f"âœ“ MBSV retrieved: phono={mbsv['phonological_strain_index']:.2f}"
        else:
            return False, f"âœ— MBSV returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— MBSV error: {str(e)}"


def test_c2_typography(base_url: str) -> Tuple[bool, str]:
    """Test C2 typography selection."""
    try:
        payload = {
            "student_id": "test_student",
            "session_id": "test_session",
            "visual_strain_index": 0.6,
            "engagement_index": 0.8,
            "phonological_strain_index": 0.3,
            "current_content_text": "à¶šà¶¸à¶½",
        }

        resp = http_request("POST", f"{base_url}/ui/typography", json_body=payload, timeout=DEFAULT_TIMEOUT_SECONDS)

        if resp.status_code == 200:
            data = resp.json()
            if 'typography_config' in data:
                config = data['typography_config']
                return True, f"âœ“ Typography selected: size={config.get('font_size', 'N/A')}"
            else:
                return False, "âœ— No typography_config in response"
        else:
            return False, f"âœ— Typography returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— Typography error: {str(e)}"


def test_c3_mastery(base_url: str) -> Tuple[bool, str]:
    """Test C3 mastery retrieval."""
    try:
        resp = http_request("GET", f"{base_url}/mastery/test_student", timeout=DEFAULT_TIMEOUT_SECONDS)

        if resp.status_code == 200:
            data = resp.json()
            mastery_vector = data.get("mastery_vector", {})
            if isinstance(mastery_vector, dict) and len(mastery_vector) > 0:
                return True, f"âœ“ Mastery retrieved: {len(mastery_vector)} skills"
            else:
                return False, "âœ— Empty mastery vector"
        else:
            return False, f"âœ— Mastery returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— Mastery error: {str(e)}"


def test_c3_bkt_update(base_url: str) -> Tuple[bool, str]:
    """Test C3 BKT update."""
    try:
        payload = {
            "student_id": "test_student",
            "session_id": "test_session",
            "skill_id": "S3_syllable_formation",
            "is_correct": True,
            "response_latency_ms": 1500,
            "cognitive_load_index": 0.4,
            "session_fatigue_index": 0.2,
        }

        resp = http_request("POST", f"{base_url}/mastery/update", json_body=payload, timeout=DEFAULT_TIMEOUT_SECONDS)

        if resp.status_code == 200:
            return True, "âœ“ BKT mastery updated"
        else:
            return False, f"âœ— BKT update returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— BKT update error: {str(e)}"


def test_c4_intervention(base_url: str) -> Tuple[bool, str]:
    """Test C4 intervention check."""
    try:
        payload = {
            "student_id": "test_student",
            "session_id": "test_session",
            "current_word": "à¶šà¶¸à¶½",
            "phonological_strain_index": 0.7,
            "error_pattern_vector": [0, 1, 0, 1],
            "strain_duration_ms": 6000,
        }

        resp = http_request("POST", f"{base_url}/intervention/check", json_body=payload, timeout=DEFAULT_TIMEOUT_SECONDS)

        if resp.status_code == 200:
            data = resp.json()
            if 'syllable_segments' in data:
                syllables = data['syllable_segments'] or []
                segment_text = ' Â· '.join(syllables) if syllables else 'no segments'
                return True, f"âœ“ Intervention stage {data.get('stage')}: {segment_text}"
            else:
                return False, "âœ— No syllable_segments in response"
        else:
            return False, f"âœ— Intervention returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— Intervention error: {str(e)}"


def test_c4_sm2(base_url: str) -> Tuple[bool, str]:
    """Test C4 SM-2 schedule."""
    try:
        resp = http_request("GET", f"{base_url}/intervention/sm2/schedule/test_student", timeout=DEFAULT_TIMEOUT_SECONDS)

        if resp.status_code == 200:
            data = resp.json()
            due_count = data.get('total_due', len(data.get('review_skills', [])))
            return True, f"âœ“ SM-2 schedule: {due_count} skills due"
        else:
            return False, f"âœ— SM-2 returned {resp.status_code}"
    except Exception as e:
        return False, f"âœ— SM-2 error: {str(e)}"


# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# MAIN TEST RUNNER
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

def run_all_tests() -> int:
    """Run complete integration test suite."""

    print("\n" + "="*70)
    print("R26-SE-031 COMPLETE INTEGRATION TEST")
    print("="*70)

    results = {
        'C1': {'passed': 0, 'failed': 0, 'tests': []},
        'C2': {'passed': 0, 'failed': 0, 'tests': []},
        'C3': {'passed': 0, 'failed': 0, 'tests': []},
        'C4': {'passed': 0, 'failed': 0, 'tests': []},
    }

    # Test each service
    for service_name, base_url in SERVICES.items():
        print(f"\n>>> {service_name} Service ({base_url})")
        print("-" * 70)

        # Health check
        success, msg = test_service_health(service_name, base_url)
        results[service_name]['tests'].append((f"Health check", msg))
        if success:
            results[service_name]['passed'] += 1
        else:
            results[service_name]['failed'] += 1
        print(f"  {msg}")

        # Service-specific tests
        if service_name == 'C1':
            success, msg = test_c1_telemetry(base_url)
            results['C1']['tests'].append(("Telemetry ingestion", msg))
            if success:
                results['C1']['passed'] += 1
            else:
                results['C1']['failed'] += 1
            print(f"  {msg}")

            success, msg = test_c1_mbsv_retrieval(base_url)
            results['C1']['tests'].append(("MBSV retrieval", msg))
            if success:
                results['C1']['passed'] += 1
            else:
                results['C1']['failed'] += 1
            print(f"  {msg}")

        elif service_name == 'C2':
            success, msg = test_c2_typography(base_url)
            results['C2']['tests'].append(("Typography selection", msg))
            if success:
                results['C2']['passed'] += 1
            else:
                results['C2']['failed'] += 1
            print(f"  {msg}")

        elif service_name == 'C3':
            success, msg = test_c3_mastery(base_url)
            results['C3']['tests'].append(("Mastery retrieval", msg))
            if success:
                results['C3']['passed'] += 1
            else:
                results['C3']['failed'] += 1
            print(f"  {msg}")

            success, msg = test_c3_bkt_update(base_url)
            results['C3']['tests'].append(("BKT update", msg))
            if success:
                results['C3']['passed'] += 1
            else:
                results['C3']['failed'] += 1
            print(f"  {msg}")

        elif service_name == 'C4':
            success, msg = test_c4_intervention(base_url)
            results['C4']['tests'].append(("Intervention check", msg))
            if success:
                results['C4']['passed'] += 1
            else:
                results['C4']['failed'] += 1
            print(f"  {msg}")

            success, msg = test_c4_sm2(base_url)
            results['C4']['tests'].append(("SM-2 schedule", msg))
            if success:
                results['C4']['passed'] += 1
            else:
                results['C4']['failed'] += 1
            print(f"  {msg}")

    # Summary
    print("\n" + "="*70)
    print("TEST SUMMARY")
    print("="*70)

    total_passed = 0
    total_failed = 0

    for service_name in ['C1', 'C2', 'C3', 'C4']:
        passed = results[service_name]['passed']
        failed = results[service_name]['failed']
        total_passed += passed
        total_failed += failed
        status = "âœ“ PASS" if failed == 0 else "âœ— FAIL"
        print(f"{service_name}: {passed} passed, {failed} failed {status}")

    print("\n" + "="*70)
    if total_failed == 0:
        print(f"âœ“ ALL {total_passed} TESTS PASSED!")
        print("="*70)
        return 0
    else:
        print(f"âœ— {total_failed} TEST(S) FAILED, {total_passed} passed")
        print("="*70)
        return 1


if __name__ == '__main__':
    exit(run_all_tests())
