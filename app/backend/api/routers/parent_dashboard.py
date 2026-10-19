from fastapi import APIRouter, Depends, HTTPException, Path, Query, Response
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta, timezone
import re
from schemas.dashboards import (
    ParentOverviewDTO,
    ParentReadingFluencyDTO,
    ParentReadingProgressDTO,
    ParentLearningPatternDTO,
    ParentActivityHistoryDTO,
    ActivityHistoryItem,
    RoundJourneyItem,
    RecommendedPracticeItem,
    AdaptiveInsightItem,
    ParentAdaptiveInsightsDTO
)
import sys
from pathlib import Path as PathLib
sys.path.insert(0, str(PathLib(__file__).parent.parent.parent.parent))
from shared.database import get_db
from services.dashboard_access import require_dashboard_access
from services.dashboard_data import KC_NAMES, number, timestamp, records, base, pattern_profile, research_evidence, speech

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
    if not durations:
        # Read-only compatibility for pre-v2 stores where the complete session
        # document lived in telemetry_events. New writes still use
        # telemetry_sessions, so this does not duplicate current data.
        legacy_pipeline=[{"$match":{"student_id":student_id}},
                         {"$group":{"_id":"$session_id","seconds":{"$max":"$session_duration_seconds"}}},
                         {"$group":{"_id":None,"seconds":{"$sum":"$seconds"}}}]
        durations=await db.telemetry_events.aggregate(legacy_pipeline).to_list(length=1)
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
async def get_parent_activity_history(student_id:str,limit:int=Query(10,ge=1,le=50),days:Optional[int]=Query(None,ge=1,le=365)):
    db=get_db(); rows=await records(db,"session_summaries",student_id)
    cutoff=(datetime.now(timezone.utc)-timedelta(days=days)).isoformat().replace("+00:00","Z") if days else None
    if cutoff: rows=[r for r in rows if (timestamp(r) or "")>=cutoff]
    history=[]
    for r in rows:
        raw=await db.telemetry_sessions.find_one({"student_id":student_id,"session_id":r.get("session_id"),"schema_version":"2.0"})
        if raw is None:
            raw=await db.telemetry_events.find_one({
                "student_id":student_id,
                "session_id":r.get("session_id"),
                "events":{"$exists":True},
            })
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

@router.get("/{student_id}/component-analytics")
async def get_parent_component_analytics(student_id: str):
    """Parent-safe projections for the four research components.

    Missing measurements remain null and each component carries its own
    availability/provenance instead of silently falling back to demo values.
    """
    db = get_db()
    summaries = (await records(db, "session_summaries", student_id))[:10]
    speech_rows = (await records(db, "speech_features", student_id))[:50]
    profile_rows = await records(db, "learner_profiles", student_id, 1)
    state_rows = await records(db, "knowledge_states", student_id, 1)
    decisions = (await records(db, "adaptive_decisions", student_id))[:50]

    latest_summary = summaries[0] if summaries else {}
    latest_speech = speech_rows[0] if speech_rows else {}
    latest_profile = profile_rows[0] if profile_rows else {}
    latest_state = state_rows[0] if state_rows else {}
    overall = latest_summary.get("overall") or {}

    c1_trend = []
    for row in reversed(summaries):
        accuracy = number((row.get("overall") or {}).get("accuracy"))
        c1_trend.append({"session": row.get("session_id"), "accuracy": accuracy})

    speech_latest = speech(latest_speech)
    quality_label = {
        "valid": "Clear enough to measure",
        "retry_required": "Audio needs a clearer recording",
        "uncertain": "Measurement is uncertain",
    }.get(speech_latest.get("recording_quality"), "Not available")
    c2_trend = []
    for row in reversed(speech_rows):
        values = speech(row)
        c2_trend.append({
            "session": row.get("session_id"),
            "wer": values.get("wer"),
            "latency_ms": values.get("acoustic_latency_ms"),
        })

    profile, probabilities, pattern = pattern_profile(latest_profile)
    mastery_values = [number(value) for value in (latest_state.get("knowledge_state") or {}).values()]
    mastery_values = [value for value in mastery_values if value is not None]
    assisted = [d for d in decisions if (d.get("scaffold_level_used", d.get("scaffold_level", 0)) or 0) > 0]

    def component(doc, **values):
        return {
            "available": bool(doc),
            "data_origin": doc.get("data_origin", "observed" if doc else "unspecified"),
            "dataset_id": doc.get("dataset_id"),
            "validation_status": doc.get("validation_status", "not_clinically_validated"),
            "last_data_at": timestamp(doc),
            **values,
        }

    return {
        **base(student_id, latest_summary, "Latest linked component records"),
        "c1_behavioral": component(
            latest_summary,
            session_count=len(summaries),
            summary_text=(f"Touch and activity observations from {len(summaries)} recent sessions." if summaries else "Complete an activity to begin collecting touch and activity observations."),
            first_attempt_accuracy=number(overall.get("accuracy")),
            retry_rate=number(overall.get("retry_rate")),
            median_response_latency_ms=number(overall.get("median_response_latency_ms")),
            correction_rate=number(overall.get("correction_rate")),
            audio_replay_rate=number(overall.get("audio_replay_rate")),
            fatigue_proxy=number(latest_summary.get("behavioral_fatigue_proxy")),
            trend=c1_trend,
        ),
        "c2_speech": component(
            latest_speech,
            recording_count=len(speech_rows),
            summary_text=(f"Reading recording captured. {quality_label}." if latest_speech else "Complete a speaking activity to begin collecting reading observations."),
            wer=speech_latest.get("wer"),
            word_accuracy=speech_latest.get("word_accuracy"),
            acoustic_latency_ms=speech_latest.get("acoustic_latency_ms"),
            pause_count=speech_latest.get("pause_count"),
            pause_ratio=speech_latest.get("pause_ratio"),
            grapheme_accuracy=speech_latest.get("grapheme_accuracy"),
            reading_rate_wpm=speech_latest.get("reading_rate_wpm"),
            combined_confidence=speech_latest.get("combined_confidence"),
            recording_quality=speech_latest.get("recording_quality"),
            measurement_status=speech_latest.get("measurement_status"),
            trend=c2_trend,
        ),
        "c3_explainability": component(
            latest_profile,
            primary_pattern=pattern,
            confidence=number(profile.get("confidence")),
            probabilities=probabilities,
            explanation_status=(
                "Experimental synthetic-trained model output; not a diagnosis."
                if latest_profile else "No linked multimodal profile is available."
            ),
        ),
        "c4_adaptive": component(
            latest_state,
            average_mastery=(sum(mastery_values) / len(mastery_values)) if mastery_values else None,
            knowledge_components=len(mastery_values),
            decision_count=len(decisions),
            supported_decision_rate=(len(assisted) / len(decisions)) if decisions else None,
            latest_decision=(decisions[0].get("decision") if decisions else None),
        ),
    }

