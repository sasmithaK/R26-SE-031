import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from schemas.dashboards import (TherapistOverviewDTO, TherapistC1BehavioralDTO, TherapistC2SpeechDTO,
                                TherapistC3ProfileDTO, TherapistC4AdaptiveDTO, ShapExplanation)
from shared.database import get_db
from services.dashboard_access import require_dashboard_access
from services.dashboard_data import (ACTIVITY_NAMES, KC_NAMES, SKILL_NAMES,
                                     number, timestamp, records, mlbase, speech,
                                     pattern_profile, mastery_status,
                                     research_evidence, activity_performance,
                                     setting, in_window, session_point, weighted_overall,
                                     kc_breakdown, error_breakdown, fatigue_view,
                                     shap_phrase, learner_coverage, window_or_latest, learner_alerts,
                                     public_coverage, activity_label, stamp,
                                     USABLE_SPEECH_STATUSES)
from dependencies import get_current_user

router = APIRouter(prefix="/api/v1/therapist/students", tags=["Therapist Dashboard"],
                   dependencies=[Depends(require_dashboard_access)])


def _task_round(item_id):
    match = re.search(r"R(\d+)", str(item_id or ""), re.IGNORECASE)
    return int(match.group(1)) if match else None


def _item_answer_values(item):
    """Return reviewed answers in a compact form suitable for read-only replay."""
    content = item.get("content") or {}
    options = item.get("options") or []
    for key in (
        "correctOption", "correct_option", "correct_answer", "correct_word",
        "correct_sentence", "target_word", "target_letter",
    ):
        if content.get(key) is not None:
            return [str(content[key])]
    for key in ("targets", "target_assets"):
        value = content.get(key)
        if isinstance(value, list) and value:
            return [str(entry) for entry in value]
    if content.get("target_asset") is not None:
        return [str(content["target_asset"])]
    target_items = [
        str(entry.get("value"))
        for entry in (content.get("items") or [])
        if isinstance(entry, dict)
        and entry.get("is_target") is True
        and entry.get("value") is not None
    ]
    if target_items:
        return target_items
    if isinstance(content.get("letters"), list) and content["letters"]:
        return [str(value) for value in content["letters"]]
    content_options = content.get("options") or []
    indices = []
    if isinstance(content.get("correct_index"), int):
        indices.append(content["correct_index"])
    indices.extend(
        index for index in (content.get("correct_indices") or [])
        if isinstance(index, int)
    )
    indexed_answers = [
        str(content_options[index]) for index in indices
        if 0 <= index < len(content_options)
    ]
    if indexed_answers:
        return indexed_answers
    correct = [
        str(option.get("value"))
        for option in options
        if option.get("role") == "target" and option.get("value") is not None
    ]
    return correct


def _task_prompt(item):
    content = item.get("content") or {}
    direct = (
        content.get("instruction")
        or content.get("prompt")
        or content.get("audio_text")
    )
    if direct:
        return str(direct)
    template = str(item.get("template_type") or "")
    reviewed_runtime_prompts = {
        "visual_odd_one_out": "සෙවනැල්ලට ගැළපෙන පින්තූරය තෝරන්න!",
        "visual_sorting_adventure": "පින්තූර නිවැරදි කූඩයට දමන්න!",
        "visual_pattern_adventure": "රටාවට ගැළපෙන පින්තූරය තෝරන්න",
        "visual_memory_hats": "මේ පින්තූරය තිබූ තැන තෝරන්න",
        "skill2_identical_match": "එක සමාන අකුරු යුගල තෝරන්න.",
        "skill2_pattern_memory": "රටාව මතක තබාගෙන නැවත සකසන්න",
    }
    return reviewed_runtime_prompts.get(template,"Task prompt unavailable")


def _task_preview(row, item):
    content = dict(item.get("content") or {})
    raw_options = item.get("options") or []
    option_by_id = {
        str(option.get("option_id")): str(option.get("value"))
        for option in raw_options
        if option.get("option_id") is not None and option.get("value") is not None
    }

    template = str(item.get("template_type") or "")

    def resolve_value(value):
        raw = str(value)
        if raw in option_by_id:
            return option_by_id[raw]
        # Older memory-task events persisted only the shuffled card position.
        # The exact image at that position cannot be recovered safely because
        # the child UI shuffles cards. Never pretend that the static bank order
        # is the order that the learner saw.
        position = re.search(r"_O(\d+)$", raw, re.IGNORECASE)
        if position and template == "visual_memory_hats":
            return f"Card {position.group(1)} (historical position)"
        token = re.search(r"_T(\d+)$", raw, re.IGNORECASE)
        if token:
            return f"Token {token.group(1)}"
        return raw

    def resolved(values):
        return [resolve_value(value) for value in (values or [])]

    selected = resolved(row.get("selected_answers") or [])
    targets = resolved(row.get("target_ids") or [])
    correct = _item_answer_values(item)
    option_rows = []
    for option in raw_options:
        value = str(option.get("value") or "")
        option_rows.append({
            "id": str(option.get("option_id") or value),
            "value": value,
            "is_correct": value in correct or option.get("role") == "target",
            "was_selected": value in selected,
            "role": option.get("role"),
        })

    # Several activity families render from structured content rather than a
    # conventional item-bank option array. Provide the therapist UI with an
    # explicit visual pool for those templates too.
    if not option_rows:
        structured_values = []
        if template == "visual_memory_hats":
            structured_values = content.get("assets") or []
        elif template == "visual_odd_one_out":
            structured_values = content.get("target_assets") or []
        elif template == "skill2_identical_match":
            structured_values = content.get("letters") or []
        elif isinstance(content.get("items"), list):
            structured_values = [
                entry.get("value") if isinstance(entry, dict) else entry
                for entry in content["items"]
            ]
        elif isinstance(content.get("options"), list):
            structured_values = content["options"]
        for index, value in enumerate(structured_values):
            if value is None:
                continue
            value = str(value)
            option_rows.append({
                "id": f"structured-{index + 1}",
                "value": value,
                "is_correct": value in correct,
                "was_selected": value in selected,
                "role": "target" if value in correct else "option",
            })

    category_pairs = []
    for category, values in (content.get("categories") or {}).items():
        label = (content.get("category_labels") or {}).get(category, category)
        for value in values if isinstance(values, list) else []:
            category_pairs.append({
                "value": str(value),
                "destination": str(label),
                "category": str(category),
            })

    prompt = _task_prompt(item)
    image = content.get("image_url") or content.get("image")

    raw_attempt_history = row.get("attempt_history") or []
    response_attempts = []
    for index, attempt in enumerate(raw_attempt_history):
        if not isinstance(attempt, dict):
            continue
        response_attempts.append({
            "attempt_number": int(attempt.get("attempt_number") or index + 1),
            "is_correct": attempt.get("is_correct") is True,
            "selected_answers": resolved(attempt.get("selected_answers") or []),
            "support_applied_before_response": bool(
                attempt.get("support_applied_before_response")
            ),
            "support_actions_before_response": [
                str(value)
                for value in (attempt.get("support_actions_before_response") or [])
            ],
            "evidence_quality": "exact",
        })

    # Historical records pre-date attempt_history. Reconstruct only what the
    # persisted counts prove: the first N attempts were incorrect and the final
    # response was correct when final_correct is true. This is intentionally
    # labelled reconstructed evidence in the UI.
    if not response_attempts:
        attempt_count = int(row.get("attempt_count") or 0)
        incorrect_count = int(row.get("incorrect_attempt_count") or 0)
        if attempt_count <= 0:
            attempt_count = max(len(selected), 1 if row.get("is_correct") is not None else 0)
        for index in range(attempt_count):
            if len(selected) == attempt_count:
                answers = [selected[index]]
            elif attempt_count == 1:
                answers = list(selected)
            elif index < incorrect_count and index < len(selected):
                answers = [selected[index]]
            elif index == attempt_count - 1:
                answers = list(correct) if row.get("is_correct") is True else []
            else:
                answers = []
            is_correct = (
                index >= incorrect_count
                and row.get("is_correct") is True
                and index == attempt_count - 1
            )
            response_attempts.append({
                "attempt_number": index + 1,
                "is_correct": is_correct,
                "selected_answers": answers,
                "support_applied_before_response": bool(
                    int(row.get("scaffold_level_used", row.get("scaffold_level", 0)) or 0) > 0
                    and index >= incorrect_count
                ),
                "support_actions_before_response": [],
                "evidence_quality": "reconstructed",
            })

    return {
        "available": bool(item),
        "template_type": item.get("template_type"),
        "prompt": str(prompt),
        "image": str(image) if image else None,
        "options": option_rows,
        "selected_response": selected,
        "correct_response": correct,
        "target_response": targets,
        "response_attempts": response_attempts,
        "category_pairs": category_pairs,
        "content": {
            key: content.get(key)
            for key in (
                "audio_text", "target_word", "target_letter", "pattern",
                "sequence", "missing_index", "correct_answer", "correct_word",
                "correct_sentence", "scrambled_letters", "scrambled_words",
                "category_labels", "category_icons", "categories", "assets",
                "target_asset", "target_assets", "letters", "items", "options",
                "show_seconds", "show_milliseconds", "difficulty",
            )
            if content.get(key) is not None
        },
    }


