"""Learner-level C1 estimate: evidence rule, missing inputs, out-of-range guard."""
import numpy as np

from research.c1_simulator import load_config, simulate_learner
from services.c1.learner_window import build_learner_features, evidence_gaps
from services.ml.learner_inference import estimate_from_sessions, outside_training_range


def rounds(sid, kc, n, first=2500, total=6000, correct=True, abandon_last=False):
    events = []
    for i in range(n):
        events.append({"event_id": f"{sid}:R{i}:complete", "skill_id": "skill_1", "activity_id": "act_1",
                       "knowledge_component_id": kc, "is_abandoned": False, "is_correct": True,
                       "final_correct": True, "first_attempt_correct": correct, "attempt_count": 1 if correct else 2,
                       "misclick_count": 0 if correct else 1, "hesitation_count": 0, "audio_replay_count": 0,
                       "first_touch_latency_ms": first, "total_round_latency_ms": total})
    if abandon_last:
        events.append({"event_id": f"{sid}:R{n}:abandoned", "skill_id": "skill_1", "is_abandoned": True, "is_correct": False,
                       "knowledge_component_id": kc, "first_touch_latency_ms": 0, "total_round_latency_ms": 30000})
    return ({"session_id": sid}, events)


def test_one_session_is_not_enough_evidence():
    result = estimate_from_sessions([rounds("s1", "KC_VISUAL_IDENTIFICATION", 5)])
    assert result["status"] == "insufficient_evidence"
    assert result["predicted_pattern"] is None and result["probabilities"] == {}
    assert any("completed rounds" in gap for gap in result["missing_evidence"])


def test_picture_only_learner_gets_estimate_with_missing_sound_index():
    sessions = [rounds(f"s{i}", "KC_VISUAL_IDENTIFICATION", 5) for i in range(5)]
    result = estimate_from_sessions(sessions)
    assert result["features"]["phonological_task_index"] is None  # missing, not imputed
    assert result["status"] in {"estimated", "outside_training_range"}
    assert any("sound" in note for note in result["notes"])
    if result["status"] == "estimated":
        assert abs(sum(result["probabilities"].values()) - 1) < 0.01


def test_duplicates_and_abandoned_rounds_are_excluded():
    sid, events = rounds("s1", "KC_VISUAL_IDENTIFICATION", 4, abandon_last=True)
    built = build_learner_features([(sid, events + events[:2])])
    assert built["evidence"]["completed_rounds"] == 4
    assert built["evidence"]["abandoned_rounds"] == 1


def test_out_of_range_inputs_block_the_estimate():
    ranges = {"mean_latency_ms": {"p01": 3000, "p99": 25000}}
    assert outside_training_range({"mean_latency_ms": 120000}, ranges)
    assert not outside_training_range({"mean_latency_ms": 9000}, ranges)
    sessions = [rounds(f"s{i}", "KC_VISUAL_IDENTIFICATION", 5, first=60000, total=200000) for i in range(5)]
    result = estimate_from_sessions(sessions)
    assert result["status"] == "outside_training_range"
    assert result["predicted_pattern"] is None
    assert result["outside_range"]


def test_simulated_learner_runs_through_live_features():
    cfg = load_config()
    rng = np.random.default_rng(7)
    _, sessions = simulate_learner(rng, "COMBINED_PATTERN", cfg, "t")
    built = build_learner_features(sessions)
    assert built["evidence"]["completed_rounds"] >= 0
    assert set(built["features"]) >= {"accuracy", "phonological_task_index", "fatigue_score"}
    assert isinstance(evidence_gaps(built["evidence"]), list)


def test_only_skill_1_to_4_rounds_feed_the_model():
    _, picture = rounds("s1", "KC_VISUAL_IDENTIFICATION", 3)
    letters = [dict(e, skill_id="skill_sinhala_vowels", event_id=e["event_id"] + "L") for e in picture]
    reading = [dict(e, skill_id="skill_5", knowledge_component_id="KC_READING_COMPREHENSION",
                    event_id=e["event_id"] + "R") for e in picture]
    built = build_learner_features([({}, picture), ({}, letters), ({}, reading)])
    assert built["evidence"]["completed_rounds"] == 3
    assert built["evidence"]["sessions"] == 1
    assert built["features"]["phonological_task_index"] is None