# ==========================================
# REVIEWED ACTIVITY METADATA (Skills 1-4)
# ==========================================
ACTIVITY_NAMES = {
    "1.1": "සැඟවුණු පින්තූර සොයමු (Hidden Picture Search)",
    "1.2": "සෙවණැල්ලට පින්තූරය ගළපමු (Shadow Matching)",
    "1.3": "පින්තූර වෙන් කරමු (Picture Sorting)",
    "1.4": "රටාව සම්පූර්ණ කරමු (Pattern Completion)",
    "1.5": "පින්තූර මතකයෙන් සොයමු (Picture Memory)",
    "2.1": "අකුරු හඳුනමු (Letter Identification)",
    "2.2": "අකුරු ගලපමු (Letter Matching)",
    "2.3": "අහලා හඳුනමු (Listen & Identify)",
    "2.4": "අකුරු කියවමු (Letter Decoding)",
    "2.5": "අකුරු මතක තබමු (Letter Memory)",
    "3.1": "පින්තූරයට වචනය තෝරමු (Choose the Word)",
    "3.2": "අකුරුවලින් වචන හදමු (Build Words)",
    "3.3": "වචන අසා හඳුනා ගනිමු (Listen & Identify Words)",
    "3.4": "අඩු අකුර සොයමු (Find the Missing Letter)",
    "3.5": "අකුරු පිළිවෙළට සකසමු (Order the Letters)",
    "4.1": "පින්තූරයට වාක්‍යය තෝරමු (Choose the Sentence)",
    "4.2": "වචන යොදා වාක්‍ය හදමු (Build Sentences)",
    "4.3": "වාක්‍ය අසා හඳුනා ගනිමු (Listen & Identify Sentences)",
    "4.4": "වචන පිළිවෙළට සකසමු (Order the Words)",
}

ACTIVITY_ROUNDS_TOTAL = {
    **{f"1.{activity}": 5 for activity in range(1, 6)},
    "2.1": 7,
    "2.2": 5,
    "2.3": 5,
    "2.4": 5,
    "2.5": 5,
    **{f"3.{activity}": 5 for activity in range(1, 6)},
    **{f"4.{activity}": 4 for activity in range(1, 5)},
}

PARENT_SKILL_PRESENTATION = {
    "1": {"title": "Pictures", "icon_key": "pictures"},
    "2": {"title": "Letters", "icon_key": "letters"},
    "3": {"title": "Words", "icon_key": "words"},
    "4": {"title": "Sentences", "icon_key": "sentences"},
}

# Parent-facing labels deliberately avoid research terminology. The score shown
# in the app is still traceable to the student's current Component-4 knowledge
# state (or, for legacy rows, the latest first-try activity evidence).
ACTIVITY_TO_KC = {
    "1.1": "KC_VISUAL_IDENTIFICATION",
    "1.2": "KC_VISUAL_MATCHING",
    "1.3": "KC_VISUAL_CATEGORIZATION",
    "1.4": "KC_VISUAL_PATTERN",
    "1.5": "KC_VISUAL_MEMORY",
    "2.1": "KC_LETTER_IDENTIFICATION",
    "2.2": "KC_LETTER_MATCHING",
    "2.3": "KC_PHONEME_LETTER_MAPPING",
    "2.4": "KC_LETTER_DECODING",
    "2.5": "KC_LETTER_MEMORY",
    "3.1": "KC_WORD_RECOGNITION",
    "3.2": "KC_WORD_FORMATION",
    "3.3": "KC_AUDITORY_WORD_RECOGNITION",
    "3.4": "KC_WORD_COMPLETION",
    "3.5": "KC_WORD_SEQUENCING",
    "4.1": "KC_SENTENCE_COMPREHENSION",
    "4.2": "KC_SENTENCE_COMPLETION",
    "4.3": "KC_AUDITORY_SENTENCE_RECOGNITION",
    "4.4": "KC_SENTENCE_SEQUENCING",
}