@router.get("/{student_id}/activity-performance")
async def get_therapist_activity_performance(
    student_id: str,
    days: int = Query(30, ge=1, le=365),
    skill_id: Optional[str] = Query(None, min_length=1, max_length=32),
    limit: int = Query(100, ge=1, le=300),
):
    """Detailed, per-skill activity summary aligned across touch and speech records."""
    return await activity_performance(get_db(), student_id, days, skill_id, limit)

def _window_days(days):
    # Direct (non-HTTP) calls pass FastAPI's Query default object.
    return days if isinstance(days, int) else setting("default_window_days", default=30)


async def _latest_profile(db, student_id):
    """Prefer the learner-window C3 profile over legacy per-session rows."""
    rows = await records(db, "learner_profiles", student_id, 20)
    window = [row for row in rows if row.get("feature_version") == "c3-learner-window-v1"]
    return (window or rows or [{}])[0]


@router.get("/{student_id}/overview", response_model=TherapistOverviewDTO)
async def get_therapist_overview(student_id: str):
    db = get_db()
    summaries = await records(db, "session_summaries", student_id)
    speeches = await records(db, "speech_features", student_id, 1)
    profile_doc = await _latest_profile(db, student_id)
    states = await records(db, "knowledge_states", student_id, 1)
    decisions = await records(db, "adaptive_decisions", student_id, 1)
    latest = summaries[0] if summaries else {}
    values = [number(v) for v in (states[0].get("knowledge_state", {}) if states else {}).values()]
    values = [v for v in values if v is not None]
    mastery = sum(values)/len(values) if values else None
    profile, _, pattern = pattern_profile(profile_doc)
    fatigue = fatigue_view(latest) if latest else {"score": None, "state": "UNAVAILABLE"}
    from bson import ObjectId
    student_doc = None
    try:
        student_doc = await db.students.find_one({"_id": ObjectId(student_id)})
    except Exception:
        pass
    session_ids = await db.session_summaries.distinct("session_id", {"student_id": student_id})
    assessment_results = student_doc.get("assessment_results", []) if student_doc else []
    comprehensive_assessment_results = student_doc.get("comprehensive_assessment_results", {}) if student_doc else {}
    reviewed_assessments = student_doc.get("reviewed_assessments", {}) if student_doc else {}

    first_name = student_doc.get("first_name") if student_doc else None
    last_name = student_doc.get("last_name") if student_doc else None
    student_name = f"{first_name or ''} {last_name or ''}".strip() if (first_name or last_name) else None
    grade = student_doc.get("grade", "Grade 1") if student_doc else "Grade 1"
    age = student_doc.get("age") if student_doc else None
    avatar_url = student_doc.get("avatar_url") if student_doc else None

    parent_name = None
    if student_doc and "parent_id" in student_doc:
        try:
            parent_doc = await db.users.find_one({"_id": ObjectId(student_doc["parent_id"])})
            if parent_doc:
                parent_name = parent_doc.get("name")
        except Exception:
            pass

    coverage = await learner_coverage(db, student_id, student_doc or {})
    alerts = learner_alerts(coverage)
    fatigue_text = ("Unavailable" if fatigue["score"] is None
                    else f"{fatigue['state'].replace('_', ' ').title()} ({fatigue['score']:.2f})")

    return TherapistOverviewDTO(**mlbase(student_id, latest, "descriptive + BKT/IRT", "c1-v2"),
        accuracy=number((latest.get("overall") or {}).get("accuracy")), attempted_items=latest.get("total_trials", 0),
        completed_sessions=len([x for x in session_ids if x]), reading_fluency_status=mastery_status(mastery),
        overall_mastery=mastery, current_pattern=pattern, pattern_confidence=number(profile.get("confidence")),
        fatigue_status=fatigue_text, fatigue_state=fatigue["state"],
        last_active=coverage.get("last_active_at") or timestamp(latest), c1_available=bool(summaries), c2_available=bool(speeches),
        c3_available=bool(profile_doc.get("model_applied")), c4_available=bool(states),
        latest_recommendation=decisions[0].get("decision_reason") if decisions else None,
        assessment_results=assessment_results,
        comprehensive_assessment_results=comprehensive_assessment_results,
        reviewed_assessments=reviewed_assessments,
        first_name=first_name,
        last_name=last_name,
        student_name=student_name,
        grade=grade,
        age=age,
        avatar_url=avatar_url,
        parent_name=parent_name,
        birth_year=(student_doc or {}).get("birth_year"),
        birth_month=(student_doc or {}).get("birth_month"),
        gender=(student_doc or {}).get("gender"),
        coverage=public_coverage(coverage),
        alerts=alerts)


