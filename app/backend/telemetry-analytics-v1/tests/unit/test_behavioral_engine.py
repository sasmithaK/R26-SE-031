import pytest
from schemas.telemetry import TelemetrySessionSubmit, TelemetryEvent
from services.behavioral_engine import extract_session_features

def create_mock_event(is_correct=True, latency=1000, error_type="unknown_error", kc="KC_UNKNOWN", is_abandoned=False, aid="test_activity", hes=0, rep=0):
    return TelemetryEvent(
        event_id="e1",
        activity_name="test_act",
        round_number=1,
        is_correct=is_correct,
        first_touch_latency_ms=latency,
        total_round_latency_ms=latency+500,
        error_type=error_type,
        knowledge_component_id=kc,
        is_abandoned=is_abandoned,
        activity_id=aid,
        hesitation_count=hes,
        audio_replay_count=rep,
        prompt_modality="audio" if rep > 0 else "visual"
    )

def test_perfect_session():
    events = [create_mock_event(is_correct=True, latency=1000) for _ in range(5)]
    session = TelemetrySessionSubmit(student_id="s1", session_id="ses1", session_duration_seconds=60, events=events)
    summary = extract_session_features(session)
    assert summary.overall["accuracy"] == 1.0
    assert summary.overall["error_rate"] == 0.0
    assert summary.overall["median_response_latency_ms"] == 1000

def test_all_incorrect_session():
    events = [create_mock_event(is_correct=False, latency=1000, error_type="visual_confusion") for _ in range(5)]
    session = TelemetrySessionSubmit(student_id="s1", session_id="ses1", session_duration_seconds=60, events=events)
    summary = extract_session_features(session)
    assert summary.overall["accuracy"] == 0.0
    assert summary.overall["error_rate"] == 1.0
    assert summary.error_profile["visual_confusion_rate"] == 1.0

def test_mixed_session_and_kc_aggregation():
    events = [
        create_mock_event(is_correct=True, latency=1000, kc="KC_AKSHARA_IDENTITY"),
        create_mock_event(is_correct=False, latency=2000, kc="KC_AKSHARA_IDENTITY", error_type="visual_confusion"),
        create_mock_event(is_correct=True, latency=1500, kc="KC_WORD_RECOGNITION")
    ]
    session = TelemetrySessionSubmit(student_id="s1", session_id="ses1", session_duration_seconds=60, events=events)
    summary = extract_session_features(session)
    assert summary.overall["accuracy"] == pytest.approx(0.666, 0.01)
    
    akshara = summary.knowledge_components.get("KC_AKSHARA_IDENTITY")
    assert akshara is not None
    assert akshara["accuracy"] == 0.5
    assert akshara["median_response_latency_ms"] == 1500
    assert akshara["error_distribution"]["visual_confusion"] == 1.0

def test_zero_valid_events_division_by_zero():
    events = [create_mock_event(is_abandoned=True)]
    session = TelemetrySessionSubmit(student_id="s1", session_id="ses1", session_duration_seconds=60, events=events)
    summary = extract_session_features(session)
    assert summary.overall["accuracy"] == 0.0
    assert summary.overall["error_rate"] == 0.0
    assert summary.overall["abandonment_rate"] == 1.0

def test_fatigue_with_sufficient_trials():
    events = [
        create_mock_event(is_correct=True, latency=1000, hes=0),
        create_mock_event(is_correct=True, latency=1000, hes=0),
        create_mock_event(is_correct=True, latency=2000, hes=1),
        create_mock_event(is_correct=False, latency=3000, hes=2)
    ]
    session = TelemetrySessionSubmit(student_id="s1", session_id="ses1", session_duration_seconds=60, events=events)
    summary = extract_session_features(session)
    assert summary.behavioral_fatigue_proxy is not None
    assert "latency_drift" in summary.fatigue_components

def test_fatigue_with_insufficient_trials():
    events = [create_mock_event() for _ in range(3)]
    session = TelemetrySessionSubmit(student_id="s1", session_id="ses1", session_duration_seconds=60, events=events)
    summary = extract_session_features(session)
    assert summary.behavioral_fatigue_proxy is None