PARENT_KC_PRESENTATION = {
    "KC_VISUAL_IDENTIFICATION": {
        "title": "Picture recognition", "icon_key": "pictures",
        "home_practice": "Name three familiar objects and ask your child to point to each matching picture.",
    },
    "KC_VISUAL_MATCHING": {
        "title": "Picture matching", "icon_key": "matching",
        "home_practice": "Place two picture pairs face up and find the pictures that match.",
    },
    "KC_VISUAL_CATEGORIZATION": {
        "title": "Sorting pictures", "icon_key": "sorting",
        "home_practice": "Sort four familiar pictures into two simple groups and say why they belong together.",
    },
    "KC_VISUAL_PATTERN": {
        "title": "Finding patterns", "icon_key": "patterns",
        "home_practice": "Make a short colour or object pattern and ask what should come next.",
    },
    "KC_VISUAL_MEMORY": {
        "title": "Picture memory", "icon_key": "memory",
        "home_practice": "Show three familiar pictures, cover them, and ask which pictures were there.",
    },
    "KC_LETTER_IDENTIFICATION": {
        "title": "Recognising letters", "icon_key": "letters",
        "home_practice": "Show two Sinhala letter cards and ask your child to point to the letter you name.",
    },
    "KC_LETTER_MATCHING": {
        "title": "Matching letters", "icon_key": "matching",
        "home_practice": "Use two pairs of Sinhala letter cards and find the matching pair together.",
    },
    "KC_PHONEME_LETTER_MAPPING": {
        "title": "Listening to letters", "icon_key": "listening",
        "home_practice": "Spend five minutes matching one spoken sound to two Sinhala letter cards.",
    },
    "KC_LETTER_DECODING": {
        "title": "Finding letters in words", "icon_key": "letters",
        "home_practice": "Say a short familiar word and find its first letter from two letter cards.",
    },
    "KC_LETTER_MEMORY": {
        "title": "Remembering letters", "icon_key": "memory",
        "home_practice": "Show two Sinhala letters, cover them, and ask your child to name or point to one.",
    },
    "KC_WORD_RECOGNITION": {
        "title": "Recognising words", "icon_key": "words",
        "home_practice": "Match two familiar word cards to their pictures and read each word together.",
    },
    "KC_WORD_FORMATION": {
        "title": "Building words", "icon_key": "words",
        "home_practice": "Build one familiar two-letter word with letter cards, then read it together.",
    },
    "KC_AUDITORY_WORD_RECOGNITION": {
        "title": "Listening to words", "icon_key": "listening",
        "home_practice": "Say one familiar word and ask your child to choose its picture from two choices.",
    },
    "KC_WORD_COMPLETION": {
        "title": "Completing words", "icon_key": "words",
        "home_practice": "Cover one letter in a familiar word and choose the missing letter from two cards.",
    },
    "KC_WORD_SEQUENCING": {
        "title": "Ordering letters", "icon_key": "sequence",
        "home_practice": "Mix the letters of one short familiar word and put them in order together.",
    },
    "KC_SENTENCE_COMPREHENSION": {
        "title": "Understanding sentences", "icon_key": "sentences",
        "home_practice": "Look at a familiar picture and choose which of two short sentences describes it.",
    },
    "KC_SENTENCE_COMPLETION": {
        "title": "Completing sentences", "icon_key": "sentences",
        "home_practice": "Read a short sentence with one missing word and choose the word together.",
    },
    "KC_AUDITORY_SENTENCE_RECOGNITION": {
        "title": "Listening to sentences", "icon_key": "listening",
        "home_practice": "Read one short sentence aloud and ask your child to point to the matching picture.",
    },
    "KC_SENTENCE_SEQUENCING": {
        "title": "Ordering words", "icon_key": "sequence",
        "home_practice": "Mix the words of one short sentence and put them back in order together.",
    },
}

SKILL2_ACTIVITY_NAMES = {
    key: value for key, value in ACTIVITY_NAMES.items() if key.startswith("2.")
}

# Activity metadata for recommendations
ACTIVITY_METADATA = {
    "2.1": {"template_type": "skill2_odd_one_out", "rounds": 7},
    "2.2": {"template_type": "skill2_identical_match", "rounds": 5},
    "2.3": {"template_type": "skill2_audio", "rounds": 5},
    "2.4": {"template_type": "skill2_mcq", "rounds": 5},
    "2.5": {"template_type": "skill2_pattern_memory", "rounds": 5},
}

# KC-based recommendation map: activity -> [rec1, rec2]
RECOMMENDATION_MAP = {
    "2.1": [
        {"id": "2.2", "description": "Strengthens letter matching skills"},
        {"id": "2.3", "description": "Practice letters through sounds"},
    ],
    "2.2": [
        {"id": "2.1", "description": "Strengthens letter recognition"},
        {"id": "2.3", "description": "Practice letters through sounds"},
    ],
    "2.3": [
        {"id": "2.1", "description": "Strengthens visual letter recognition"},
        {"id": "2.2", "description": "Practice matching identical letters"},
    ],
    "2.4": [
        {"id": "2.1", "description": "Builds letter recognition foundation"},
        {"id": "2.3", "description": "Strengthens sound-letter connection"},
    ],
    "2.5": [
        {"id": "2.2", "description": "Reinforces letter matching for memory"},
        {"id": "2.1", "description": "Strengthens letter recognition"},
    ],
}

def _build_recommendations(activity_id: str, remediation_count: int, guided_rounds: int) -> list:
    """Build recommended practice items when child needed help."""
    if remediation_count == 0 and guided_rounds == 0:
        return []
    
    recs = RECOMMENDATION_MAP.get(activity_id, [])
    result = []
    for rec in recs:
        rec_id = rec["id"]
        meta = ACTIVITY_METADATA.get(rec_id, {})
        result.append(RecommendedPracticeItem(
            activity_id=rec_id,
            activity_name=SKILL2_ACTIVITY_NAMES.get(rec_id, f"Activity {rec_id}"),
            description=rec["description"],
            template_type=meta.get("template_type", ""),
            rounds_count=meta.get("rounds", 5)
        ))
    return result