def _c1_state_view(states):
    """Latest C1 learner state (indices, states, model estimate) + baseline."""
    if not states:
        return {}
    latest, first = states[0], states[-1]
    model = latest.get("model") or {}
    def indices(row):
        return {k: number(v) for k, v in (row.get("indices") or {}).items()}
    return {
        "session_id": latest.get("session_id"),
        "updated_at": timestamp(latest) or stamp(getattr(latest.get("_id"), "generation_time", None)),
        "indices": indices(latest),
        "baseline_indices": indices(first) if len(states) > 1 else {},
        "fatigue": latest.get("fatigue") or {},
        "interaction_state": latest.get("interaction_state") or {},
        "quality": latest.get("quality") or {},
        "pattern_estimate": {
            "available": model.get("model_used") == "trained_random_forest_model",
            "predicted_pattern": model.get("predicted_pattern"),
            "probabilities": model.get("probabilities") or {},
            "confidence": number(model.get("confidence")),
            "model_version": model.get("model_version"),
            "provenance": model.get("model_provenance") or "synthetic_only",
            "unavailable_reason": model.get("unavailable_reason"),
            "missing_features": model.get("missing_features") or [],
            "label": "Model estimate from synthetic training - for professional review, not a diagnosis.",
        },
        "sessions_with_state": len(states),
    }


def _kinematics_view(rows):
    """Median touch-movement features over the window (drag paths only)."""
    def median(key, *alts):
        values = []
        for row in rows:
            for name in (key, *alts):
                value = number(row.get(name))
                if value is not None:
                    values.append(value)
                    break
        if not values:
            return None
        values.sort()
        mid = len(values) // 2
        return values[mid] if len(values) % 2 else (values[mid - 1] + values[mid]) / 2
    coverage = [number(r.get("orthographic_confusion_coverage")) for r in rows]
    coverage = [c for c in coverage if c is not None]
    return {
        "sessions": len(rows),
        "time_to_first_touch_ms": median("time_to_first_touch_ms"),
        "dwell_time_ms": median("dwell_time_ms", "mean_dwell_time_ms"),
        "path_efficiency_ratio": median("path_efficiency_ratio"),
        "dimensionless_jerk": median("dimensionless_jerk"),
        "orthographic_confusion_index": median("orthographic_confusion_index") if any(c > 0 for c in coverage) else None,
        "orthographic_confusion_note": (
            None if any(c > 0 for c in coverage)
            else "Letter-confusion index not shown: the confusion map did not cover the letters this child got wrong."
        ),
    }


@router.get("/{student_id}/c1-behavioral", response_model=TherapistC1BehavioralDTO)
async def get_therapist_c1_behavioral(student_id: str, days: Optional[int] = Query(None, ge=1, le=365)):
    db = get_db()
    days = _window_days(days)
    all_rows = await records(db, "session_summaries", student_id)
    history, period = window_or_latest(all_rows, days)
    latest = history[0] if history else {}
    trend_rows = list(reversed(history[: setting("limits", "trend_sessions", default=12)]))
    def trend(field=None, fatigue=False):
        points = []
        for index, row in enumerate(trend_rows, start=1):
            value = fatigue_view(row)["score"] if fatigue else number((row.get("overall") or {}).get(field))
            points.append(session_point(row, index, value))
        return points
    errors = error_breakdown(history)
    shares = {c["key"]: c["share"] for c in errors["categories"]}
    kcs = kc_breakdown(history)
    states = in_window(await records(db, "behavioral_features", student_id, 100), days)
    states = states or (await records(db, "behavioral_features", student_id, 1))
    index_trend = []
    for index, row in enumerate(reversed(states[: setting("limits", "trend_sessions", default=12)]), start=1):
        point = session_point(row, index, None)
        point.update({k: number(v) for k, v in (row.get("indices") or {}).items()})
        index_trend.append(point)
    motion = in_window(await records(db, "kinematic_features", student_id, 100), days)
    fatigue = fatigue_view(latest) if latest else {"score": None, "state": "UNAVAILABLE"}
    return TherapistC1BehavioralDTO(**{**mlbase(student_id, latest, "descriptive", "c1-v2"),
                                       "reporting_period": period},
        session_id=latest.get("session_id"),
        first_attempt_accuracy=weighted_overall(history, "accuracy"),
        median_response_latency_ms=weighted_overall(history, "median_response_latency_ms"),
        retry_rate=weighted_overall(history, "retry_rate"),
        mean_attempts_per_round=weighted_overall(history, "mean_attempts_per_round"),
        median_time_to_correct_ms=weighted_overall(history, "median_time_to_correct_ms"),
        correction_rate=weighted_overall(history, "correction_rate"),
        behavioral_fatigue_proxy=fatigue["score"], fatigue_state=fatigue["state"],
        kc_performance={row["kc_id"]: row["accuracy"] for row in kcs if row["kc_id"] in KC_NAMES},
        error_distribution={k: (shares.get(k) if errors["total_errors"] else None)
                            for k in ("visual_confusion", "visual_task_error", "phonological_confusion", "sequence_error", "unknown_error")},
        trends=dict(accuracy=trend("accuracy"), latency=trend("median_response_latency_ms"), fatigue=trend(fatigue=True)),
        window_days=days, session_count=len(history),
        total_trials=sum(int(r.get("total_trials") or 0) for r in history),
        kc_breakdown=kcs, error_breakdown=errors,
        c1_state=_c1_state_view(states), kinematics=_kinematics_view(motion),
        index_trend=index_trend)


def _speech_item(row):
    values = speech(row)
    labels = activity_label(row.get("skill_id"), row.get("activity_id"), row.get("activity_name"))
    alignment = row.get("alignment") or {}
    operations = (alignment.get("word") or {}).get("operations") or []
    return {
        "item_id": row.get("item_id"),
        "activity": labels["activity_display"],
        "recorded_at": timestamp(row),
        "expected_text": values["expected_text"],
        "recognized_text": values["transcription"],
        "grapheme_accuracy": values["grapheme_accuracy"],
        "word_accuracy": values["word_accuracy"],
        "reading_score": values["reading_performance_score"],
        "confidence": values["combined_confidence"],
        "status": values["measurement_status"],
        "quality_issues": values["quality_issues"],
        "word_operations": [
            {"op": op.get("operation"), "expected": op.get("expected"), "observed": op.get("observed")}
            for op in operations[:40] if isinstance(op, dict)
        ],
    }


@router.get("/{student_id}/c2-speech", response_model=TherapistC2SpeechDTO)
async def get_therapist_c2_speech(student_id: str, days: Optional[int] = Query(None, ge=1, le=365)):
    days = _window_days(days)
    all_rows = await records(get_db(), "speech_features", student_id)
    history, period = window_or_latest(all_rows, days, fallback=20)
    latest = history[0] if history else {}
    usable_rows = [row for row in history if row.get("measurement_status") in USABLE_SPEECH_STATUSES]
    issues = {}
    for row in history:
        for issue in speech(row)["quality_issues"]:
            issues[issue] = issues.get(issue, 0) + 1
    recent = history[:10]
    def trend(key):
        return [{"session": row.get("session_id"), "value": speech(row)[key], "date": timestamp(row)} for row in reversed(recent)]
    # Per-session medians make different sentences comparable over time.
    sessions = {}
    for row in usable_rows:
        sessions.setdefault(row.get("session_id") or timestamp(row), []).append(row)
    def med(values):
        values = sorted(v for v in values if v is not None)
        if not values:
            return None
        mid = len(values) // 2
        return values[mid] if len(values) % 2 else (values[mid - 1] + values[mid]) / 2
    session_trend = []
    ordered = sorted(sessions.items(), key=lambda kv: min(timestamp(r) or "" for r in kv[1]))
    for index, (sid, rows) in enumerate(ordered, start=1):
        point = session_point(rows[-1], index, None)
        point.update({
            "items": len(rows),
            "grapheme_accuracy": med([speech(r)["grapheme_accuracy"] for r in rows]),
            "word_accuracy": med([speech(r)["word_accuracy"] for r in rows]),
            "reading_score": med([speech(r)["reading_performance_score"] for r in rows]),
            "voice_onset_ms": med([speech(r)["voice_onset_ms"] for r in rows]),
            "pause_ratio": med([speech(r)["pause_ratio"] for r in rows]),
        })
        session_trend.append(point)
    latest_view = speech(latest)
    latest_view.update({"item_id": latest.get("item_id"), "recorded_at": timestamp(latest)})
    return TherapistC2SpeechDTO(**{**mlbase(student_id, latest, "speech analysis", "c2-pipeline-v3"),
                                   "reporting_period": period.replace("sessions", "recordings")},
        recording_count=len(history), usable_recording_count=len(usable_rows), latest=latest_view,
        trends=dict(accuracy=trend("word_accuracy"), wer=trend("wer"), latency=trend("voice_onset_ms"),
                    silence_ratio=trend("silence_ratio"), peak_delta=trend("peak_delta")),
        window_days=days,
        usable_recording_rate=(len(usable_rows) / len(history)) if history else None,
        quality_issue_counts=issues,
        items=[_speech_item(row) for row in history[: setting("limits", "speech_items", default=20)]],
        session_trend=session_trend[-setting("limits", "trend_sessions", default=12):])


