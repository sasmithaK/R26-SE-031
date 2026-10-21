"""Letter-pronunciation practice (C2) never leaks into reading or C1 figures."""
import asyncio
import unittest
from datetime import datetime, timedelta, timezone

from bson import ObjectId

from tests.test_pp2_dashboard_contracts import Database, STUDENT, OWNER
from routers import therapist_dashboard as therapist, parent_dashboard as parent
from services import dashboard_access
from services.dashboard_data import learner_coverage, activity_performance, c1_window_metrics

NOW = datetime.now(timezone.utc)


def letter(i):
    return {"_id": f"L{i:03}", "student_id": STUDENT, "skill_id": "skill_sinhala_vowels", "activity_id": "act_1",
            "item_id": f"SVOWA1R{(i % 12) + 1:02d}", "task_kind": "letter_pronunciation",
            "measurement_status": "uncertain", "recording_quality": "valid", "recognized_text": "අ",
            "created_at": (NOW - timedelta(minutes=i)).isoformat()}


def reading(i):
    return {"_id": f"R{i:03}", "student_id": STUDENT, "skill_id": "skill_6", "activity_id": "act_1",
            "item_id": f"S6A1R0{i}", "measurement_status": "valid", "recording_quality": "valid",
            "word_accuracy": 0.8, "grapheme_accuracy": 0.85, "recognized_text": "x",
            "created_at": (NOW - timedelta(days=2, minutes=i)).isoformat()}


class LetterPracticeSeparation(unittest.TestCase):
    def setUp(self):
        letter_session = {"_id": "TS1", "student_id": STUDENT, "session_id": "ls", "completed_at": NOW.isoformat(),
                          "events": [{"event_id": "ls:1", "skill_id": "skill_sinhala_vowels", "activity_id": "act_1",
                                      "is_abandoned": True}]}
        self.db = Database(students=[{"_id": ObjectId(STUDENT), "parent_id": OWNER}],
                           speech_features=[letter(i) for i in range(60)] + [reading(1), reading(2)],
                           telemetry_sessions=[letter_session])
        for module in (therapist, parent, dashboard_access):
            module.get_db = lambda: self.db

    def call(self, coro):
        return asyncio.run(coro)

    def test_coverage_and_alerts_count_reading_only(self):
        coverage = self.call(learner_coverage(self.db, STUDENT, {}))
        self.assertEqual((coverage["recordings"], coverage["usable_recordings"]), (2, 2))

    def test_activity_performance_has_no_letter_row(self):
        perf = self.call(activity_performance(self.db, STUDENT, 30))
        self.assertTrue(all(row["skill_id"] != "skill_sinhala_vowels" for row in perf["activities"]))
        self.assertTrue(all(row["skill_id"] != "unknown" for row in perf["activities"]))

    def test_sixty_letter_attempts_do_not_hide_reading(self):
        analytics = self.call(parent.get_parent_component_analytics(STUDENT))
        self.assertEqual(analytics["c2_speech"]["recording_count"], 2)
        c2 = self.call(therapist.get_therapist_c2_speech(STUDENT, 30))
        self.assertEqual(c2.recording_count, 2)
        self.assertEqual(c2.letter_recording_count, 60)

    def test_letter_sessions_are_not_c1_sessions(self):
        c1 = self.call(c1_window_metrics(self.db, STUDENT))
        self.assertEqual((c1["sessions_started"], c1["abandoned_rounds"]), (0, 0))


if __name__ == "__main__":
    unittest.main()
