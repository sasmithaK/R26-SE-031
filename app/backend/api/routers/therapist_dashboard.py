from fastapi import APIRouter, Depends, HTTPException, Response
from schemas.dashboards import (TherapistOverviewDTO, TherapistC1BehavioralDTO, TherapistC2SpeechDTO,
                                TherapistC3ProfileDTO, TherapistC4AdaptiveDTO)
from shared.database import get_db
from services.dashboard_access import require_dashboard_access
from services.dashboard_data import (KC_NAMES, number, timestamp, records, mlbase, speech, pattern_profile,
                                     mastery_status, research_evidence)

router = APIRouter(prefix="/api/v1/therapist/students", tags=["Therapist Dashboard"],
                   dependencies=[Depends(require_dashboard_access)])

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
    def trend(key):
        return [{"session":row.get("session_id"),"value":speech(row)[key]} for row in reversed(history)]
    return TherapistC2SpeechDTO(**mlbase(student_id, latest, "speech prototype", "speech-v1"), latest=speech(latest),
        trends=dict(accuracy=[], wer=trend("wer"), latency=trend("acoustic_latency_ms"), silence_ratio=trend("silence_ratio"), peak_delta=trend("peak_delta")))

@router.get("/{student_id}/c3-profile", response_model=TherapistC3ProfileDTO)
async def get_therapist_c3_profile(student_id: str):
    rows = await records(get_db(), "learner_profiles", student_id, 1)
    doc = rows[0] if rows else {}
    profile, probs, pattern = pattern_profile(doc)
    explanations=[]
    for f in (doc.get("shap_explanations") or {}).get("top_contributing_features", []):
        contribution=number(f.get("shap_impact"))
        if contribution is not None:
            explanations.append(dict(feature=f.get("feature_name", ""), contribution=contribution,
                observed_value=number(f.get("observed_value", f.get("value"))),
                direction="increases model score" if contribution>0 else "decreases model score" if contribution<0 else "neutral"))
    return TherapistC3ProfileDTO(**mlbase(student_id, doc, "unavailable", "unavailable"), primary_pattern=pattern,
        probabilities=probs, confidence=number(profile.get("confidence")), modalities_used=profile.get("modalities_used") or [],
        shap_explanations=explanations, llm_summary=doc.get("llm_summary"), llm_recommendations=doc.get("llm_recommendations"),
        skip_reason="Insufficient historical data to formulate a diagnosis" if not rows else None)

@router.get("/{student_id}/c4-adaptive", response_model=TherapistC4AdaptiveDTO)
async def get_therapist_c4_adaptive(student_id: str):
    db=get_db()
    states=await records(db,"knowledge_states",student_id,1)
    state=states[0] if states else {}
    history=(await records(db,"adaptive_decisions",student_id))[:20]
    timeline=[]
    for d in reversed(history):
        timeline.append(dict(timestamp=timestamp(d) or "Unavailable", mastery_before=number(d.get("mastery_before")),
            mastery_after=number(d.get("mastery_after")), fatigue=number(d.get("behavioral_fatigue_indicator", d.get("fatigue_score"))),
            previous_difficulty=number(d.get("previous_difficulty")), selected_difficulty=number(d.get("selected_difficulty")),
            scaffold_level=d.get("scaffold_level",0), next_activity=d.get("next_activity",d.get("selected_activity","Unavailable")),
            decision=d.get("decision", "Unavailable"), reason=d.get("decision_reason","Unavailable")))
    return TherapistC4AdaptiveDTO(**mlbase(student_id,state,"BKT + Rasch","c4-v1"),
        knowledge_components=[dict(id=k,name=KC_NAMES.get(k,k),mastery=v) for k,x in (state.get("knowledge_state") or {}).items() if (v:=number(x)) is not None],
        theta=number(state.get("theta_estimate")), theta_se=number(state.get("theta_se")), updated_at_state=timestamp(state), history=timeline)

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