@router.get("/{student_id}/c3-profile", response_model=TherapistC3ProfileDTO)
async def get_therapist_c3_profile(student_id: str):
    db = get_db()
    doc = await _latest_profile(db, student_id)
    rows = [doc] if doc else []
    audit_rows = await records(db, "model_audit_log", student_id, 20)
    audit = next((row for row in audit_rows if row.get("model_name") == "XGBoost"), {})
    profile, probs, pattern = pattern_profile(doc)
    evidence = doc.get("evidence_summary") or {}
    window = doc.get("evidence_window") or {}
    summary_text = doc.get("llm_summary") or "More activity and reading observations are needed before a combined summary is available."
    recommendation_text = doc.get("llm_recommendations") or "Review repeated attempts and reading samples across several activities over time."
    pipeline_status = doc.get("pipeline_status") or audit.get("status") or "not_run"
    missing_inputs = list(doc.get("missing_inputs") or audit.get("missing_features") or [])
    skip_reason = None
    if not doc.get("model_applied"):
        skip_reason = ("The combined estimate is not ready yet. Still needed: " + "; ".join(missing_inputs) + ".") if missing_inputs \
            else "The combined estimate is not ready yet: more activity and reading observations are needed."
    metadata = mlbase(student_id, doc or audit, "XGBoost", "c3-fusion-v1")
    metadata["available"] = bool(doc)
    metadata["validation_status"] = "synthetic_trained_model"

    shap_list = []
    raw_shap = doc.get("shap_explanations") or {}
    top_features = raw_shap.get("top_contributing_features", []) if isinstance(raw_shap, dict) else (raw_shap if isinstance(raw_shap, list) else [])
    for item in top_features:
        if isinstance(item, dict):
            feat = item.get("feature") or item.get("feature_name") or "Unknown"
            val = number(item.get("value") if item.get("value") is not None else item.get("observed_value"))
            raw_contrib = item.get("contribution") or item.get("shap_val") or item.get("shap_impact")
            try:
                contrib = float(str(raw_contrib).replace("+", ""))
            except Exception:
                contrib = 0.0
            shap_list.append(ShapExplanation(
                feature=feat, contribution=contrib, observed_value=val,
                direction=item.get("direction") or ("positive" if contrib > 0 else "negative"),
                plain_text=shap_phrase(feat, contrib, val),
            ))

    classifier_available = bool(probs) and pattern != "Unavailable" and bool(doc.get("model_applied", True))
    ranked = sorted(probs.values(), reverse=True)
    low_agreement = len(ranked) > 1 and (ranked[0] - ranked[1]) < setting("c3", "low_agreement_gap", default=0.15)

    from bson import ObjectId
    student = {}
    try:
        student = await db.students.find_one({"_id": ObjectId(student_id)}) or {}
    except Exception:
        pass
    questionnaire = student.get("comprehensive_assessment_results") or {}
    sections_done = len([v for v in questionnaire.values() if isinstance(v, list) and v])
    sections_total = setting("alerts", "questionnaire_sections_total", default=4)
    checklist = [
        {"key": "activities", "label": "Touch activities (Skills 1-4)",
         "done": (window.get("movement_sessions") or 0) >= (window.get("min_movement_sessions") or 1),
         "detail": f"{window.get('movement_sessions', 0)} sessions with finger-movement data in {window.get('days', '-')} days"},
        {"key": "reading", "label": "Reading recordings (Skills 5-6)",
         "done": (window.get("usable_recordings") or 0) >= (window.get("min_usable_recordings") or 1),
         "detail": f"{window.get('usable_recordings', 0)} clear recordings of {window.get('recordings', 0)}"},
        {"key": "age", "label": "Child's age recorded", "done": "age" not in missing_inputs and bool(doc),
         "detail": "Add the birth month and year in the child profile" if "age" in missing_inputs else "Recorded"},
        {"key": "questionnaire", "label": "Parent questionnaire", "done": sections_done >= sections_total,
         "detail": f"{sections_done} of {sections_total} sections (shown in the summary, not a model input)"},
    ]
    sources = [s for s, ok in (("touch activities", bool(evidence.get("c1", {}).get("first_attempt_accuracy") is not None)),
                               ("reading recordings", evidence.get("c2", {}).get("word_accuracy") is not None),
                               ("parent questionnaire", bool(evidence.get("parent_observation_count")))) if ok]
    feedback = await records(db, "professional_feedback", student_id, 20)
    latest_feedback = next((f for f in feedback if f.get("component") == "c3"), None)
    if latest_feedback:
        latest_feedback = {k: (stamp(v) if k in {"created_at"} else v) for k, v in latest_feedback.items()
                           if k in {"agreement", "professional_pattern", "note", "created_at", "reviewer_name"}}

    return TherapistC3ProfileDTO(
        **metadata,
        classifier_available=classifier_available,
        primary_pattern=pattern if classifier_available else ("Not enough evidence yet" if doc else "Unavailable"),
        probabilities=probs if classifier_available else {},
        confidence=number(profile.get("confidence")) if classifier_available else None,
        modalities_used=profile.get("modalities_used") or [],
        shap_explanations=shap_list if classifier_available else [],
        llm_summary=doc.get("llm_summary"),
        llm_recommendations=doc.get("llm_recommendations"),
        pipeline_status=pipeline_status,
        missing_inputs=missing_inputs,
        skip_reason=skip_reason,
        summary_text=summary_text,
        recommendation_text=recommendation_text,
        evidence_window=window,
        coverage_checklist=checklist,
        measurement_notes=list(doc.get("measurement_notes") or []),
        low_agreement=low_agreement,
        sources_used=sources,
        latest_feedback=latest_feedback,
        marginalized_covariates=list(profile.get("marginalized_covariates") or []),
    )


# --- Professional feedback (expert labels for future model training) --------
from pydantic import BaseModel as _BaseModel, Field as _Field
from typing import Literal as _Literal

