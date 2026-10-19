import re

from fastapi import APIRouter, Depends, HTTPException, Response
from schemas.dashboards import (TherapistOverviewDTO, TherapistC1BehavioralDTO, TherapistC2SpeechDTO,
                                TherapistC3ProfileDTO, TherapistC4AdaptiveDTO)
from shared.database import get_db
from services.dashboard_access import require_dashboard_access
from services.dashboard_data import (ACTIVITY_NAMES, KC_NAMES, SKILL_NAMES,
                                     number, timestamp, records, mlbase, speech,
                                     pattern_profile, mastery_status,
                                     research_evidence)

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

@router.get("/{student_id}/overview", response_model=TherapistOverviewDTO)
async def get_therapist_overview(student_id: str):
    db = get_db()
    summaries = await records(db, "session_summaries", student_id)
    speeches = await records(db, "speech_features", student_id, 1)
    profiles = await records(db, "learner_profiles", student_id, 1)
    states = await records(db, "knowledge_states", student_id, 1)
    decisions = await records(db, "adaptive_decisions", student_id, 1)
    latest = summaries[0] if summaries else {}
    values = [number(v) for v in (states[0].get("knowledge_state", {}) if states else {}).values()]
    values = [v for v in values if v is not None]
    mastery = sum(values)/len(values) if values else None
    profile, _, pattern = pattern_profile(profiles[0] if profiles else {})
    fatigue = number(latest.get("behavioral_fatigue_proxy"))
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

    return TherapistOverviewDTO(**mlbase(student_id, latest, "descriptive + BKT/IRT", "c1-v2"),
        accuracy=number((latest.get("overall") or {}).get("accuracy")), attempted_items=latest.get("total_trials", 0),
        completed_sessions=len([x for x in session_ids if x]), reading_fluency_status=mastery_status(mastery),
        overall_mastery=mastery, current_pattern=pattern, pattern_confidence=number(profile.get("confidence")),
        fatigue_status="Unavailable" if fatigue is None else f"Proxy {fatigue:.2f} (not a diagnosis)",
        last_active=timestamp(latest), c1_available=bool(summaries), c2_available=bool(speeches),
        c3_available=bool(profiles), c4_available=bool(states),
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
        parent_name=parent_name)

@router.get("/{student_id}/c1-behavioral", response_model=TherapistC1BehavioralDTO)
async def get_therapist_c1_behavioral(student_id: str):
    history = (await records(get_db(), "session_summaries", student_id))[:10]
    latest = history[0] if history else {}
    overall, errors, kcs = latest.get("overall") or {}, latest.get("error_profile") or {}, latest.get("knowledge_components") or {}
    def trend(field, fatigue=False):
        return [{"session": row.get("session_id"), "value": number(row.get("behavioral_fatigue_proxy") if fatigue else (row.get("overall") or {}).get(field))} for row in reversed(history)]
    has_errors = (number(overall.get("error_rate")) or 0) > 0
    return TherapistC1BehavioralDTO(**mlbase(student_id, latest, "descriptive", "c1-v2"), session_id=latest.get("session_id"),
        first_attempt_accuracy=number(overall.get("accuracy")), median_response_latency_ms=number(overall.get("median_response_latency_ms")),
        retry_rate=number(overall.get("retry_rate")), mean_attempts_per_round=number(overall.get("mean_attempts_per_round")),
        median_time_to_correct_ms=number(overall.get("median_time_to_correct_ms")), correction_rate=number(overall.get("correction_rate")),
        behavioral_fatigue_proxy=number(latest.get("behavioral_fatigue_proxy")),
        kc_performance={kc:number((kcs.get(kc) or {}).get("accuracy")) for kc in KC_NAMES},
        error_distribution={k:number(errors.get(k+"_rate")) if has_errors else None for k in ("visual_confusion", "phonological_confusion", "sequence_error", "unknown_error")},
        trends=dict(accuracy=trend("accuracy"), latency=trend("median_response_latency_ms"), fatigue=trend("", True)))

@router.get("/{student_id}/c2-speech", response_model=TherapistC2SpeechDTO)
async def get_therapist_c2_speech(student_id: str):
    history = (await records(get_db(), "speech_features", student_id))[:10]
    latest = history[0] if history else {}
    usable = sum(1 for row in history if row.get("measurement_status") in {"valid", "available", "synthetic_features"})
    def trend(key):
        return [{"session":row.get("session_id"),"value":speech(row)[key]} for row in reversed(history)]
    return TherapistC2SpeechDTO(**mlbase(student_id, latest, "speech analysis", "c2-pipeline-v3"), recording_count=len(history), usable_recording_count=usable, latest=speech(latest),
        trends=dict(accuracy=[], wer=trend("wer"), latency=trend("acoustic_latency_ms"), silence_ratio=trend("silence_ratio"), peak_delta=trend("peak_delta")))

@router.get("/{student_id}/c3-profile", response_model=TherapistC3ProfileDTO)
async def get_therapist_c3_profile(student_id: str):
    db = get_db()
    rows = await records(db, "learner_profiles", student_id, 1)
    audit_rows = await records(db, "model_audit_log", student_id, 20)
    audit = next(
        (row for row in audit_rows if row.get("model_name") == "XGBoost"),
        {},
    )
    doc = rows[0] if rows else {}
    profile, probs, pattern = pattern_profile(doc)
    explanations=[]
    for f in (doc.get("shap_explanations") or {}).get("top_contributing_features", []):
        contribution=number(f.get("shap_impact"))
        if contribution is not None:
            explanations.append(dict(feature=f.get("feature_name", ""), contribution=contribution,
                observed_value=number(f.get("observed_value", f.get("value"))),
                direction="increases model score" if contribution>0 else "decreases model score" if contribution<0 else "neutral"))
    pipeline_status = audit.get("status") or ("profile_available" if rows else "not_run")
    missing_inputs = list(audit.get("missing_features") or [])
    skip_reason = None
    if not rows and pipeline_status == "skipped_missing_inputs":
        skip_reason = "C3 fusion was safely skipped because required inputs were unavailable."
    elif not rows:
        skip_reason = "Insufficient linked multimodal data to generate a learner profile."
    metadata = mlbase(student_id, doc or audit, "XGBoost", "c3-fusion-v1")
    metadata["available"] = bool(rows)
    return TherapistC3ProfileDTO(**metadata, primary_pattern=pattern,
        probabilities=probs, confidence=number(profile.get("confidence")), modalities_used=profile.get("modalities_used") or [],
        shap_explanations=explanations, llm_summary=doc.get("llm_summary"), llm_recommendations=doc.get("llm_recommendations"),
        pipeline_status=pipeline_status, missing_inputs=missing_inputs,
        skip_reason=skip_reason)

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
