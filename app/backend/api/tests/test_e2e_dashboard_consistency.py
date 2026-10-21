"""End-to-end: simulated sessions -> real C1 ingestion -> every dashboard.

Step 1 (telemetry service, subprocess): ``scripts/e2e_ingest_simulated.py``
posts simulated learners through the real ``/telemetry`` endpoint and dumps
the stored collections plus the expected numbers computed straight from the
simulated rounds. Step 2 (here): the therapist and parent dashboard endpoints
read those collections and must report exactly the expected numbers.
"""
import asyncio
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from bson import ObjectId

from tests.test_pp2_dashboard_contracts import Database
from routers import therapist_dashboard as therapist, parent_dashboard as parent
from services import dashboard_access

TELEMETRY = Path(__file__).resolve().parents[2] / "telemetry-analytics-v1"


def _ingest(learners=8):
    out = Path(tempfile.gettempdir()) / "sipsara_e2e_dashboard.json"
    env = {**os.environ, "PYTHONPATH": ""}
    subprocess.run([sys.executable, "scripts/e2e_ingest_simulated.py", str(out), str(learners)],
                   cwd=TELEMETRY, check=True, env=env, capture_output=True)
    return json.loads(out.read_text(encoding="utf-8"))


class EndToEndDashboardConsistency(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = _ingest()
        collections = cls.data["collections"]
        for row in collections["students"]:
            row["_id"] = ObjectId(row["_id"])
        cls.db = Database(**collections)

    def setUp(self):
        for module in (therapist, parent, dashboard_access):
            module.get_db = lambda: self.db

    def call(self, fn, *args):
        return asyncio.run(fn(*args))

    def test_every_screen_reports_the_simulated_truth(self):
        self.assertTrue(self.data["truth"])
        for student_id, truth in self.data["truth"].items():
            with self.subTest(student=student_id, pattern=truth["pattern"]):
                expected = truth["first_attempt_accuracy"]
                overview = self.call(therapist.get_therapist_overview, student_id)
                c1 = self.call(therapist.get_therapist_c1_behavioral, student_id, 30)
                parent_overview = self.call(parent.get_parent_overview, student_id)
                analytics = self.call(parent.get_parent_component_analytics, student_id)
                perf = self.call(parent.get_parent_activity_performance, student_id, 30, None, 100)

                self.assertAlmostEqual(overview.accuracy, expected, places=6)
                self.assertAlmostEqual(c1.first_attempt_accuracy, expected, places=6)
                self.assertAlmostEqual(analytics["c1_behavioral"]["first_attempt_accuracy"], expected, places=6)
                self.assertEqual(parent_overview.accuracy, round(expected * 100))
                self.assertEqual(overview.attempted_items, truth["completed_rounds"])
                self.assertEqual(parent_overview.completed_rounds, truth["completed_rounds"])
                self.assertEqual(c1.window["sessions_started"], truth["sessions"])
                self.assertEqual(sum(r["trials"] for r in perf["activities"]), truth["completed_rounds"])
                self.assertEqual(
                    round(sum((r["first_attempt_accuracy"] or 0) * r["trials"] for r in perf["activities"])),
                    truth["first_try_correct"])
                self.assertEqual(c1.median_response_latency_ms, parent_overview.median_response_latency_ms)

    def test_learner_level_estimate_reaches_the_therapist_tab(self):
        estimates = {row["student_id"]: row for row in self.data["collections"]["c1_learner_estimates"]}
        self.assertEqual(set(estimates), set(self.data["truth"]))
        for student_id, stored in estimates.items():
            view = self.call(therapist.get_therapist_c1_behavioral, student_id, 30).c1_state["pattern_estimate"]
            self.assertEqual(view["status"], stored["status"])
            self.assertEqual(view["predicted_pattern"], stored.get("predicted_pattern"))
            self.assertEqual(view["evidence"]["completed_rounds"], self.data["truth"][student_id]["completed_rounds"])


if __name__ == "__main__":
    unittest.main()