PATTERN_CHOICES = ("TYPICAL", "VISUAL_ORTHOGRAPHIC_PATTERN", "PHONOLOGICAL_PATTERN",
                   "COMBINED_PATTERN", "NOT_SURE")


class ProfessionalFeedbackRequest(_BaseModel):
    component: _Literal["c1", "c3"]
    agreement: _Literal["agree", "disagree", "unsure"]
    professional_pattern: Optional[_Literal[PATTERN_CHOICES]] = None
    note: Optional[str] = _Field(None, max_length=1000)
    session_id: Optional[str] = None


@router.post("/{student_id}/feedback", status_code=201)
async def submit_professional_feedback(student_id: str, req: ProfessionalFeedbackRequest,
                                       current_user: dict = Depends(get_current_user)):
    """Store a therapist's judgement on a model estimate, with a feature snapshot.

    These rows are the expert-labelled dataset that can later replace the
    synthetic training data (see telemetry ``/ml/train``).
    """
    if current_user.get("role") not in {"specialist", "therapist"}:
        raise HTTPException(403, "Only connected professionals can review model estimates.")
    db = get_db()
    from datetime import datetime, timezone
    snapshot, estimate, model_version = {}, None, None
    if req.component == "c1":
        states = await records(db, "behavioral_features", student_id, 20)
        state = next((s for s in states if s.get("session_id") == req.session_id), states[0] if states else {})
        model = state.get("model") or {}
        estimate, model_version = model.get("predicted_pattern"), model.get("model_version")
        snapshot = {**(state.get("behavior") or {}), **(state.get("indices") or {}),
                    "fatigue_score": (state.get("fatigue") or {}).get("score"),
                    "cognitive_load_score": (state.get("interaction_state") or {}).get("score")}
        session_id = state.get("session_id")
    else:
        doc = await _latest_profile(db, student_id)
        estimate = (doc.get("learner_profile") or {}).get("primary_pattern")
        model_version = doc.get("model_version")
        snapshot = doc.get("model_inputs") or {}
        session_id = doc.get("session_id")
    row = {
        "student_id": student_id, "component": req.component, "session_id": req.session_id or session_id,
        "agreement": req.agreement, "professional_pattern": req.professional_pattern,
        "note": (req.note or "").strip() or None, "model_estimate": estimate, "model_version": model_version,
        "feature_snapshot": {k: v for k, v in snapshot.items() if number(v) is not None},
        "reviewer_id": str(current_user["_id"]), "reviewer_name": current_user.get("name"),
        "data_origin": "observed", "calibration_eligible": False,
        "created_at": datetime.now(timezone.utc),
    }
    await db.professional_feedback.insert_one(row)
    return {"message": "Feedback saved.", "component": req.component, "agreement": req.agreement}


@router.get("/{student_id}/feedback")
async def list_professional_feedback(student_id: str):
    rows = await records(get_db(), "professional_feedback", student_id, 50)
    return {"student_id": student_id, "feedback": [
        {k: (stamp(v) if k == "created_at" else v) for k, v in row.items()
         if k in {"component", "agreement", "professional_pattern", "note", "model_estimate",
                  "model_version", "reviewer_name", "created_at", "session_id"}}
        for row in rows]}


