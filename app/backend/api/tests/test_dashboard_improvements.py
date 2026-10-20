"""Regression tests for the dashboard data fixes (C1/C2/C3 views, alerts, feedback, parent PDF)."""
import asyncio
import unittest
from datetime import datetime, timedelta, timezone

from bson import ObjectId
from fastapi import FastAPI
from fastapi.testclient import TestClient

from tests.test_pp2_dashboard_contracts import Database, Collection, STUDENT, OWNER


async def _insert_one(self, doc):
    self.rows.append(dict(doc))


Collection.insert_one = _insert_one
from routers import therapist_dashboard as therapist, parent_dashboard as parent
from services import dashboard_access
from services.dashboard_data import activity_label, fatigue_view, learner_alerts
from dependencies import get_current_user

NOW = datetime.now(timezone.utc)


def summary(n, **extra):
    row = dict(_id=f"{n:03}", student_id=STUDENT, session_id=f"s{n}", total_trials=10,
               completed_at=NOW - timedelta(days=n),
               overall={"accuracy": 0.5 + n / 100, "median_response_latency_ms": 2000, "retry_rate": 0.4,
                        "error_rate": 0.5},
               error_profile={"visual_task_error_rate": 1.0, "visual_confusion_rate": 0.0, "error_count": 5},
               knowledge_components={"KC_VISUAL_CATEGORIZATION": {"trials": 10, "accuracy": 0.5}},
               behavioral_fatigue_proxy=-0.34, fatigue_components={})
    row.update(extra)
    return row


class DashboardImprovementTests(unittest.TestCase):
    def setUp(self):
        self.db = Database(students=[{"_id": ObjectId(STUDENT), "parent_id": OWNER, "first_name": "Sahan"}])
        therapist.get_db = parent.get_db = dashboard_access.get_db = lambda: self.db

    def call(self, fn, *args):
        return asyncio.run(fn(*args))

    def test_c1_uses_window_real_kcs_reported_errors_and_bounded_fatigue(self):
        self.db.session_summaries.rows = [summary(1), summary(2)]
        dto = self.call(therapist.get_therapist_c1_behavioral, STUDENT, 30)
        self.assertEqual(dto.session_count, 2)
        self.assertEqual(dto.total_trials, 20)
        self.assertEqual(dto.kc_breakdown[0]["kc_id"], "KC_VISUAL_CATEGORIZATION")
        self.assertEqual(dto.kc_breakdown[0]["trials"], 20)
        shares = {c["key"]: c["share"] for c in dto.error_breakdown["categories"]}
        self.assertEqual(shares["visual_task_error"], 1.0)
        self.assertEqual(shares["visual_confusion"], 0.0)
        self.assertEqual(dto.behavioral_fatigue_proxy, 0.0)  # legacy -0.34 clipped
        self.assertEqual(dto.fatigue_state, "LOW")

    def test_c1_state_and_kinematics_are_exposed(self):
        self.db.session_summaries.rows = [summary(1)]
        self.db.behavioral_features.rows = [{
            "_id": "b1", "student_id": STUDENT, "session_id": "s1", "timestamp": NOW.isoformat(),
            "indices": {"visual_processing_index": 61.0, "attention_stability_index": 80.0},
            "fatigue": {"score": 0.1, "state": "LOW"},
            "interaction_state": {"score": 0.3, "state": "ENGAGED"},
            "model": {"model_used": "trained_random_forest_model", "predicted_pattern": "TYPICAL",
                      "probabilities": {"TYPICAL": 0.7}, "confidence": 0.7, "model_version": "2.0.0"},
        }]
        self.db.kinematic_features.rows = [{"_id": "k1", "student_id": STUDENT, "timestamp": NOW.isoformat(),
                                            "path_efficiency_ratio": 0.8, "orthographic_confusion_coverage": 0}]
        dto = self.call(therapist.get_therapist_c1_behavioral, STUDENT, 30)
        self.assertTrue(dto.c1_state["pattern_estimate"]["available"])
        self.assertEqual(dto.c1_state["indices"]["visual_processing_index"], 61.0)
        self.assertEqual(dto.kinematics["path_efficiency_ratio"], 0.8)
        self.assertIsNone(dto.kinematics["orthographic_confusion_index"])

    def test_activity_template_ids_resolve_to_names(self):
        label = activity_label("skill_1", "visual_sorting_adventure")
        self.assertEqual(label["activity_key"], "1.3")
        self.assertEqual(label["activity_name_en"], "Picture sorting")
        self.assertEqual(activity_label("skill_5", "act_2")["activity_name_en"], "Who?")

    def test_alerts_for_inactivity_and_low_usable_recordings(self):
        coverage = {"last_active_at": (NOW - timedelta(days=9)).isoformat(), "recordings": 4,
                    "usable_recordings": 1, "usable_recording_rate": 0.25,
                    "questionnaire_sections_done": 4, "questionnaire_sections_total": 4,
                    "_window_summaries": [summary(1, behavioral_fatigue_proxy=0.9), summary(2, behavioral_fatigue_proxy=0.9)]}
        codes = {a["code"] for a in learner_alerts(coverage)}
        self.assertEqual(codes, {"inactive", "low_usable_recordings", "repeated_high_fatigue"})

    def test_feedback_is_professional_only_and_stores_snapshot(self):
        self.db.therapist_connections.rows = [{"therapist_id": "t1", "student_id": STUDENT, "status": "active"}]
        self.db.learner_profiles.rows = [{"_id": "p1", "student_id": STUDENT, "feature_version": "c3-learner-window-v1",
                                          "learner_profile": {"primary_pattern": "Typical Learning Pattern"},
                                          "model_inputs": {"age": 6.0}, "model_version": "C3-v1.2"}]
        app = FastAPI(); app.include_router(therapist.router)
        url = f"/api/v1/therapist/students/{STUDENT}/feedback"
        body = {"component": "c3", "agreement": "disagree", "professional_pattern": "NOT_SURE", "note": "Needs more reading data"}
        with TestClient(app) as client:
            app.dependency_overrides[get_current_user] = lambda: {"_id": OWNER, "role": "parent"}
            self.assertEqual(client.post(url, json=body).status_code, 403)
            app.dependency_overrides[get_current_user] = lambda: {"_id": "t1", "role": "specialist", "name": "Dr T"}
            self.assertEqual(client.post(url, json=body).status_code, 201)
        stored = self.db.professional_feedback.rows[-1]
        self.assertEqual(stored["agreement"], "disagree")
        self.assertEqual(stored["model_estimate"], "Typical Learning Pattern")
        self.assertEqual(stored["feature_snapshot"], {"age": 6.0})
        self.assertFalse(stored["calibration_eligible"])

    def test_parent_pdf_is_generated_without_model_outputs(self):
        self.db.session_summaries.rows = [summary(1, activity_breakdown_by_skill={
            "skill_1::act_3": {"skill_id": "skill_1", "activity_id": "act_3", "trials": 9, "accuracy": 0.56, "retry_rate": 0.44}})]
        response = self.call(parent.download_parent_report, STUDENT, 30)
        self.assertEqual(response.media_type, "application/pdf")
        self.assertTrue(response.body.startswith(b"%PDF"))


if __name__ == "__main__":
    unittest.main()
