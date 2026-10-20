"""Learner-level C1 estimate: evidence rule -> out-of-range guard -> model.

The estimate is a model output for professional review, trained on simulated
learners only. It is returned only when:
  1. the learner has enough evidence (config ``c1_learner_window``), and
  2. every measured input lies inside the range seen in training.
Otherwise the result says why, and no pattern or probability is given.
"""
from __future__ import annotations

import json
import math
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from services.c1.learner_window import (FEATURE_VERSION, RULES, build_learner_features,
                                        evidence_gaps, evidence_notes)
from .registry import registry

MODEL_NAME = "c1_learner_model"
RANGE_MARGIN = 0.10  # share of the training p1-p99 width allowed outside it
_MODELS_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "models")
_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "config", "c1_features.json")


def _feature_names() -> list[str]:
    with open(_SCHEMA_PATH, "r", encoding="utf-8") as f:
        return json.load(f)["features"]


def _ranges() -> dict:
    name = registry.get_config(MODEL_NAME).get("ranges", "c1_learner_feature_ranges.json")
    path = os.path.join(_MODELS_DIR, name)
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f).get("ranges", {})


def outside_training_range(values: dict, ranges: Optional[dict] = None) -> list[dict]:
    ranges = ranges if ranges is not None else _ranges()
    outside = []
    for name, value in values.items():
        bounds = ranges.get(name)
        if value is None or not bounds:
            continue
        width = bounds["p99"] - bounds["p01"]
        low, high = bounds["p01"] - RANGE_MARGIN * width, bounds["p99"] + RANGE_MARGIN * width
        if value < low or value > high:
            outside.append({"feature": name, "value": round(float(value), 4),
                            "training_range": [round(bounds["p01"], 4), round(bounds["p99"], 4)]})
    return outside


def estimate_from_sessions(sessions: list[tuple[dict, list[dict]]]) -> dict:
    built = build_learner_features(sessions)
    values, evidence = built["features"], built["evidence"]
    config = registry.get_config(MODEL_NAME)
    result = {
        "model_name": MODEL_NAME,
        "model_version": config.get("version", "unknown"),
        "feature_schema_version": FEATURE_VERSION,
        "provenance": config.get("provenance", "synthetic_only"),
        "evidence": evidence,
        "evidence_rule": RULES,
        "features": values,
        "notes": evidence_notes(evidence, values),
        "predicted_pattern": None,
        "probabilities": {},
        "confidence": None,
        "missing_evidence": [],
        "outside_range": [],
    }
    gaps = evidence_gaps(evidence)
    if gaps:
        return {**result, "status": "insufficient_evidence", "missing_evidence": gaps}
    model = registry.load_model(MODEL_NAME)
    names = _feature_names()
    if model is None or list(getattr(model, "sipsara_feature_names", names)) != names \
            or getattr(model, "sipsara_feature_schema", FEATURE_VERSION) != FEATURE_VERSION:
        return {**result, "status": "model_unavailable"}
    outside = outside_training_range(values)
    if outside:
        return {**result, "status": "outside_training_range", "outside_range": outside}
    import numpy as np
    row = np.asarray([[math.nan if values.get(n) is None else float(values[n]) for n in names]])
    probs = model.predict_proba(row)[0]
    classes = config.get("class_names") or []
    labels = [classes[int(c)] if classes else str(c) for c in model.classes_]
    probabilities = {label: round(float(p), 3) for label, p in zip(labels, probs)}
    best = max(probabilities, key=probabilities.get)
    return {**result, "status": "estimated", "predicted_pattern": best,
            "probabilities": probabilities, "confidence": probabilities[best]}


def _when(doc: dict) -> Optional[datetime]:
    for key in ("completed_at", "started_at", "submitted_at"):
        value = doc.get(key)
        if isinstance(value, datetime):
            return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
        if isinstance(value, str) and value:
            try:
                parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
                return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
            except ValueError:
                continue
    return None


async def compute_and_store(db, student_id: str, now: Optional[datetime] = None) -> dict:
    """Recompute the learner's estimate from stored sessions and save it."""
    now = now or datetime.now(timezone.utc)
    since = now - timedelta(days=RULES["window_days"])
    projection = {"events.touch_path": 0, "events.touch_stream": 0, "events.attempt_history": 0,
                  "events.scaffold_applications": 0, "device_metrics": 0}
    docs = await db.telemetry_sessions.find({"student_id": student_id}, projection) \
        .sort("_id", -1).limit(300).to_list(length=300)
    dated = [(d, _when(d)) for d in docs]
    window = sorted([(d, t) for d, t in dated if t is None or t >= since], key=lambda x: x[1] or now)
    sessions = [({"session_id": d.get("session_id")}, d.get("events") or []) for d, _ in window]
    estimate = estimate_from_sessions(sessions)
    doc = {
        "student_id": student_id,
        "computed_at": now.isoformat(),
        "window_days": RULES["window_days"],
        "window_start": since.isoformat(),
        "session_ids": [d.get("session_id") for d, _ in window],
        "data_origin": next((d.get("data_origin") for d, _ in window if d.get("data_origin")), "unspecified"),
        "validation_status": "model_estimate_synthetic_training",
        **estimate,
    }
    await db.c1_learner_estimates.update_one({"student_id": student_id}, {"$set": doc}, upsert=True)
    return doc
