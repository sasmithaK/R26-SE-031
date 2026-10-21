"""One C1 definition across therapist and parent dashboards (Savi scenario).

A learner plays Skill 1 Activity 1 in five sessions: 7 completed rounds, all
correct on the first try, and three sessions that ended before any round was
finished. Every dashboard must say 100% (7 rounds), never 73%, and attempts
per round must be 1.0, never 0.7.
"""
import asyncio
import unittest
from datetime import datetime, timedelta, timezone

from bson import ObjectId

from tests.test_pp2_dashboard_contracts import Database, STUDENT, OWNER
from routers import therapist_dashboard as therapist, parent_dashboard as parent
from services import dashboard_access
from services.dashboard_data import speech

NOW = datetime.now(timezone.utc)


def rnd(sid, n, first=1500, correct_ms=4000, abandoned=False):
    return {"event_id": f"{sid}:S1A1R0{n}:{'abandoned' if abandoned else 'complete'}",
            "skill_id": "skill_1", "activity_id": "act_1", "activity_name": "visual_hidden_search",
            "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
            "is_abandoned": abandoned, "is_correct": not abandoned, "final_correct": not abandoned,
            "first_attempt_correct": None if abandoned else True, "attempt_count": 1,
            "first_touch_latency_ms": 0 if abandoned else first, "time_to_correct_ms": 0 if abandoned else correct_ms,
            "total_round_latency_ms": 30000 if abandoned else correct_ms, "correction_count": 0}


def session(n, events, abandoned_only=False):
    sid = f"sess-{n}"
    return dict(_id=f"{n:03}", student_id=STUDENT, session_id=sid, schema_version="2.0",
                completed_at=(NOW - timedelta(hours=n)).isoformat(), session_duration_seconds=40,
                events=events)


class C1ConsistencyTests(unittest.TestCase):
    def setUp(self):
        sessions = [
            session(1, [rnd("sess-1", 1), rnd("sess-1", 2), rnd("sess-1", 2), rnd("sess-1", 3, abandoned=True)]),
            session(2, [rnd("sess-2", 1, abandoned=True)]),
            session(3, [rnd("sess-3", 1), rnd("sess-3", 2), rnd("sess-3", 3)]),
            session(4, [rnd("sess-4", 1, abandoned=True)]),
            session(5, [rnd("sess-5", 1), rnd("sess-5", 2), rnd("sess-5", 3, abandoned=True)]),
        ]
        # sess-1 has a duplicate copy of round 2 (offline replay): counted once.
        summaries = []
        for i, s in enumerate(sessions, start=1):
            done = [e for e in s["events"] if not e["is_abandoned"]]
            summaries.append(dict(_id=s["_id"], student_id=STUDENT, session_id=s["session_id"],
                                  completed_at=s["completed_at"], total_trials=len(s["events"]),
                                  overall={"accuracy": 1.0 if done else 0.0,
                                           "mean_attempts_per_round": 1.0 if done else 0.0,
                                           "abandonment_rate": 1 - len(done) / len(s["events"])},
                                  knowledge_components={}, error_profile={}))
        self.db = Database(students=[{"_id": ObjectId(STUDENT), "parent_id": OWNER}],
                           telemetry_sessions=sessions, session_summaries=summaries,
                           telemetry_events=[{"student_id": STUDENT, "knowledge_component_id": "KC_VISUAL_IDENTIFICATION",
                                              "is_abandoned": False}],
                           knowledge_states=[{"student_id": STUDENT, "knowledge_state": {
                               "KC_VISUAL_IDENTIFICATION": 0.9, "KC_LETTER_MEMORY": 0.2, "KC_WORD_RECOGNITION": 0.15}}])
        for module in (therapist, parent, dashboard_access):
            module.get_db = lambda: self.db

    def call(self, fn, *args):
        return asyncio.run(fn(*args))

    def test_therapist_summary_and_activities_agree(self):
        overview = self.call(therapist.get_therapist_overview, STUDENT)
        c1 = self.call(therapist.get_therapist_c1_behavioral, STUDENT, 30)
        self.assertEqual(overview.accuracy, 1.0)
        self.assertEqual(c1.first_attempt_accuracy, 1.0)
        self.assertEqual(c1.mean_attempts_per_round, 1.0)
        self.assertEqual(c1.retry_rate, 0.0)
        self.assertEqual(c1.window["completed_rounds"], 7)
        self.assertEqual(c1.window["sessions_started"], 5)
        self.assertEqual(c1.window["sessions_ended_early"], 2)
        self.assertEqual(overview.attempted_items, 7)
        # Mastery averages practised areas only (0.9), not the untouched priors.
        self.assertAlmostEqual(overview.overall_mastery, 0.9)
        self.assertEqual(overview.mastery_practised_areas, 1)

    def test_parent_matches_therapist(self):
        overview = self.call(parent.get_parent_overview, STUDENT)
        analytics = self.call(parent.get_parent_component_analytics, STUDENT)
        perf = self.call(parent.get_parent_activity_performance, STUDENT, 30, None, 100)
        self.assertEqual(overview.accuracy, 100)
        self.assertEqual(overview.completed_rounds, 7)
        self.assertEqual(analytics["c1_behavioral"]["first_attempt_accuracy"], 1.0)
        self.assertEqual(analytics["c1_behavioral"]["median_response_latency_ms"],
                         overview.median_response_latency_ms)
        row = perf["activities"][0]
        self.assertEqual((row["trials"], row["first_attempt_accuracy"]), (7, 1.0))

    def test_unusable_recording_has_no_accuracy(self):
        failed = speech({"measurement_status": "retry_required", "recording_quality": "retry_required",
                         "word_accuracy": 0.0, "grapheme_accuracy": 0.0, "word_error_rate": 1.0})
        self.assertFalse(failed["measured"])
        self.assertIsNone(failed["word_accuracy"])
        self.assertIsNone(failed["wer"])
        ok = speech({"measurement_status": "valid", "word_accuracy": 0.8, "recognized_text": "x"})
        self.assertTrue(ok["measured"])
        self.assertEqual(ok["word_accuracy"], 0.8)


if __name__ == "__main__":
    unittest.main()