@router.get("/{student_id}/c4-adaptive", response_model=TherapistC4AdaptiveDTO)
async def get_therapist_c4_adaptive(student_id: str, window: int = 20):
    db=get_db()
    window=max(5,min(int(window),100))
    states=await records(db,"knowledge_states",student_id,1)
    state=states[0] if states else {}
    raw_history=[
        row for row in await records(db,"adaptive_decisions",student_id,500)
        if row.get("research_eligible") is not False
    ]
    telemetry_history=await records(db,"telemetry_events",student_id,1000)
    policy_history=await records(db,"policy_decisions",student_id,1000)

    telemetry_by_event={
        str(row.get("event_id")):row
        for row in telemetry_history
        if row.get("event_id")
    }
    telemetry_by_task={}
    for row in telemetry_history:
        key=(str(row.get("session_id") or ""),str(row.get("item_id") or ""))
        if all(key) and key not in telemetry_by_task:
            telemetry_by_task[key]=row

    # Older adaptive-decision documents did not duplicate every task metric.
    # The matching telemetry event is the authoritative source for attempts,
    # timing, exact selections, and rendered scaffold commands. Join only on
    # stable identifiers; never manufacture a value when no match exists.
    all_history=[]
    telemetry_fields=(
        "attempt_count","incorrect_attempt_count","first_touch_latency_ms",
        "total_round_latency_ms","attempt_history","selected_answers",
        "scaffold_applications","struggled_target_units",
    )
    for source in raw_history:
        row=dict(source)
        telemetry=None
        if row.get("event_id"):
            telemetry=telemetry_by_event.get(str(row["event_id"]))
        if telemetry is None:
            telemetry=telemetry_by_task.get((
                str(row.get("session_id") or ""),
                str(row.get("current_item") or ""),
            ))
        if telemetry:
            for field in telemetry_fields:
                current=row.get(field)
                observed=telemetry.get(field)
                missing=current is None or current==[]
                if field in {
                    "attempt_count","incorrect_attempt_count",
                    "first_touch_latency_ms","total_round_latency_ms",
                }:
                    missing=number(current) in {None,0}
                    observed_available=number(observed) is not None
                else:
                    observed_available=observed not in (None,[])
                if missing and observed_available:
                    row[field]=observed
        all_history.append(row)

    policy_actions_by_task={}
    policy_actions_by_event={}
    for policy in reversed(policy_history):
        key=(
            str(policy.get("session_id") or ""),
            str(policy.get("item_id") or policy.get("current_item") or ""),
        )
        action=(
            policy.get("applied_action")
            or policy.get("decision")
            or policy.get("model_recommendation")
        )
        if all(key) and action:
            actions=policy_actions_by_task.setdefault(key,[])
            if str(action) not in actions:
                actions.append(str(action))
        if policy.get("event_id") and action:
            actions=policy_actions_by_event.setdefault(str(policy["event_id"]),[])
            if str(action) not in actions:
                actions.append(str(action))
    history=all_history[:window]
    item_ids={
        str(row.get("current_item"))
        for row in all_history
        if row.get("current_item")
    }
    item_docs=(
        await db.item_bank.find({"item_id":{"$in":list(item_ids)}})
        .limit(len(item_ids) or 1)
        .to_list(length=len(item_ids) or 1)
        if item_ids else []
    )
    items_by_id={str(item.get("item_id")):item for item in item_docs}

    def row_kc(row):
        return str(
            row.get("kc_id")
            or row.get("knowledge_component_id")
            or ""
        ).strip()

    def evidence_role(row):
        explicit=str(row.get("mastery_evidence_role") or "").upper()
        role=str(row.get("item_role") or "").upper()
        phase=str(row.get("practice_phase") or "").upper()
        for value in (explicit,role,phase):
            if value.startswith("REMEDIATION"):
                return "REMEDIATION"
            if value.startswith("CONFIRMATION"):
                return "CONFIRMATION"
        return "CORE" if role in {"","CORE"} else "OTHER"

    def mastery_evidence_eligible(row):
        applied=row.get("mastery_update_applied")
        if applied is not None:
            return applied is True
        return evidence_role(row) in {"CORE","CONFIRMATION"}

    def independent(row):
        first=row.get("learning_observation_correct")
        if first is None:
            first=row.get("first_attempt_correct")
        if first is None:
            first=str(row.get("response_quality") or "").upper() in {
                "CLEAN_SUCCESS","INDEPENDENT_SUCCESS","MASTERED"
            }
        return bool(first is True and int(row.get("scaffold_level_used",row.get("scaffold_level",0)) or 0)==0)

    observed_kcs={row_kc(row) for row in history if row_kc(row)}
    mastery_values=[]
    for kc_id,raw_value in (state.get("knowledge_state") or {}).items():
        value=number(raw_value)
        if value is not None and 0 <= value <= 1:
            mastery_values.append((str(kc_id),value))
    observed_mastery=[pair for pair in mastery_values if pair[0] in observed_kcs]
    primary_candidates=observed_mastery or mastery_values
    primary_focus=(
        min(primary_candidates,key=lambda pair:pair[1])
        if primary_candidates else None
    )
    primary_id=primary_focus[0] if primary_focus else None
    primary_name=(
        KC_NAMES.get(primary_id,primary_id.removeprefix("KC_").replace("_"," ").title())
        if primary_id else "Unavailable"
    )

    core_rows=[row for row in history if str(row.get("item_role") or "CORE").upper()=="CORE"]
    confirmation_rows=[row for row in history if str(row.get("item_role") or "").upper()=="CONFIRMATION"]
    independent_core=sum(1 for row in core_rows if independent(row))
    supported_core=len(core_rows)-independent_core
    independent_confirmations=sum(1 for row in confirmation_rows if independent(row))

    focus_core_rows=[row for row in core_rows if row_kc(row)==primary_id]
    focus_confirmation_rows=[
        row for row in confirmation_rows if row_kc(row)==primary_id
    ]
    focus_independent_core=sum(1 for row in focus_core_rows if independent(row))
    focus_supported_core=len(focus_core_rows)-focus_independent_core
    focus_independent_confirmations=sum(
        1 for row in focus_confirmation_rows if independent(row)
    )

    trend_source=[
        row for row in reversed(all_history[:100])
        if number(row.get("mastery_after")) is not None
        and primary_id is not None
        and row_kc(row)==primary_id
        and mastery_evidence_eligible(row)
    ]
    mastery_trend=[{
        "timestamp": timestamp(row),
        "value": number(row.get("mastery_after")),
        "item_id": row.get("current_item"),
        "activity_id": row.get("activity_id"),
        "knowledge_component_id": row_kc(row) or None,
        "evidence_role": evidence_role(row),
        "first_independent_correct": (
            row.get("learning_observation_correct")
            if row.get("learning_observation_correct") is not None
            else row.get("first_attempt_correct")
        ),
        "mastery_update_applied": mastery_evidence_eligible(row),
    } for row in trend_source[-6:]]

    kc_observations={}
    for row in all_history[:100]:
        if not mastery_evidence_eligible(row):
            continue
        kc_id=row_kc(row)
        if not kc_id:
            continue
        stats=kc_observations.setdefault(kc_id,{
            "observations":0,
            "independent_observations":0,
            "supported_observations":0,
            "last_observed_at":None,
        })
        stats["observations"]+=1
        if independent(row):
            stats["independent_observations"]+=1
        else:
            stats["supported_observations"]+=1
        stats["last_observed_at"]=(
            stats["last_observed_at"] or timestamp(row)
        )

    activity_groups={}
    for row in all_history:
        activity_id=str(row.get("activity_id") or "")
        if activity_id in ACTIVITY_NAMES:
            activity_groups.setdefault(activity_id,[]).append(row)

    activity_summaries=[]
    for activity_id in sorted(
        activity_groups,
        key=lambda value: tuple(int(part) for part in value.split(".")),
    ):
        rows=activity_groups[activity_id]
        kc_id=next((row_kc(row) for row in rows if row_kc(row)),None)
        eligible=[row for row in rows if mastery_evidence_eligible(row)]
        core=[row for row in rows if evidence_role(row)=="CORE"]
        remediation=[row for row in rows if evidence_role(row)=="REMEDIATION"]
        confirmation=[row for row in rows if evidence_role(row)=="CONFIRMATION"]
        independent_core_rows=[row for row in core if independent(row)]
        independent_confirmation_rows=[
            row for row in confirmation if independent(row)
        ]
        task_attempts=[]
        for row in rows:
            item_id=str(row.get("current_item") or "")
            role=evidence_role(row)
            first_correct=row.get("learning_observation_correct")
            if first_correct is None:
                first_correct=row.get("first_attempt_correct")
            applications=row.get("scaffold_applications") or []
            support_actions=[]
            for application in applications:
                if not isinstance(application,dict):
                    continue
                # Rendered command types are the clearest description of what
                # the learner actually saw. Never expose opaque action IDs.
                actions=list(application.get("command_types") or [])
                direct=(
                    application.get("command")
                    or application.get("action")
                    or application.get("type")
                )
                if direct:
                    actions.append(direct)
                for action in actions:
                    if action and str(action) not in support_actions:
                        support_actions.append(str(action))
            preview=_task_preview(row,items_by_id.get(item_id,{}))
            if not support_actions:
                for attempt in preview["response_attempts"]:
                    for action in attempt.get("support_actions_before_response",[]):
                        if action and str(action) not in support_actions:
                            support_actions.append(str(action))
            if not support_actions and row.get("event_id"):
                support_actions.extend(
                    policy_actions_by_event.get(str(row["event_id"]),[])
                )
            if not support_actions:
                support_actions.extend(policy_actions_by_task.get((
                    str(row.get("session_id") or ""),item_id,
                ),[]))
            attempt_count=row.get("attempt_count")
            if number(attempt_count) in {None,0} and preview["response_attempts"]:
                attempt_count=len(preview["response_attempts"])
            incorrect_attempt_count=row.get("incorrect_attempt_count")
            if number(incorrect_attempt_count) is None and preview["response_attempts"]:
                incorrect_attempt_count=sum(
                    1 for attempt in preview["response_attempts"]
                    if attempt.get("is_correct") is not True
                )
            task_attempts.append({
                "item_id":item_id,
                "round":_task_round(item_id),
                "role":role,
                "timestamp":timestamp(row),
                "session_id":row.get("session_id"),
                "first_response_correct":first_correct,
                "final_correct":row.get("is_correct"),
                "completed_independently":independent(row),
                "response_quality":row.get("response_quality"),
                "scaffold_level":int(
                    row.get("scaffold_level_used",row.get("scaffold_level",0))
                    or 0
                ),
                "support_actions":support_actions,
                "attempt_count":attempt_count,
                "incorrect_attempt_count":incorrect_attempt_count,
                "first_touch_latency_ms":row.get("first_touch_latency_ms"),
                "total_round_latency_ms":row.get("total_round_latency_ms"),
                "struggled_targets":row.get("struggled_target_units") or [],
                "mastery_before":number(row.get("mastery_before")),
                "mastery_after":number(row.get("mastery_after")),
                "mastery_update_applied":mastery_evidence_eligible(row),
                "preview":preview,
            })
        activity_summaries.append({
            "activity_id":activity_id,
            "activity_name":ACTIVITY_NAMES[activity_id],
            "skill_id":activity_id.split(".")[0],
            "skill_name":SKILL_NAMES.get(activity_id.split(".")[0],"Learning"),
            "knowledge_component_id":kc_id,
            "knowledge_component_name":KC_NAMES.get(
                kc_id,kc_id.removeprefix("KC_").replace("_"," ").title()
                if kc_id else "Unavailable"
            ),
            "mastery":number((state.get("knowledge_state") or {}).get(kc_id)),
            "observations":len(eligible),
            "core_tasks":len(core),
            "independent_core_tasks":len(independent_core_rows),
            "supported_core_tasks":len(core)-len(independent_core_rows),
            "remediation_tasks":len(remediation),
            "confirmation_tasks":len(confirmation),
            "independent_confirmations":len(independent_confirmation_rows),
            "session_count":len({
                str(row.get("session_id")) for row in rows if row.get("session_id")
            }),
            "last_observed_at":timestamp(rows[0]) if rows else None,
            "trend":[{
                "timestamp":timestamp(row),
                "value":number(row.get("mastery_after")),
                "role":evidence_role(row),
                "first_response_correct":row.get(
                    "learning_observation_correct",
                    row.get("first_attempt_correct"),
                ),
                "item_id":row.get("current_item"),
            } for row in reversed(eligible[:12])],
            "task_attempts":task_attempts,
        })

    skill_summaries=[]
    for skill_id,skill_name in SKILL_NAMES.items():
        activities=[
            activity for activity in activity_summaries
            if activity["skill_id"]==skill_id
        ]
        mastery_values_for_skill=[
            activity["mastery"] for activity in activities
            if activity.get("mastery") is not None
        ]
        core_count=sum(activity["core_tasks"] for activity in activities)
        independent_count=sum(
            activity["independent_core_tasks"] for activity in activities
        )
        skill_summaries.append({
            "skill_id":skill_id,
            "skill_name":skill_name,
            "activities_attempted":len(activities),
            "activities_total":5 if skill_id!="4" else 4,
            "average_mastery":(
                sum(mastery_values_for_skill)/len(mastery_values_for_skill)
                if mastery_values_for_skill else None
            ),
            "core_tasks":core_count,
            "independent_core_tasks":independent_count,
            "supported_core_tasks":core_count-independent_count,
            "confirmation_tasks":sum(
                activity["confirmation_tasks"] for activity in activities
            ),
            "independent_confirmations":sum(
                activity["independent_confirmations"] for activity in activities
            ),
            "activity_ids":[activity["activity_id"] for activity in activities],
        })

    target_groups={}
    for row in all_history[:100]:
        activity=str(row.get("activity_id") or "")
        for raw_unit in (row.get("struggled_target_units") or []):
            unit=str(raw_unit).strip()
            if not unit:
                continue
            group=target_groups.setdefault(unit,{
                "unit":unit,"observations":0,"activities":set(),"last_observed_at":None
            })
            group["observations"]+=1
            if activity:
                group["activities"].add(activity)
            group["last_observed_at"]=group["last_observed_at"] or timestamp(row)
    recurring_targets=[]
    for group in target_groups.values():
        if group["observations"] < 2:
            continue
        recurring_targets.append({
            **group,
            "activities":sorted(group["activities"]),
        })
    recurring_targets=sorted(
        recurring_targets,key=lambda row:(row["observations"],len(row["activities"])),reverse=True
    )[:6]

    focus_rows=[row for row in all_history if primary_id and row_kc(row)==primary_id]
    plan_source=focus_rows
    plan_activity=str(plan_source[0].get("activity_id") or "") if plan_source else ""
    activity_parts=plan_activity.split(".")
    practice_available=(
        len(activity_parts)==2
        and all(part.isdigit() for part in activity_parts)
        and 1 <= int(activity_parts[0]) <= 4
        and 1 <= int(activity_parts[1]) <= 5
    )
    focus_evidence=(
        f"Current {primary_name.lower()} mastery estimate is {round(primary_focus[1]*100)}%."
        if primary_focus else "More observed tasks are needed before selecting a focus."
    )
    next_session_plan={
        "focus_knowledge_component_id":primary_id,
        "focus_name":primary_name,
        "activity_id":plan_activity or None,
        "minutes":5,
        "practice_available":practice_available,
        "evidence":focus_evidence,
        "instruction":(
            f"Use reviewed {primary_name.lower()} practice for 5 minutes, then check learning with a fresh equivalent item."
            if primary_focus else "Continue normal activities while the app gathers more learning evidence."
        ),
    }

    latest_measurement_se = None
    timeline=[]
    for d in reversed(history):
        reason_codes = d.get("policy_reason") or []
        if isinstance(reason_codes, str):
            reason_codes = [reason_codes]
        measurement_se = number(d.get("measurement_standard_error"))
        if measurement_se is not None:
            latest_measurement_se = measurement_se
        timeline.append(dict(timestamp=timestamp(d) or "Unavailable", mastery_before=number(d.get("mastery_before")),
            mastery_after=number(d.get("mastery_after")), fatigue=number(d.get("behavioral_fatigue_indicator", d.get("fatigue_score"))),
            previous_difficulty=number(d.get("difficulty_b", d.get("previous_difficulty"))), selected_difficulty=number(d.get("selected_difficulty")),
            scaffold_level=d.get("scaffold_level",0), next_activity=d.get("next_activity",d.get("selected_activity","Unavailable")),
            decision=d.get("decision", "Unavailable"),
            reason=d.get("decision_reason") or ", ".join(reason_codes) or "Unavailable",
            reason_codes=reason_codes,item_id=d.get("current_item"),
            knowledge_component_id=d.get("kc_id"),response_quality=d.get("response_quality"),
            item_role=d.get("item_role"),mastery_evidence_role=evidence_role(d),
            mastery_update_applied=mastery_evidence_eligible(d)))
    policy_rows=(await records(db,"policy_decisions",student_id))[:100]
    c3_audit_rows=await records(db,"model_audit_log",student_id,20)
    c3_audit=next(
        (row for row in c3_audit_rows if row.get("model_name") == "XGBoost"),
        {},
    )
    action_groups = {}
    for row in policy_rows:
        action = row.get("applied_action") or "Unavailable"
        group = action_groups.setdefault(action, {"action": action, "uses": 0, "outcomes": 0, "independent_successes": 0})
        group["uses"] += 1
        if row.get("outcome_observed") is True:
            group["outcomes"] += 1
            group["independent_successes"] += int(row.get("outcome_first_attempt_correct") is True)
    effectiveness = []
    for group in action_groups.values():
        outcomes = group["outcomes"]
        effectiveness.append({
            **group,
            "next_independent_success_rate": (
                round(group["independent_successes"] / outcomes, 4)
                if outcomes else None
            ),
        })
    latest_policy = policy_rows[0] if policy_rows else {}
    origins = sorted({str(row.get("data_origin") or "unspecified") for row in policy_rows})
    comparable_policy_rows = [
        row for row in policy_rows
        if row.get("model_recommendation") and row.get("applied_action")
    ]
    recommendation_agreements = sum(
        1 for row in comparable_policy_rows
        if row.get("model_recommendation") == row.get("applied_action")
    )
    model_status = latest_policy.get("model_validation_status", "unavailable")
    policy_mode = latest_policy.get("policy_mode", "baseline")
    controls_live_adaptation = bool(
        latest_policy.get("controls_live_adaptation")
        or (
            policy_mode == "model"
            and model_status in {"pilot_approved", "validated_observed"}
        )
    )
    execution_source = latest_policy.get(
        "execution_source", "deterministic_capability_policy"
    )
    # The Skill 1-2 cross-activity target-memory experiment is retired. Keep
    # the response field for API compatibility, but do not surface historical
    # experimental rows as current therapist recommendations.
    persistent_learning_needs = []
    return TherapistC4AdaptiveDTO(**mlbase(student_id,state,"BKT + Rasch + action-outcome shadow model","c4-v3"),
        knowledge_components=[dict(
            id=k,
            name=KC_NAMES.get(k,k.removeprefix("KC_").replace("_"," ").title()),
            mastery=v,
            **kc_observations.get(k,{}),
        ) for k,x in (state.get("knowledge_state") or {}).items() if (v:=number(x)) is not None],
        skills=skill_summaries,
        activities=activity_summaries,
        theta=number(state.get("theta_estimate")), theta_se=number(state.get("theta_se")), updated_at_state=timestamp(state), history=timeline,
        policy_status={
            "mode": policy_mode,
            "applied_policy": execution_source,
            "model_version": latest_policy.get("model_version"),
            "model_validation_status": model_status,
            "fallback_reason": latest_policy.get("fallback_reason"),
            "controls_live_adaptation": controls_live_adaptation,
            "evidence_scope": (
                "Synthetic-trained model simulation; functional evidence only, not child efficacy"
                if execution_source == "synthetic_model_simulation"
                else "Observed shadow comparison; descriptive, not causal"
                if policy_rows else "No action-policy observations yet"
            ),
        },
        latest_policy_decision={key: latest_policy.get(key) for key in (
            "timestamp", "item_id", "candidate_actions", "model_recommendation",
            "model_confidence", "applied_action", "predicted_next_independent_success",
            "action_utilities", "execution_source", "controls_live_adaptation",
            "proximal_next_response_correct", "proximal_response_phase",
            "outcome_first_attempt_correct", "outcome_response_quality", "outcome_item_id",
        )},
        support_effectiveness=sorted(effectiveness, key=lambda row: row["action"]),
        persistent_learning_needs=persistent_learning_needs,
        summary={
            "window_decisions":len(history),
            "primary_focus_id":primary_id,
            "primary_focus_name":primary_name,
            "primary_mastery":primary_focus[1] if primary_focus else None,
            "core_tasks":len(core_rows),
            "independent_core_tasks":independent_core,
            "supported_core_tasks":supported_core,
            "support_dependence_rate":(
                round(supported_core/len(core_rows),4) if core_rows else None
            ),
            "confirmation_tasks":len(confirmation_rows),
            "independent_confirmations":independent_confirmations,
            "independent_transfer_rate":(
                round(independent_confirmations/len(confirmation_rows),4)
                if confirmation_rows else None
            ),
            "transfer_evidence_level":(
                "established" if len(focus_confirmation_rows)>=5
                else "early" if focus_confirmation_rows else "unavailable"
            ),
            "focus_core_tasks":len(focus_core_rows),
            "focus_independent_core_tasks":focus_independent_core,
            "focus_supported_core_tasks":focus_supported_core,
            "focus_confirmation_tasks":len(focus_confirmation_rows),
            "focus_independent_confirmations":focus_independent_confirmations,
            "observed_skills":sum(
                1 for skill in skill_summaries
                if skill["activities_attempted"]>0
            ),
            "observed_activities":len(activity_summaries),
            "all_core_tasks":sum(
                activity["core_tasks"] for activity in activity_summaries
            ),
            "all_independent_core_tasks":sum(
                activity["independent_core_tasks"]
                for activity in activity_summaries
            ),
            "all_supported_core_tasks":sum(
                activity["supported_core_tasks"]
                for activity in activity_summaries
            ),
            "all_confirmation_tasks":sum(
                activity["confirmation_tasks"]
                for activity in activity_summaries
            ),
            "all_independent_confirmations":sum(
                activity["independent_confirmations"]
                for activity in activity_summaries
            ),
        },
        mastery_trend=mastery_trend,
        recurring_targets=recurring_targets,
        next_session_plan=next_session_plan,
        data_quality={
            "decision_rows": len(history),
            "available_decision_rows":len(all_history),
            "window_size":window,
            "policy_rows": len(policy_rows),
            "policy_rows_with_proximal_outcomes": sum(1 for row in policy_rows if row.get("proximal_outcome_observed") is True),
            "policy_rows_with_outcomes": sum(1 for row in policy_rows if row.get("outcome_observed") is True),
            "recommendation_comparisons": len(comparable_policy_rows),
            "recommendation_agreements": recommendation_agreements,
            "recommendation_agreement_rate": (
                round(recommendation_agreements / len(comparable_policy_rows), 4)
                if comparable_policy_rows else None
            ),
            "data_origins": origins,
            "c3_pipeline_status": c3_audit.get("status") or "not_run",
            "c3_missing_inputs": list(c3_audit.get("missing_features") or []),
            "calibration_warning": "Rasch/BKT calibration requires an approved observed cohort; synthetic rows are excluded.",
        })