def _is_core_item(activity_id: str, item_id: str) -> bool:
    """Check if an item is a core round (not a variant/remediation)."""
    if not item_id:
        return False
    match = re.fullmatch(r"S(\d+)A(\d+)R(\d+)", str(item_id), re.IGNORECASE)
    return bool(match and f"{int(match.group(1))}.{int(match.group(2))}" == activity_id)

def _extract_round_number(item_id: str) -> int:
    """Extract round number from item_id like S2A1R03 -> 3."""
    try:
        # Find the R and take the digits after it
        r_idx = item_id.rindex("R")
        num_str = item_id[r_idx + 1:].replace("V", "").replace("v", "")[:2]
        return int(num_str)
    except (ValueError, IndexError):
        return 0

def _get_round_result(quality: str, needed_remediation: bool) -> dict:
    """Map response quality + remediation to parent-friendly icon/text."""
    q = (quality or "").upper()
    if q in ["CLEAN_SUCCESS", "MASTERED", "INDEPENDENT_SUCCESS"] and not needed_remediation:
        return {"icon": "⭐", "text": "Got it right!"}
    elif q in ["STRUGGLED_SUCCESS"] and not needed_remediation:
        return {"icon": "👍", "text": "Figured it out after thinking"}
    elif q in ["ASSISTED_SUCCESS"]:
        return {"icon": "💡", "text": "Solved with a helpful hint"}
    elif needed_remediation:
        return {"icon": "📝", "text": "Got extra practice, then solved it"}
    else:
        return {"icon": "👍", "text": "Good attempt"}


