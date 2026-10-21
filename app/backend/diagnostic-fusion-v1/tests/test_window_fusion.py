"""C3 learner-window fusion: no imputation, minimum evidence, gender marginalisation."""
import asyncio
import copy
from datetime import datetime, timedelta, timezone

from bson import ObjectId

import main
from schemas import SessionFusionRequest
from services.xai_engine import get_xai_engine

STUDENT = str(ObjectId())
NOW = datetime.now(timezone.utc)


class Cursor:
    def __init__(self, rows): self.rows = copy.deepcopy(rows)
    def sort(self, *_): return self
    async def to_list(self, length): return self.rows[:length]


class Collection:
    def __init__(self, rows=None): self.rows = rows or []; self.writes = []
    def find(self, query): return Cursor([r for r in self.rows if r.get("student_id") == query.get("student_id")])
    async def find_one(self, query): return next((r for r in self.rows if r.get("_id") == query.get("_id")), None)
    async def update_one(self, flt, update, upsert=False): self.writes.append(update["$set"])
    async def insert_one(self, doc): self.writes.append(doc)


class DB(dict):
    def __getattr__(self, key): return self.setdefault(key, Collection())
    def __getitem__(self, key): return self.setdefault(key, Collection())


def speech(i, **extra):
    return {"student_id": STUDENT, "created_at": NOW - timedelta(days=i), "measurement_status": "valid",
            "acoustic_latency_ms": 900 + i, "syllabic_event_mismatch": 1, "expected_syllables": 8,
            "intra_word_silence_ratio": 0.2,
            "local_jitter": 0.03, "local_shimmer": 0.05, "word_accuracy": 0.8, **extra}


def motion(i):
    return {"student_id": STUDENT, "timestamp": (NOW - timedelta(days=i)).isoformat(),
            "time_to_first_touch_ms": 1500, "orthographic_confusion_index": 0.1,
            "path_efficiency_ratio": 0.8, "dimensionless_jerk": 60, "dwell_time_ms": 300}


def run(db):
    main.get_db = lambda: db
    async def allow(*_): return None
    main.require_student_access = allow
    req = SessionFusionRequest(student_id=STUDENT, session_id="s1")
    return asyncio.run(main.diagnose_saved_session(req, get_xai_engine(), {"_id": "p"}))


def test_missing_reading_evidence_skips_model_without_defaults():
    db = DB(students=Collection([{"_id": ObjectId(STUDENT), "age_months": 80}]),
            kinematic_features=Collection([motion(1), motion(2)]))
    out = run(db)
    assert out["model_applied"] is False
    assert out["pipeline_status"] == "insufficient_evidence"
    assert any(m.startswith("usable_reading_recordings") for m in out["missing_inputs"])
    stored = db.learner_profiles.writes[-1]
    assert stored["model_inputs"] == {}
    assert stored["learner_profile"]["class_probabilities"] == {}


def test_unknown_age_blocks_and_gender_is_not_an_input():
    base = dict(speech_features=Collection([speech(1), speech(2)]),
                kinematic_features=Collection([motion(1), motion(3)]))
    no_age = DB(students=Collection([{"_id": ObjectId(STUDENT)}]), **copy.deepcopy(base))
    assert "age" in run(no_age)["missing_inputs"]

    db = DB(students=Collection([{"_id": ObjectId(STUDENT), "age_months": 80}]), **base)
    out = run(db)
    assert out["model_applied"] is True
    stored = db.learner_profiles.writes[-1]
    profile = stored["learner_profile"]
    assert abs(sum(profile["class_probabilities"].values()) - 1.0) < 0.01
    assert "gender" not in stored["model_inputs"]
    # No C1 learner estimate yet: those inputs are missing, not filled in.
    assert "c1_first_try_accuracy" in stored["not_measured_inputs"]
    names = [f["feature_name"] for f in stored["shap_explanations"]["top_contributing_features"]]
    assert "c1_first_try_accuracy" not in names


def test_out_of_range_inputs_block_the_estimate():
    far = [dict(speech(i), acoustic_latency_ms=60000) for i in (1, 2)]
    db = DB(students=Collection([{"_id": ObjectId(STUDENT), "age_months": 80}]),
            speech_features=Collection(far), kinematic_features=Collection([motion(1), motion(2)]))
    out = run(db)
    assert out["model_applied"] is False
    assert out["pipeline_status"] == "outside_training_range"
    assert out["outside_range"][0]["feature"] == "acoustic_latency_ms"


def test_recordings_without_acoustic_measures_do_not_count():
    """/analyze-reading rows carry a status but no timing/voice measures."""
    bare = [{"student_id": STUDENT, "created_at": NOW - timedelta(days=i), "measurement_status": "valid",
             "word_accuracy": 0.9} for i in (1, 2, 3)]
    db = DB(students=Collection([{"_id": ObjectId(STUDENT), "age_months": 80}]),
            speech_features=Collection(bare), kinematic_features=Collection([motion(1), motion(2)]))
    out = run(db)
    assert out["model_applied"] is False
    assert any(m.startswith("usable_reading_recordings (0") for m in out["missing_inputs"])


def test_letter_practice_is_not_reading_evidence():
    letters = [dict(speech(i), task_kind="letter_pronunciation", skill_id="skill_sinhala_vowels") for i in (1, 2, 3)]
    db = DB(students=Collection([{"_id": ObjectId(STUDENT), "age_months": 80}]),
            speech_features=Collection(letters), kinematic_features=Collection([motion(1), motion(2)]))
    out = run(db)
    assert out["model_applied"] is False
    assert any(m.startswith("usable_reading_recordings (0") for m in out["missing_inputs"])