@router.get("/{student_id}/research-evidence")
async def get_therapist_evidence(student_id: str):
    return await research_evidence(get_db(),student_id)

@router.get("/{student_id}/research-summary")
async def get_therapist_research_summary(student_id: str):
    result={"student_id":student_id}
    for key,fn in (("c1_behavioral",get_therapist_c1_behavioral),("c2_speech",get_therapist_c2_speech),
                   ("c3_profile",get_therapist_c3_profile),("c4_adaptive",get_therapist_c4_adaptive)):
        result[key]=(await fn(student_id)).model_dump()
    result["research_evidence"]=await get_therapist_evidence(student_id)
    return result

@router.get("/{student_id}/report/pdf")
async def get_therapist_research_pdf(student_id: str):
    from utils.research_report_generator import generate_research_pdf
    d=await get_therapist_research_summary(student_id)
    content=generate_research_pdf(student_id,d["c1_behavioral"],d["c2_speech"],d["c3_profile"],d["c4_adaptive"])
    return Response(content=content,media_type="application/pdf",headers={"Content-Disposition":f'attachment; filename="Sipsara_Report_{student_id}.pdf"'})

from pydantic import BaseModel
class ReviewAssessmentRequest(BaseModel):
    reviewed: bool = True

@router.patch("/{student_id}/review-assessment/{category}")
async def review_assessment(student_id: str, category: str, req: ReviewAssessmentRequest):
    db = get_db()
    from bson import ObjectId
    try:
        obj_id = ObjectId(student_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid student ID")
    
    field = f"reviewed_assessments.{category}"
    await db.students.update_one(
        {"_id": obj_id},
        {"$set": {field: req.reviewed}}
    )
    student_doc = await db.students.find_one({"_id": obj_id})
    return {
        "student_id": student_id,
        "category": category,
        "reviewed": req.reviewed,
        "reviewed_assessments": student_doc.get("reviewed_assessments", {}) if student_doc else {}
    }