@router.get("/{student_id}/adaptive-insights", response_model=ParentAdaptiveInsightsDTO)
async def get_adaptive_insights(student_id: str = Path(...)):
    """Return one current, parent-friendly card per attempted Skill 1-4 activity.

    Each card is restricted to that activity's latest session. This keeps a replay
    from inflating the round journey while ensuring that starting Activity 3 does
    not hide completed Activities 1 and 2.
    """
    db = get_db()
    all_decisions = await db.adaptive_decisions.find(
        {"student_id": student_id}
    ).sort("_id", -1).limit(2000).to_list(length=2000)

    # Rows arrive newest-first. Select the newest session independently for every
    # activity rather than selecting one global session for the whole dashboard.
    latest_session_by_activity: Dict[str, Optional[str]] = {}
    for row in all_decisions:
        activity_id = str(row.get("activity_id"))
        if activity_id in ACTIVITY_NAMES and activity_id not in latest_session_by_activity:
            latest_session_by_activity[activity_id] = row.get("session_id")

    latest_records_by_activity: Dict[str, List[Dict[str, Any]]] = {}
    for activity_id, session_id in latest_session_by_activity.items():
        matching = [
            row for row in all_decisions
            if str(row.get("activity_id")) == activity_id
            and (
                row.get("session_id") == session_id
                if session_id
                else not row.get("session_id")
            )
        ]
        # Current clients always provide a session ID. For legacy rows without one,
        # cap the view to a single curriculum-sized journey rather than presenting
        # every historic database row as one play.
        if not session_id:
            matching = matching[:20]
        latest_records_by_activity[activity_id] = list(reversed(matching))

    summary_decisions = [
        row
        for records_for_activity in latest_records_by_activity.values()
        for row in records_for_activity
    ]
    if not summary_decisions and all_decisions:
        # Compatibility for pre-item-bank rows that did not persist activity_id.
        latest_legacy_session = all_decisions[0].get("session_id")
        summary_decisions = (
            [row for row in all_decisions if row.get("session_id") == latest_legacy_session]
            if latest_legacy_session else all_decisions[:20]
        )
    completed = len(summary_decisions)
    independent = sum(
        1 for row in summary_decisions
        if row.get("response_quality") in {"CLEAN_SUCCESS", "INDEPENDENT_SUCCESS", "MASTERED"}
    )
    supported = sum(
        1 for row in summary_decisions if row.get("response_quality") == "ASSISTED_SUCCESS"
    )
    remediation = sum(1 for row in summary_decisions if row.get("decision") == "REMEDIATION")
    explicit_confirmation_rows = [
        row for row in summary_decisions
        if str(row.get("item_role") or row.get("practice_phase") or "").upper()
        == "CONFIRMATION"
    ]
    routed_confirmation = sum(
        1 for row in summary_decisions if row.get("next_phase") == "CONFIRMATION"
    )
    # Current rows identify a completed confirmation by item_role. Older rows
    # only recorded the transition into confirmation, so preserve a clearly
    # labelled compatibility fallback instead of silently dropping history.
    confirmation = (
        len(explicit_confirmation_rows)
        if explicit_confirmation_rows else routed_confirmation
    )

    def parent_metric_detail(row: Dict[str, Any], metric: str) -> Dict[str, Any]:
        activity_id = str(row.get("activity_id") or "")
        skill_number = activity_id.split(".", 1)[0] if "." in activity_id else ""
        item_id = str(row.get("current_item") or "")
        round_number = _extract_round_number(item_id)
        role = str(row.get("item_role") or row.get("practice_phase") or "").upper()
        if metric == "checked":
            task_kind = "Learning check"
            if role == "CONFIRMATION":
                quality = str(row.get("response_quality") or "").upper()
                detail = (
                    "Completed the fresh check independently."
                    if quality in {"CLEAN_SUCCESS", "INDEPENDENT_SUCCESS", "MASTERED"}
                    else "Completed the fresh check with app support."
                    if quality == "ASSISTED_SUCCESS"
                    else "Completed a fresh check after support."
                )
            else:
                detail = "The app started a fresh check after this task."
        elif metric == "helped":
            task_kind = (
                "Learning check" if role == "CONFIRMATION"
                else "Practice task" if role == "REMEDIATION"
                else "Learning task"
            )
            detail = "Completed after the app provided learning support."
        else:
            task_kind = (
                "Learning check" if role == "CONFIRMATION"
                else "Practice task" if role == "REMEDIATION"
                else "Learning task"
            )
            detail = "Correct on the first try without an app hint."
        skill_meta = PARENT_SKILL_PRESENTATION.get(skill_number, {})
        return {
            "skill_number": int(skill_number) if skill_number.isdigit() else None,
            "skill_title": skill_meta.get("title", "Learning"),
            "skill_icon_key": skill_meta.get("icon_key", "practice"),
            "activity_id": activity_id,
            "activity_name": ACTIVITY_NAMES.get(activity_id, "Learning activity"),
            "task_number": round_number or None,
            "task_label": f"Task {round_number}" if round_number else task_kind,
            "task_kind": task_kind,
            "detail": detail,
        }

    independent_details = [
        parent_metric_detail(row, "independent")
        for row in summary_decisions
        if row.get("response_quality") in {
            "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS", "MASTERED"
        }
    ]
    helped_details = [
        parent_metric_detail(row, "helped")
        for row in summary_decisions
        if row.get("response_quality") == "ASSISTED_SUCCESS"
    ]
    checked_source_rows = (
        explicit_confirmation_rows
        if explicit_confirmation_rows
        else [
            row for row in summary_decisions
            if row.get("next_phase") == "CONFIRMATION"
        ]
    )
    checked_details = [
        parent_metric_detail(row, "checked") for row in checked_source_rows
    ]
    if completed == 0:
        plain_message = "No completed learning tasks are available yet."
    elif supported == 0:
        plain_message = f"Your child completed {completed} tasks without recorded hints."
    else:
        plain_message = (
            f"Your child completed {completed} tasks. The app provided help on "
            f"{supported} tasks and then checked learning with a new task."
        )
    support_summary = {
        "completed_tasks": completed,
        "independent_successes": independent,
        "supported_successes": supported,
        "remediation_routes": remediation,
        "confirmation_checks": confirmation,
        "confirmation_check_basis": (
            "completed_follow_up_items"
            if explicit_confirmation_rows else "legacy_follow_up_routes"
        ),
        "metric_details": {
            "independent": independent_details,
            "helped": helped_details,
            "checked": checked_details,
        },
        "plain_message": plain_message,
        "scope": "Latest attempt for each activity in Skills 1–4",
        "session_id": None,
        "activity_count": len(latest_records_by_activity),
        "session_count": len({
            str(row.get("session_id")) for row in summary_decisions
            if row.get("session_id")
        }),
    }
    
    def activity_sort_key(activity_id: str):
        try:
            skill, activity = activity_id.split(".", 1)
            return int(skill), int(activity)
        except (AttributeError, TypeError, ValueError):
            return 999, 999

    activity_ids = sorted(latest_records_by_activity, key=activity_sort_key)
    activities = []
    practice_origin_by_activity: Dict[str, str] = {}

    for act_id in activity_ids:
        # all_decisions is newest first; calculations below require chronology.
        all_records = [
            row for row in all_decisions if str(row.get("activity_id")) == act_id
        ]
        latest_session_records = latest_records_by_activity.get(act_id, [])
        if not latest_session_records:
            continue
        rounds_total = ACTIVITY_ROUNDS_TOTAL.get(act_id, 5)
        
        # --- 1. Completion Progress ---
        completed_core_rounds = set()
        is_activity_complete = False
        
        for rec in latest_session_records:
            item = rec.get("current_item", "")
            decision = rec.get("decision", "")
            
            if _is_core_item(act_id, item) and rec.get("is_correct", False):
                rn = _extract_round_number(item)
                if rn > 0:
                    completed_core_rounds.add(rn)
            
            if decision in ["ACTIVITY_COMPLETE", "CURRICULUM_COMPLETE"]:
                is_activity_complete = True
        
        rounds_completed = len(completed_core_rounds)
        if is_activity_complete:
            rounds_completed = rounds_total
            completion_text = "Activity Complete! ✅"
        else:
            completion_text = f"{rounds_completed} of {rounds_total} puzzles done"
        
        # --- 2. First-Try Accuracy ---
        # For each core round, check if the FIRST attempt was correct without scaffold
        first_try_results = {}  # round_num -> was_first_try_correct
        seen_core_rounds = set()
        
        for rec in latest_session_records:
            item = rec.get("current_item", "")
            if not _is_core_item(act_id, item):
                continue
            rn = _extract_round_number(item)
            if rn == 0 or rn in seen_core_rounds:
                continue
            seen_core_rounds.add(rn)
            
            quality = rec.get("response_quality", "")
            is_first_try = quality in ["CLEAN_SUCCESS", "MASTERED", "INDEPENDENT_SUCCESS"]
            first_try_results[rn] = is_first_try
        
        first_try_correct = sum(1 for v in first_try_results.values() if v)
        first_try_total = len(first_try_results)
        
        if first_try_total == 0:
            accuracy_text = "No rounds attempted yet"
        elif first_try_correct == first_try_total:
            accuracy_text = f"Got all {first_try_correct} right on the first try! ⭐"
        elif first_try_correct > 0:
            accuracy_text = f"Got {first_try_correct} of {first_try_total} right on the first try"
        else:
            accuracy_text = "Needed some practice, but kept trying!"
        
        # --- 3. App Adaptation Story (Remediation Count) ---
        remediation_count = 0
        remediation_rounds = set()
        
        for rec in latest_session_records:
            decision = rec.get("decision", "")
            policy_reasons = rec.get("policy_reason", [])
            
            if decision == "REMEDIATION":
                rn_item = rec.get("current_item", "")
                rn = _extract_round_number(rn_item) if rn_item else 0
                if rn > 0 and rn not in remediation_rounds:
                    remediation_rounds.add(rn)
                    remediation_count += 1
            # Also check policy_reason for remediation triggers
            for reason in policy_reasons:
                if "STRUGGLED" in str(reason) and "REMEDIATION" not in str(reason):
                    pass  # Already counted via decision
        
        if remediation_count == 0:
            adaptation_text = "Sailed through all puzzles! 🎯"
        elif remediation_count == 1:
            adaptation_text = "The app gave extra practice on 1 tricky puzzle to help 📝"
        else:
            adaptation_text = f"The app gave extra practice on {remediation_count} puzzles to help 📝"
        
        # --- 4. Independence Level ---
        independence_by_round = {}
        
        for rec in latest_session_records:
            item = rec.get("current_item", "")
            if not _is_core_item(act_id, item):
                continue
            rn = _extract_round_number(item)
            if rn <= 0:
                continue
            
            scaffold = rec.get("scaffold_level", 0)
            quality = rec.get("response_quality", "")
            
            if rec.get("is_correct", False):
                if scaffold == 0 and quality in ["CLEAN_SUCCESS", "MASTERED", "INDEPENDENT_SUCCESS"]:
                    independence_by_round.setdefault(rn, True)
                else:
                    independence_by_round[rn] = False

        independent_rounds = sum(1 for value in independence_by_round.values() if value)
        guided_rounds = sum(1 for value in independence_by_round.values() if not value)
        
        total_judged = independent_rounds + guided_rounds
        if total_judged == 0:
            independence_text = "No data yet"
            independence_badge = "Getting Started 🌱"
        elif independent_rounds == total_judged:
            independence_text = f"Solved all {independent_rounds} independently!"
            independence_badge = "Independent Learner 🌟"
        elif independent_rounds > guided_rounds:
            independence_text = f"Solved {independent_rounds} independently, needed hints on {guided_rounds}"
            independence_badge = "Independent Learner 🌟"
        elif independent_rounds > 0:
            independence_text = f"Solved {independent_rounds} independently, needed hints on {guided_rounds}"
            independence_badge = "Guided Learner 💡"
        else:
            independence_text = f"Needed guidance on all {guided_rounds} puzzles"
            independence_badge = "Supported Learner 🤝"
        
        # --- 5. Round Journey ---
        round_journey = []
        core_round_records = {}  # round_num -> first core record
        remediation_triggered = set()
        
        for rec in latest_session_records:
            item = rec.get("current_item", "")
            decision = rec.get("decision", "")
            
            if _is_core_item(act_id, item):
                rn = _extract_round_number(item)
                if rn > 0 and rn not in core_round_records:
                    core_round_records[rn] = rec
            
            # Track which rounds triggered remediation
            if decision == "REMEDIATION":
                rn = _extract_round_number(item)
                if rn > 0:
                    remediation_triggered.add(rn)
        
        for rn in sorted(core_round_records.keys()):
            rec = core_round_records[rn]
            quality = rec.get("response_quality", "")
            needed_rem = rn in remediation_triggered
            result = _get_round_result(quality, needed_rem)
            
            was_first_try = quality in ["CLEAN_SUCCESS", "MASTERED", "INDEPENDENT_SUCCESS"]
            
            round_journey.append(RoundJourneyItem(
                round_number=rn,
                result_icon=result["icon"],
                result_text=result["text"],
                was_first_try=was_first_try,
                needed_remediation=needed_rem
            ))

        # Keep the most recent core task that was not completed independently.
        # This gives the parent UI a concrete, observed practice target instead
        # of inventing a generic weakness from an aggregate percentage.
        struggled_rounds = [
            row.round_number
            for row in round_journey
            if not row.was_first_try or row.needed_remediation
        ]
        if struggled_rounds:
            skill_number, activity_number = act_id.split(".", 1)
            practice_origin_by_activity[act_id] = (
                f"S{int(skill_number)}A{int(activity_number)}"
                f"R{max(struggled_rounds):02d}"
            )
        
        # --- 6. Overall Rating ---
        if first_try_total > 0:
            first_try_ratio = first_try_correct / first_try_total
        else:
            first_try_ratio = 0
        
        if first_try_ratio >= 0.8 and remediation_count == 0:
            star_rating = 3
            rating_text = "⭐⭐⭐ Excellent!"
        elif first_try_ratio >= 0.5 or (is_activity_complete and remediation_count <= 2):
            star_rating = 2
            rating_text = "⭐⭐ Good Progress!"
        else:
            star_rating = 1
            rating_text = "⭐ Keep Practicing!"
        
        # --- Meta ---
        last_record = latest_session_records[-1]
        last_played = last_record.get("timestamp", "")
        distinct_sessions = {
            str(row.get("session_id")) for row in all_records if row.get("session_id")
        }
        # Legacy rows did not carry session_id. They establish that the activity
        # was played, but are not mislabelled as one play per database record.
        times_played = len(distinct_sessions) or (1 if all_records else 0)
        
        # --- 7. Recommended Practice ---
        recommendations = _build_recommendations(act_id, remediation_count, guided_rounds)
        
        activities.append(AdaptiveInsightItem(
            activity_id=act_id,
            activity_name=ACTIVITY_NAMES.get(act_id, f"Activity {act_id}"),
            rounds_completed=rounds_completed,
            rounds_total=rounds_total,
            is_activity_complete=is_activity_complete,
            completion_text=completion_text,
            first_try_correct=first_try_correct,
            first_try_total=first_try_total,
            accuracy_text=accuracy_text,
            remediation_count=remediation_count,
            adaptation_text=adaptation_text,
            independent_rounds=independent_rounds,
            guided_rounds=guided_rounds,
            independence_text=independence_text,
            independence_badge=independence_badge,
            round_journey=round_journey,
            star_rating=star_rating,
            rating_text=rating_text,
            recommendations=recommendations,
            last_played=last_played,
            times_played=times_played
        ))

    # Convert the current Component-4 state into two plain-language parent
    # signals. Only areas the child has actually attempted are eligible. This
    # avoids presenting an untouched skill as a weakness and keeps every score
    # traceable to either BKT state or observed first-try performance.
    state_rows = await records(db, "knowledge_states", student_id, 1)
    knowledge_state = (state_rows[0].get("knowledge_state") or {}) if state_rows else {}
    parent_areas = []
    for activity in activities:
        kc_id = ACTIVITY_TO_KC.get(activity.activity_id)
        presentation = PARENT_KC_PRESENTATION.get(kc_id or "")
        if not presentation or activity.first_try_total <= 0:
            continue
        mastery = number(knowledge_state.get(kc_id))
        if mastery is None:
            mastery = activity.first_try_correct / activity.first_try_total
            score_source = "latest_activity_first_try_evidence"
        else:
            score_source = "component4_mastery_estimate"
        mastery = max(0.0, min(1.0, mastery))
        parent_areas.append({
            "knowledge_component_id": kc_id,
            "activity_id": activity.activity_id,
            "activity_name": activity.activity_name,
            "title": presentation["title"],
            "icon_key": presentation["icon_key"],
            "score": round(mastery, 4),
            "score_percent": round(mastery * 100),
            "evidence_count": activity.first_try_total,
            "independent_rounds": activity.independent_rounds,
            "guided_rounds": activity.guided_rounds,
            "source": score_source,
        })

    strongest_area = max(parent_areas, key=lambda area: area["score"], default=None)
    focus_area = min(parent_areas, key=lambda area: area["score"], default=None)
    if strongest_area:
        strongest_area = dict(strongest_area)
        strongest_area["subtitle"] = (
            "Strong and steady" if strongest_area["score"] >= 0.80
            else "Growing confidently" if strongest_area["score"] >= 0.60
            else "Best current area"
        )
    if focus_area:
        focus_area = dict(focus_area)
        focus_area["subtitle"] = (
            "Still needs support" if focus_area["score"] < 0.50
            else "Building with support" if focus_area["score"] < 0.70
            else "Ready to strengthen"
        )
        focus_area["support_message"] = (
            "The app is giving shorter practice and checking again with a new task."
            if supported or remediation
            else "The app will continue with short practice and check this area again."
        )

    practice_area = focus_area or strongest_area
    home_practice = None
    if practice_area:
        practice_meta = PARENT_KC_PRESENTATION.get(
            practice_area["knowledge_component_id"], {}
        )
        home_practice = {
            "title": f"Practise {practice_area['title'].lower()}",
            "instruction": practice_meta.get("home_practice", ""),
            "minutes": 5,
            "knowledge_component_id": practice_area["knowledge_component_id"],
        }

    # Parent-facing priorities are based only on the latest observed attempt
    # for each activity. A larger score means more first-try misses and/or more
    # guided rounds. The item bank lookup is used only to confirm that the
    # reviewed generic remediation and confirmation pair really exists.
    needs_practice = []
    going_well = []
    for activity in activities:
        misses = max(0, activity.first_try_total - activity.first_try_correct)
        support_count = max(activity.guided_rounds, activity.remediation_count)
        origin_item_id = practice_origin_by_activity.get(activity.activity_id)
        priority_score = misses + (support_count * 2)
        area = next(
            (
                item for item in parent_areas
                if item["activity_id"] == activity.activity_id
            ),
            None,
        )

        if priority_score > 0 and origin_item_id:
            variants = await db.item_bank.find({
                "equivalent_group_id": origin_item_id,
            }).to_list(length=50)
            active_variants = [
                item for item in variants
                if item.get("is_active", True)
                and not item.get("targeted_practice", False)
            ]
            remediation_item = next(
                (
                    item for item in active_variants
                    if str(item.get("item_role", "")).upper() == "REMEDIATION"
                ),
                None,
            )
            confirmation_item = next(
                (
                    item for item in active_variants
                    if str(item.get("item_role", "")).upper() == "CONFIRMATION"
                ),
                None,
            )
            if misses and support_count:
                evidence_text = (
                    f"Needed help on {support_count} task"
                    f"{'s' if support_count != 1 else ''}; "
                    f"{misses} were not correct on the first try."
                )
            elif support_count:
                evidence_text = (
                    f"Needed help on {support_count} task"
                    f"{'s' if support_count != 1 else ''}."
                )
            else:
                evidence_text = (
                    f"{misses} task{'s were' if misses != 1 else ' was'} "
                    "not correct on the first try."
                )
            needs_practice.append({
                "activity_id": activity.activity_id,
                "activity_name": activity.activity_name,
                "title": (area or {}).get("title", activity.activity_name),
                "icon_key": (area or {}).get("icon_key", "practice"),
                "first_try_misses": misses,
                "guided_rounds": activity.guided_rounds,
                "observed_rounds": activity.first_try_total,
                "priority_score": priority_score,
                "evidence_text": evidence_text,
                "origin_item_id": origin_item_id,
                "practice_available": bool(remediation_item and confirmation_item),
                "practice_steps": [
                    {
                        "role": "REMEDIATION",
                        "label": "Shorter supported practice",
                        "item_id": remediation_item.get("item_id"),
                    },
                    {
                        "role": "CONFIRMATION",
                        "label": "Fresh learning check",
                        "item_id": confirmation_item.get("item_id"),
                    },
                ] if remediation_item and confirmation_item else [],
            })
        elif activity.first_try_total > 0:
            going_well.append({
                "activity_id": activity.activity_id,
                "activity_name": activity.activity_name,
                "title": (area or {}).get("title", activity.activity_name),
                "icon_key": (area or {}).get("icon_key", "practice"),
                "independent_rounds": activity.independent_rounds,
                "observed_rounds": activity.first_try_total,
                "evidence_text": (
                    f"Completed {activity.first_try_correct} of "
                    f"{activity.first_try_total} tasks independently on the first try."
                ),
            })

    needs_practice.sort(
        key=lambda item: (
            item["priority_score"], item["guided_rounds"], item["first_try_misses"]
        ),
        reverse=True,
    )
    going_well.sort(
        key=lambda item: item["independent_rounds"], reverse=True
    )

    skill_progress = []
    for skill_number, presentation in PARENT_SKILL_PRESENTATION.items():
        skill_activities = [
            activity for activity in activities
            if activity.activity_id.startswith(f"{skill_number}.")
        ]
        if not skill_activities:
            continue
        observed = sum(activity.first_try_total for activity in skill_activities)
        first_try = sum(activity.first_try_correct for activity in skill_activities)
        helped = sum(activity.guided_rounds for activity in skill_activities)
        completed_activities = sum(
            1 for activity in skill_activities if activity.is_activity_complete
        )
        first_try_ratio = first_try / observed if observed else 0.0
        if observed and first_try_ratio >= 0.80 and helped == 0:
            status = "Going smoothly"
        elif observed and first_try_ratio >= 0.60:
            status = "Building steadily"
        else:
            status = "Needs more practice"
        skill_progress.append({
            "skill_number": int(skill_number),
            "title": presentation["title"],
            "icon_key": presentation["icon_key"],
            "activities_tried": len(skill_activities),
            "activities_available": sum(
                1 for activity_id in ACTIVITY_NAMES
                if activity_id.startswith(f"{skill_number}.")
            ),
            "activities_completed": completed_activities,
            "observed_tasks": observed,
            "first_try_successes": first_try,
            "helped_tasks": helped,
            "first_try_ratio": round(first_try_ratio, 4),
            "status": status,
        })

    confirmation_independent = sum(
        1 for row in explicit_confirmation_rows
        if row.get("response_quality") in {
            "CLEAN_SUCCESS", "INDEPENDENT_SUCCESS", "MASTERED"
        }
    )
    if explicit_confirmation_rows:
        support_result_text = (
            f"After support, {confirmation_independent} of "
            f"{len(explicit_confirmation_rows)} fresh checks were completed "
            "independently."
        )
    elif routed_confirmation:
        support_result_text = (
            f"The app started {routed_confirmation} fresh learning check"
            f"{'s' if routed_confirmation != 1 else ''}. Older records do not "
            "show the check result separately."
        )
    elif supported:
        support_result_text = (
            "Help was used, but no completed fresh learning check is recorded yet."
        )
    else:
        support_result_text = "No learning support was needed in these activities."

    support_summary.update({
        "strongest_area": strongest_area,
        "focus_area": focus_area,
        "home_practice": home_practice,
        "coverage": {
            "activities_tried": len(activities),
            "activities_available": len(ACTIVITY_NAMES),
            "activities_completed": sum(
                1 for activity in activities if activity.is_activity_complete
            ),
        },
        "skill_progress": skill_progress,
        "support_effectiveness": {
            "helped_tasks": supported,
            "completed_follow_up_checks": len(explicit_confirmation_rows),
            "independent_follow_up_checks": confirmation_independent,
            "legacy_follow_up_routes": routed_confirmation,
            "summary": support_result_text,
        },
        "help_story": {
            "tricky_tasks_noticed": supported,
            "extra_practice_routes": remediation,
            "learning_checks": confirmation,
        },
        "needs_practice": needs_practice[:3],
        "going_well": going_well[:2],
    })
    
    latest_policy = await db.policy_decisions.find_one(
        {"student_id": student_id},
        sort=[("_id", -1)],
    )
    execution_source = (latest_policy or {}).get(
        "execution_source", "deterministic_capability_policy"
    )
    if execution_source == "synthetic_model_simulation":
        policy_notice = (
            "Research demonstration mode is active: the app's practice model "
            "chooses among safe, pre-approved help options. This demonstrates "
            "how personalisation works; it is not a diagnosis."
        )
    elif (latest_policy or {}).get("controls_live_adaptation"):
        policy_notice = (
            "The validated learning-support model chooses among safe, "
            "pre-approved help options. It does not diagnose your child."
        )
    else:
        policy_notice = (
            "Your child's learning is guided by tested support rules. Research "
            "predictions are monitored in the background and do not control activities."
        )

    return ParentAdaptiveInsightsDTO(
        **base(
            student_id,
            all_decisions[0] if all_decisions else None,
            "Latest available adaptive observations",
        ),
        activities=activities,
        support_summary=support_summary,
        policy_notice=policy_notice,
    )

@router.get("/{student_id}/report")
async def download_parent_report(student_id:str):
    raise HTTPException(501,"Parent PDF export is not implemented; no placeholder PDF is returned.")
