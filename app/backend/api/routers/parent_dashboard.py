from fastapi import APIRouter, Depends, HTTPException, Query
from datetime import datetime, timezone, timedelta
from schemas.dashboards import ParentOverviewDTO, ParentReadingFluencyDTO, ParentReadingProgressDTO, ParentLearningPatternDTO, ParentActivityHistoryDTO
from shared.database import get_db
from services.dashboard_access import require_dashboard_access
from services.dashboard_data import KC_NAMES, number, timestamp, records, base, pattern_profile, research_evidence

router=APIRouter(prefix="/api/v1/parent/students",tags=["Parent Dashboard"],dependencies=[Depends(require_dashboard_access)])

@router.get("/{student_id}/overview",response_model=ParentOverviewDTO)
async def get_parent_overview(student_id:str):
    db=get_db(); summaries=await records(db,"session_summaries",student_id)
    latest=summaries[0] if summaries else {}
    student = None
    try:
        from bson import ObjectId
        student = await db.students.find_one({"_id": ObjectId(student_id)})
    except Exception:
        pass
    assessment = (student or {}).get("comprehensive_assessment_results") or {}
    category_counts = {
        key: sum(1 for item in value if isinstance(item, dict) and item.get("answer") is True)
        for key, value in assessment.items() if isinstance(value, list)
    }
    assessment_summary = {
        "completed_categories": len([v for v in assessment.values() if isinstance(v, list) and v]),
        "total_categories": 4,
        "reported_observations": sum(category_counts.values()),
        "by_category": category_counts,
        "reviewed": (student or {}).get("reviewed_assessments") or {},
    }
    sessions=await db.session_summaries.distinct("session_id",{"student_id":student_id})
    pipeline=[{"$match":{"student_id":student_id,"schema_version":"2.0"}},
              {"$group":{"_id":"$session_id","seconds":{"$max":"$session_duration_seconds"}}},
              {"$group":{"_id":None,"seconds":{"$sum":"$seconds"}}}]
    durations=await db.telemetry_sessions.aggregate(pipeline).to_list(length=1)
    accuracy=number((latest.get("overall") or {}).get("accuracy"))
    return ParentOverviewDTO(**base(student_id,latest,"Latest accuracy; all completed sessions and measured session duration"),
        accuracy=round(accuracy*100) if accuracy is not None else None,
        practice_time_minutes=round(durations[0]["seconds"]/60) if durations else None,
        sessions_completed=len([x for x in sessions if x]), reading_progress="Practice recorded" if summaries else "No observations yet",
        assessment_summary=assessment_summary)

@router.get("/{student_id}/assessment-summary")
async def get_parent_assessment_summary(student_id: str):
    db = get_db()
    try:
        from bson import ObjectId
        student = await db.students.find_one({"_id": ObjectId(student_id)})
    except Exception:
        student = None
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    assessment = student.get("comprehensive_assessment_results") or {}
    category_counts = {
        key: sum(1 for item in value if isinstance(item, dict) and item.get("answer") is True)
        for key, value in assessment.items() if isinstance(value, list)
    }
    
    return {
        "student_id": student_id,
        "completed_categories": len([v for v in assessment.values() if isinstance(v, list) and v]),
        "total_categories": 4,
        "reported_observations": sum(category_counts.values()),
        "by_category": category_counts,
        "raw_responses": assessment
    }

@router.get("/{student_id}/fluency",response_model=ParentReadingFluencyDTO)
async def get_parent_fluency(student_id:str):
    return ParentReadingFluencyDTO(**base(student_id),fluency_status="Fluency score is not implemented; mastery is not fluency",fluency_score=None)

@router.get("/{student_id}/progress",response_model=ParentReadingProgressDTO)
async def get_parent_progress(student_id:str):
    rows=(await records(get_db(),"session_summaries",student_id))[:10]
    trend=[]
    for r in reversed(rows):
        value=number((r.get("overall") or {}).get("accuracy"))
        trend.append({"session":r.get("session_id"),"accuracy":round(value*100) if value is not None else None})
    return ParentReadingProgressDTO(**base(student_id,rows[0] if rows else {},"Latest 10 sessions, chronological"),accuracy_trend=trend)

@router.get("/{student_id}/skills")
async def get_parent_skills(student_id:str):
    rows=await records(get_db(),"knowledge_states",student_id,1); doc=rows[0] if rows else {}
    skills=[{"skill_name":KC_NAMES.get(k,k),"mastery_percentage":round(v*100),"status":"Model estimate, not a test grade"}
            for k,x in (doc.get("knowledge_state") or {}).items() if (v:=number(x)) is not None]
    return {**base(student_id,doc),"skills":skills}

@router.get("/{student_id}/learning-pattern",response_model=ParentLearningPatternDTO)
async def get_parent_learning_pattern(student_id:str):
    rows=await records(get_db(),"learner_profiles",student_id,1); doc=rows[0] if rows else {}
    _,_,pattern=pattern_profile(doc)
    origin=doc.get("data_origin","unspecified")
    obs=(f"Synthetic demonstration: the experimental model produced a {pattern} pattern. This is not a finding about your child."
         if origin=="synthetic" else f"Experimental model output: {pattern}. Input provenance is {origin}; this does not establish a learning difficulty." if doc else "No learning-pattern evidence is available yet.")
    return ParentLearningPatternDTO(**base(student_id,doc),observation=obs,recommended_practices=[])

@router.get("/{student_id}/activity-history",response_model=ParentActivityHistoryDTO)
async def get_parent_activity_history(student_id:str,limit:int=Query(10,ge=1,le=50),days:int|None=Query(None,ge=1,le=365)):
    db=get_db(); rows=await records(db,"session_summaries",student_id)
    cutoff=(datetime.now(timezone.utc)-timedelta(days=days)).isoformat().replace("+00:00","Z") if days else None
    if cutoff: rows=[r for r in rows if (timestamp(r) or "")>=cutoff]
    history=[]
    for r in rows:
        raw=await db.telemetry_sessions.find_one({"student_id":student_id,"session_id":r.get("session_id"),"schema_version":"2.0"})
        for aid,metrics in (r.get("activity_breakdown") or {}).items():
            # Sum matching actual round durations; never multiply first-touch by trial count.
            events=[e for e in (raw or {}).get("events",[]) if e.get("activity_id")==aid]
            durations=[number(e.get("total_round_latency_ms")) for e in events]
            duration=sum(durations)/60000 if durations and all(v is not None for v in durations) else None
            accuracy=number(metrics.get("accuracy"))
            history.append(dict(session_id=r.get("session_id"),session_date=(timestamp(r) or "Unavailable")[:10],activity_name=aid,
                accuracy=round(accuracy*100) if accuracy is not None else None,duration_minutes=round(duration) if duration is not None else None,
                duration_source="sum of recorded round durations" if duration is not None else "unavailable"))
            if len(history)>=limit: break
        if len(history)>=limit: break
    return ParentActivityHistoryDTO(**base(student_id,rows[0] if rows else {},"Recent activity observations"),history=history)

@router.get("/{student_id}/research-evidence")
async def get_parent_evidence(student_id:str):
    return await research_evidence(get_db(),student_id)

@router.get("/{student_id}/report")
async def download_parent_report(student_id:str):
    raise HTTPException(501,"Parent PDF export is not implemented; no placeholder PDF is returned.")
