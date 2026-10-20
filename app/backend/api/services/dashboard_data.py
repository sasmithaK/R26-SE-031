"""Dashboard projections: preserve missingness, provenance and current storage contracts."""
from datetime import datetime, timezone
import statistics
import math

KC_NAMES = {
    "KC_VISUAL_SUPPORT": "Visual support",
    "KC_VISUAL_IDENTIFICATION": "Picture identification",
    "KC_VISUAL_MATCHING": "Picture matching",
    "KC_VISUAL_CATEGORIZATION": "Picture sorting",
    "KC_VISUAL_PATTERN": "Visual patterns",
    "KC_VISUAL_MEMORY": "Visual memory",
    "KC_AKSHARA_IDENTITY": "Sinhala letter identity",
    "KC_LETTER_IDENTIFICATION": "Letter identification",
    "KC_LETTER_MATCHING": "Letter matching",
    "KC_PHONEME_GRAPHEME": "Sound-letter matching",
    "KC_PHONEME_LETTER_MAPPING": "Sound-letter mapping",
    "KC_LETTER_DECODING": "Letter decoding",
    "KC_ORTHOGRAPHIC_MEMORY": "Letter sequence memory",
    "KC_LETTER_MEMORY": "Letter memory",
    "KC_WORD_RECOGNITION": "Word recognition",
    "KC_WORD_FORMATION": "Word formation",
    "KC_AUDITORY_WORD_RECOGNITION": "Listening for words",
    "KC_WORD_COMPLETION": "Word completion",
    "KC_SPELLING_SEQUENCE": "Spelling sequence",
    "KC_WORD_SEQUENCING": "Word sequencing",
    "KC_SENTENCE_LANGUAGE": "Sentence language",
    "KC_SENTENCE_COMPREHENSION": "Sentence comprehension",
    "KC_SENTENCE_COMPLETION": "Sentence completion",
    "KC_AUDITORY_SENTENCE_RECOGNITION": "Listening for sentences",
    "KC_SENTENCE_SEQUENCING": "Sentence sequencing",
    "KC_READING_COMPREHENSION": "Reading comprehension",
    "KC_ORAL_READING_FLUENCY": "Oral reading",
}

# Canonical curriculum presentation. These labels mirror the child-facing
# curriculum files so parents, therapists, exports, and task evidence all refer
# to an activity by the same name.
SKILL_NAMES = {
    "1": "පින්තූර හඳුනාගනිමු",
    "2": "මූලික අකුරු හඳුනාගනිමු",
    "3": "සරල වචන සකසමු",
    "4": "සරල වාක්‍ය සකසමු",
}
# Reading skills (C2). Kept separate because Component 4 iterates SKILL_NAMES
# and ACTIVITY_NAMES as the Skills 1-4 adaptive scope.
READING_SKILL_NAMES = {
    "5": "කියවා තේරුම් ගනිමු",
    "6": "සිංහල පෙළපොත",
}

SKILL_NAMES_EN = {
    "1": "Picture recognition",
    "2": "Letter recognition",
    "3": "Word building",
    "4": "Sentence building",
    "5": "Reading comprehension",
    "6": "Textbook reading",
}

ACTIVITY_NAMES = {
    "1.1": "සැඟවුණු පින්තූර සොයමු",
    "1.2": "සෙවණැල්ලට පින්තූරය ගළපමු",
    "1.3": "පින්තූර වෙන් කරමු",
    "1.4": "රටාව සම්පූර්ණ කරමු",
    "1.5": "පින්තූර මතකයෙන් සොයමු",
    "2.1": "නිවැරදි අකුර සොයමු",
    "2.2": "සමාන අකුරු සොයමු",
    "2.3": "අකුර අසා හඳුනා ගනිමු",
    "2.4": "අකුර සොයා තෝරමු",
    "2.5": "අකුරු මතකයෙන් සකසමු",
    "3.1": "පින්තූරයට වචනය තෝරමු",
    "3.2": "අකුරුවලින් වචන හදමු",
    "3.3": "වචන අසා හඳුනා ගනිමු",
    "3.4": "අඩු අකුර සොයමු",
    "3.5": "අකුරු පිළිවෙළට සකසමු",
    "4.1": "පින්තූරයට වාක්‍යය තෝරමු",
    "4.2": "වචන යොදා වාක්‍ය හදමු",
    "4.3": "වාක්‍ය අසා හඳුනා ගනිමු",
    "4.4": "වචන පිළිවෙළට සකසමු",
}
READING_ACTIVITY_NAMES = {
    "5.1": "කියවා කරන්න",
    "5.2": "කවුද?",
    "5.3": "මොනවාද?",
    "5.4": "කොහෙද?",
    "6.1": "පෙළපොතෙන් කියවමු - 1",
    "6.2": "පෙළපොතෙන් කියවමු - 2",
}

ACTIVITY_NAMES_EN = {
    "1.1": "Hidden picture search", "1.2": "Shadow matching", "1.3": "Picture sorting",
    "1.4": "Pattern completion", "1.5": "Picture memory",
    "2.1": "Find the letter", "2.2": "Matching letters", "2.3": "Listen and find the letter",
    "2.4": "Choose the letter", "2.5": "Letter memory",
    "3.1": "Picture to word", "3.2": "Build a word", "3.3": "Listen and find the word",
    "3.4": "Missing letter", "3.5": "Put letters in order",
    "4.1": "Picture to sentence", "4.2": "Complete the sentence",
    "4.3": "Listen and find the sentence", "4.4": "Put words in order",
    "5.1": "Read and do", "5.2": "Who?", "5.3": "What?", "5.4": "Where?",
    "6.1": "Textbook reading 1", "6.2": "Textbook reading 2",
}

# Curriculum template types (assets/data/curriculum/skill_N.json) that some
# stored records use as their activity id or name.
TEMPLATE_TO_ACTIVITY = {
    "visual_hidden_search": "1.1", "visual_odd_one_out": "1.2", "visual_shadow_matching": "1.2",
    "visual_sorting_adventure": "1.3", "visual_pattern_adventure": "1.4", "visual_memory_hats": "1.5",
    "skill2_odd_one_out": "2.1", "skill2_identical_match": "2.2", "skill2_audio": "2.3",
    "skill2_mcq": "2.4", "skill2_pattern_memory": "2.5",
    "skill3_image_mcq": "3.1", "skill3_word_formation": "3.2", "skill3_word_formation_mcq": "3.2",
    "skill3_audio_mcq": "3.3", "skill3_fill_blank": "3.4", "skill3_jumbled_word": "3.5",
    "skill4_act1_mcq": "4.1", "skill4_act2_fill_blank": "4.2", "skill4_act3_mcq": "4.3",
    "skill4_act4_jumbled_sentence": "4.4",
    "skill5_act1_mcq": "5.1", "skill5_act2_mcq": "5.2", "skill5_act3_mcq": "5.3", "skill5_act4_mcq": "5.4",
}
# Recording statuses that count as "clear enough to measure" everywhere
# (therapist, parent, coverage, alerts and C3 use the same set).
USABLE_SPEECH_STATUSES = {"valid", "available", "synthetic_features"}

PATTERNS = {name: name.removesuffix(" Learning Pattern") for name in (
    "Typical Learning Pattern", "Phonological Learning Pattern",
    "Visual-Orthographic Learning Pattern", "Combined Learning Pattern")}

def number(value):
    if isinstance(value, bool):
        return None
    try:
        result = float(value)
        return result if math.isfinite(result) else None
    except (ValueError, TypeError):
        return None

def stamp(value):
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    if isinstance(value, str) and value:
        try:
            return stamp(datetime.fromisoformat(value.replace("Z", "+00:00")))
        except ValueError:
            return None
    return None

def timestamp(doc):
    return stamp(doc.get("completed_at") or doc.get("created_at") or doc.get("timestamp") or doc.get("updated_at"))

async def records(db, collection, student_id, limit=200):
    # Bounded projection: newest ingested records, then chronological presentation.
    docs = await db[collection].find({"student_id": student_id}).sort("_id", -1).limit(limit).to_list(length=limit)
    return sorted(docs, key=lambda d: timestamp(d) or "", reverse=True)

def provenance(doc):
    doc = doc or {}
    return dict(available=bool(doc), data_origin=doc.get("data_origin", "unspecified"),
                dataset_id=doc.get("dataset_id"), validation_status=doc.get("validation_status", "not_clinically_validated"),
                limitations=["Prototype observations and model estimates are not a diagnosis.",
                             "Synthetic results demonstrate software behavior, not performance on Sri Lankan Grade 1 children.",
                             "Missing measurements are unavailable, not zero."])

def base(student_id, doc=None, period="Latest available record"):
    return dict(student_id=student_id, updated_at=stamp(datetime.now(timezone.utc)), reporting_period=period, **provenance(doc))

def mlbase(student_id, doc=None, model="unavailable", feature="unavailable"):
    doc = doc or {}
    return dict(**base(student_id, doc), model_version=doc.get("model_version", model),
                feature_version=doc.get("feature_version", feature), last_data_at=timestamp(doc))

def speech(doc):
    doc = doc or {}
    raw = doc.get("speech_data") or {}
    def field(*names):
        for source in (doc, raw):
            for name in names:
                if source.get(name) is not None:
                    return source[name]
        return None
    # A historical 1-WER value is not a recognition confidence estimate.
    confidence = field("stt_confidence") if field("stt_confidence_method") not in (None, "one_minus_wer") else None
    fusion = doc.get("fusion") or {}
    result = dict(pause_count=number(field("pause_count", "Pause_Count")),
                mean_pause_duration_ms=number(field("mean_pause_duration_ms", "Mean_Pause_Duration_ms")),
                pause_ratio=number(field("pause_ratio", "Pause_Ratio")), speech_duration_ms=number(field("speech_duration_ms", "Speech_Duration_ms")),
                expected_text=field("expected_text") or "", transcription=field("recognized_text", "transcription") or "",
                wer=number(field("word_error_rate", "wer")), stt_confidence=number(confidence),
                stt_confidence_method=field("stt_confidence_method"),
                acoustic_latency_ms=number(field("acoustic_latency_ms", "reading_initiation_latency_ms", "Acoustic_Latency_ms")),
                voice_onset_ms=number(field("voice_onset_ms", "Voice_Onset_ms")),
                peak_delta=number(field("syllabic_event_mismatch", "peak_count_delta", "Peak_Count_Delta")),
                silence_ratio=number(field("intra_word_silence_ratio", "internal_silence_ratio", "Intra_Word_Silence_Ratio")),
                jitter=number(field("local_jitter", "jitter", "Local_Jitter")),
                shimmer=number(field("local_shimmer", "shimmer", "Local_Shimmer")),
                grapheme_accuracy=number(field("grapheme_accuracy")),
                word_accuracy=number(field("word_accuracy")),
                reading_rate_wpm=number(field("reading_rate_wpm")),
                combined_confidence=number(field("combined_confidence")),
                reading_performance_score=number(field("reading_performance_score")),
                method_disagreement=bool(fusion.get("method_disagreement", False)),
                quality_issues=field("recording_quality_issues") or [],
                recording_quality=field("recording_quality") or "Unknown",
                measurement_status=field("measurement_status") or ("unverified" if doc else "unavailable"),
                record_start_delay_ms=number(field("record_start_delay_ms", "Record_Start_Delay_ms")),
                recording_quality_score=number(field("recording_quality_score")),
                pipeline_version=field("pipeline_version"),
                asr_model=field("asr_model"),
                disagreement_reasons=list(fusion.get("disagreement_reasons") or []))
    result["measured"] = speech_measured(doc, result)
    if not result["measured"]:
        # A recording that failed the quality check, or where nothing was
        # recognised, has no reading accuracy. The pipeline stores 0 / WER 1
        # for these; showing that as "0% read correctly" is wrong.
        for key in ("word_accuracy", "grapheme_accuracy", "wer", "reading_performance_score",
                    "reading_rate_wpm", "combined_confidence"):
            result[key] = None
    return result


def speech_measured(doc, values=None):
    """True when a recording produced a reading measurement."""
    if not doc:
        return False
    values = values if values is not None else {}
    status = doc.get("measurement_status")
    if status in USABLE_SPEECH_STATUSES:
        return True
    quality = values.get("recording_quality", doc.get("recording_quality"))
    if status is None:
        # Older rows without a status: trust them unless the quality gate failed.
        return quality != "retry_required"
    transcript = values.get("transcription", doc.get("recognized_text") or doc.get("transcription") or "")
    return status == "uncertain" and quality != "retry_required" and bool(str(transcript).strip())


def usable_speech(rows):
    """Latest recording that was clear enough to measure, or None."""
    return next((row for row in rows if row.get("measurement_status") in USABLE_SPEECH_STATUSES), None)

def pattern_profile(doc):
    profile = (doc or {}).get("learner_profile") or {}
    probs = {PATTERNS.get(k, k): number(v) for k, v in (profile.get("class_probabilities") or {}).items()}
    probs = {k:v for k,v in probs.items() if v is not None and 0 <= v <= 1}
    pattern = PATTERNS.get(profile.get("primary_pattern"), profile.get("primary_pattern", "Unavailable"))
    return profile, probs, pattern

def mastery_status(value):
    if value is None:
        return "Unavailable"
    labels = setting("mastery_labels", default={}) or {}
    higher, developing = labels.get("higher", .8), labels.get("developing", .5)
    return "Higher model estimate" if value >= higher else "Developing estimate" if value >= developing else "Lower model estimate"

async def research_evidence(db, student_id):
    docs = await records(db, "research_evaluations", student_id)
    if docs:
        doc = {k:v for k,v in docs[0].items() if k != "_id"}
        return {**base(student_id, doc, "Synthetic held-out evaluation"), **doc}
    return {**base(student_id, None), "components": [], "message": "No reproducible evaluation has been imported for this student. No baseline scores are invented."}


async def activity_performance(db, student_id, days=30, skill_id=None, limit=100):
    """Join C1 activity aggregates and C2 recordings on student/skill/activity.

    C1 activity IDs repeat across skills, so all grouping keys include skill_id.
    Missing C1/C2 values remain null/zero-count rather than being inferred.
    """
    from datetime import timedelta

    cutoff = datetime.now(timezone.utc) - timedelta(days=days) if days else None
    groups = {}
    raw_rows, _ = await window_sessions(db, student_id, days, skill_id, fallback=False)
    if raw_rows:
        # Pool the captured rounds per activity (same rules as c1_window_metrics).
        per_activity = {}
        for doc, events in raw_rows:
            stamp_value = timestamp(doc)
            for event in events:
                sid = _skill_digits(event.get("skill_id"))
                aid = str(event.get("activity_id") or "unknown")
                bucket = per_activity.setdefault((sid, aid), {"events": [], "sessions": set(), "last": None,
                                                              "name": event.get("activity_name"),
                                                              "origin": doc.get("data_origin", "unspecified")})
                bucket["events"].append(event)
                bucket["sessions"].add(doc.get("session_id"))
                bucket["last"] = max(filter(None, [bucket["last"], stamp_value]), default=None)
        for (sid, aid), bucket in per_activity.items():
            pooled = pooled_round_metrics(bucket["events"])
            groups[(sid, aid)] = {
                "skill_id": sid, "activity_id": aid, "sessions": len(bucket["sessions"]),
                "trials": pooled["completed_rounds"], "abandoned_trials": pooled["abandoned_rounds"],
                "activity_name": bucket["name"] or aid,
                "first_correct": pooled["first_try_correct"],
                "retry_trials": round((pooled["retry_rate"] or 0) * pooled["completed_rounds"]),
                "latencies": [], "median_latency": pooled["median_response_latency_ms"],
                "data_origin": bucket["origin"], "last_activity_at": bucket["last"],
            }
    summaries = [] if raw_rows else await records(db, "session_summaries", student_id, 500)
    for summary in summaries:
        stamp_value = timestamp(summary)
        if cutoff and stamp_value:
            try:
                if datetime.fromisoformat(stamp_value.replace("Z", "+00:00")) < cutoff:
                    continue
            except ValueError:
                pass
        breakdown = summary.get("activity_breakdown_by_skill") or {}
        # Backward-compatible fallback for old rows, with an explicit unknown skill.
        if not breakdown:
            breakdown = {
                f"unknown::{activity}": {"skill_id": "unknown", "activity_id": activity, **metrics}
                for activity, metrics in (summary.get("activity_breakdown") or {}).items()
            }
        for key, metrics in breakdown.items():
            sid = _skill_digits(metrics.get("skill_id") or key.split("::", 1)[0])
            aid = str(metrics.get("activity_id") or key.split("::", 1)[-1] or "unknown")
            if skill_id and sid != _skill_digits(skill_id):
                continue
            group = groups.setdefault((sid, aid), {
                "skill_id": sid, "activity_id": aid, "sessions": 0, "trials": 0, "abandoned_trials": 0,
                "activity_name": metrics.get("activity_name") or aid,
                "first_correct": 0, "retry_trials": 0, "latencies": [],
                "data_origin": summary.get("data_origin", "unspecified"),
                "last_activity_at": stamp_value,
            })
            trials = int(metrics.get("trials") or 0)
            accuracy = number(metrics.get("accuracy"))
            group["sessions"] += 1
            group["trials"] += trials
            group["abandoned_trials"] += int(metrics.get("abandoned_trials") or 0)
            if accuracy is not None:
                group["first_correct"] += round(accuracy * trials)
            retry_rate = number(metrics.get("retry_rate"))
            if retry_rate is not None:
                group["retry_trials"] += round(retry_rate * trials)
            latency = number(metrics.get("median_response_latency_ms"))
            if latency is not None:
                group["latencies"].append(latency)
            group["last_activity_at"] = group["last_activity_at"] or stamp_value

    speech_rows = await records(db, "speech_features", student_id, 500)
    for row in speech_rows:
        sid, aid = _skill_digits(row.get("skill_id")), str(row.get("activity_id") or "unknown")
        if skill_id and sid != _skill_digits(skill_id):
            continue
        stamp_value = timestamp(row)
        if cutoff and stamp_value:
            try:
                if datetime.fromisoformat(stamp_value.replace("Z", "+00:00")) < cutoff:
                    continue
            except ValueError:
                pass
        group = groups.setdefault((sid, aid), {
            "skill_id": sid, "activity_id": aid, "sessions": 0, "trials": 0, "abandoned_trials": 0,
            "activity_name": row.get("activity_name") or aid,
            "first_correct": 0, "retry_trials": 0, "latencies": [],
            "data_origin": row.get("data_origin", "unspecified"), "last_activity_at": stamp_value,
        })
        voice = group.setdefault("voice", {"recordings": 0, "usable_recordings": 0, "quality_counts": {}})
        voice["recordings"] += 1
        quality = str(speech(row).get("recording_quality") or "unavailable")
        voice["quality_counts"][quality] = voice["quality_counts"].get(quality, 0) + 1
        if row.get("measurement_status") in USABLE_SPEECH_STATUSES:
            voice["usable_recordings"] += 1
        if "latest_voice" not in group or (stamp_value or "") >= (group.get("latest_voice_at") or ""):
            voice_data = speech(row)
            group["latest_voice"] = {
                "recording_quality": voice_data.get("recording_quality"),
                "measurement_status": voice_data.get("measurement_status"),
                "word_accuracy": voice_data.get("word_accuracy"),
                "grapheme_accuracy": voice_data.get("grapheme_accuracy"),
                "reading_rate_wpm": voice_data.get("reading_rate_wpm"),
                "pause_ratio": voice_data.get("pause_ratio"),
            }
            group["latest_voice_at"] = stamp_value

    output = []
    for group in groups.values():
        trials = group.pop("trials")
        group["trials"] = trials
        correct = group.pop("first_correct")
        retries = group.pop("retry_trials")
        latencies = group.pop("latencies")
        group["first_attempt_accuracy"] = correct / trials if trials else None
        group["retry_rate"] = retries / trials if trials else None
        pooled_latency = group.pop("median_latency", None)
        group["median_response_latency_ms"] = (pooled_latency if pooled_latency is not None
                                               else number(statistics.median(latencies)) if latencies else None)
        group.setdefault("voice", {"recordings": 0, "usable_recordings": 0, "quality_counts": {}})
        group.update(activity_label(group.get("skill_id"), group.get("activity_id"), group.get("activity_name")))
        group["data_available"] = bool(group["sessions"] or group["voice"]["recordings"])
        output.append(group)
    output.sort(key=lambda row: (row.get("skill_id", ""), row.get("activity_id", "")))
    return {"student_id": student_id, "reporting_days": days, "skill_id": skill_id, "activities": output[:limit]}


# ---------------------------------------------------------------------------
# Shared presentation helpers (one source for names, windows and thresholds)
# ---------------------------------------------------------------------------
import json
import os
import re
from datetime import timedelta

_SETTINGS_PATH = os.path.join(os.path.dirname(__file__), "..", "dashboard_settings.json")
try:
    with open(_SETTINGS_PATH, encoding="utf-8") as _settings_file:
        SETTINGS = json.load(_settings_file)
except (OSError, ValueError):  # pragma: no cover - file ships with the service
    SETTINGS = {}


def setting(*path, default=None):
    node = SETTINGS
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return default
        node = node[key]
    return node


ALL_ACTIVITY_NAMES = {**ACTIVITY_NAMES, **READING_ACTIVITY_NAMES}


def activity_key(skill_id=None, activity_id=None, activity_name=None):
    """Resolve any stored activity identifier to a curriculum key such as "1.3"."""
    for candidate in (activity_id, activity_name):
        text = str(candidate or "").strip()
        if not text:
            continue
        if text in ALL_ACTIVITY_NAMES:
            return text
        if text in TEMPLATE_TO_ACTIVITY:
            return TEMPLATE_TO_ACTIVITY[text]
        skill_match = re.search(r"(\d+)", str(skill_id or ""))
        act_match = re.fullmatch(r"act_?(\d+)", text, re.IGNORECASE)
        if skill_match and act_match:
            key = f"{int(skill_match.group(1))}.{int(act_match.group(1))}"
            if key in ALL_ACTIVITY_NAMES:
                return key
        item_match = re.match(r"S(\d+)A(\d+)", text, re.IGNORECASE)
        if item_match:
            key = f"{int(item_match.group(1))}.{int(item_match.group(2))}"
            if key in ALL_ACTIVITY_NAMES:
                return key
    return None


def activity_label(skill_id=None, activity_id=None, activity_name=None):
    key = activity_key(skill_id, activity_id, activity_name)
    skill_number = key.split(".")[0] if key else re.sub(r"\D", "", str(skill_id or "")) or None
    return {
        "activity_key": key,
        "activity_name_si": ALL_ACTIVITY_NAMES.get(key) if key else None,
        "activity_name_en": ACTIVITY_NAMES_EN.get(key) if key else None,
        "skill_name_si": {**SKILL_NAMES, **READING_SKILL_NAMES}.get(skill_number) if skill_number else None,
        "skill_name_en": SKILL_NAMES_EN.get(skill_number) if skill_number else None,
        "activity_display": (
            ACTIVITY_NAMES_EN.get(key) if key else str(activity_name or activity_id or "Activity")
        ),
    }


def parse_time(value):
    text = stamp(value)
    if not text:
        return None
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


def window_or_latest(rows, days, fallback=10):
    """Rows in the window; if none, the latest ``fallback`` rows (labelled)."""
    kept = in_window(rows, days)
    if kept or not rows:
        return kept, f"Last {days} days"
    return list(rows[:fallback]), f"Latest {min(fallback, len(rows))} sessions (none in the last {days} days)"


def in_window(rows, days):
    """Rows whose timestamp falls in the last ``days`` days (undated rows kept)."""
    if not days:
        return list(rows)
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    kept = []
    for row in rows:
        when = parse_time(row.get("completed_at") or row.get("created_at") or row.get("timestamp") or row.get("updated_at"))
        if when is None or when >= cutoff:
            kept.append(row)
    return kept


def session_point(row, index, value):
    """Chart point labelled by session number and date instead of a UUID."""
    when = parse_time(row.get("completed_at") or row.get("created_at") or row.get("timestamp"))
    date = when.strftime("%d %b") if when else None
    return {
        "session": row.get("session_id"),
        "index": index,
        "date": stamp(when) if when else None,
        "label": f"S{index}" + (f" · {date}" if date else ""),
        "value": value,
    }


def completed_trials(row):
    """Completed (non-abandoned) rounds in a stored session summary.

    Returns None when an old summary does not record trial counts.
    """
    if row.get("valid_trials") is not None:
        return int(row.get("valid_trials") or 0)
    if row.get("total_trials") is None:
        return None
    total = int(row.get("total_trials") or 0)
    abandoned = number((row.get("overall") or {}).get("abandonment_rate")) or 0.0
    return max(0, total - round(abandoned * total))


def has_completed_rounds(row):
    """False only when a summary is known to contain no completed round."""
    return completed_trials(row) != 0


def weighted_overall(summaries, field):
    """Mean of an ``overall`` metric weighted by completed rounds.

    Sessions with no completed round are skipped: older summaries stored 0
    for their accuracy/attempts, which is not a measurement.
    """
    total, weight = 0.0, 0
    for row in summaries:
        value = number((row.get("overall") or {}).get(field))
        trials = completed_trials(row)
        trials = 1 if trials is None else trials
        if value is not None and trials > 0:
            total += value * trials
            weight += trials
    return total / weight if weight else None


def kc_breakdown(summaries):
    """Accuracy and trial counts per knowledge component over the window."""
    totals = {}
    for row in summaries:
        for kc, values in (row.get("knowledge_components") or {}).items():
            if not isinstance(values, dict) or not kc or kc in {"KC_UNKNOWN", "None"}:
                continue
            trials = int(values.get("trials") or 0)
            accuracy = number(values.get("accuracy"))
            if not trials or accuracy is None:
                continue
            bucket = totals.setdefault(kc, {"trials": 0, "correct": 0.0})
            bucket["trials"] += trials
            bucket["correct"] += accuracy * trials
    rows = [
        {"kc_id": kc, "name": KC_NAMES.get(kc, kc.removeprefix("KC_").replace("_", " ").title()),
         "trials": v["trials"], "accuracy": v["correct"] / v["trials"]}
        for kc, v in totals.items()
    ]
    rows.sort(key=lambda r: (-r["trials"], r["name"]))
    return rows


ERROR_LABELS = {
    "visual_confusion": "Look-alike letter confusion",
    "visual_task_error": "Picture-task error",
    "phonological_confusion": "Sound / language error",
    "sequence_error": "Order / sequence error",
    "unknown_error": "Type not recorded",
}


def error_breakdown(summaries):
    """Share of first-attempt errors by reported type, with counts."""
    counts = {key: 0.0 for key in ERROR_LABELS}
    total = 0
    for row in summaries:
        profile = row.get("error_profile") or {}
        overall = row.get("overall") or {}
        errors = profile.get("error_count")
        if errors is None:
            trials = int(row.get("total_trials") or 0)
            rate = number(overall.get("error_rate"))
            errors = round(rate * trials) if rate is not None else 0
        errors = int(errors or 0)
        if not errors:
            continue
        total += errors
        for key in counts:
            share = number(profile.get(f"{key}_rate"))
            if share is not None:
                counts[key] += share * errors
    return {
        "total_errors": total,
        "categories": [
            {"key": key, "label": label, "count": round(counts[key]),
             "share": (counts[key] / total) if total else None}
            for key, label in ERROR_LABELS.items()
        ],
    }


def fatigue_view(row):
    """Return a bounded fatigue score and state; legacy signed values are clipped."""
    components = row.get("fatigue_components") or {}
    state = row.get("fatigue_state") or components.get("state")
    score = number(row.get("behavioral_fatigue_proxy"))
    if score is not None:
        score = max(0.0, min(1.0, score))
        if not state:
            low = 0.30; moderate = 0.60; high = 0.80
            state = "LOW" if score <= low else "MODERATE" if score <= moderate else "HIGH" if score <= high else "VERY_HIGH"
    return {"score": score, "state": state or "UNAVAILABLE",
            "latency_drift": number(components.get("latency_drift")),
            "error_drift": number(components.get("error_drift")),
            "hesitation_drift": number(components.get("hesitation_drift"))}


SHAP_FEATURE_NAMES = {
    "acoustic_latency_ms": ("Time to start reading aloud", "ms"),
    "peak_count_delta": ("Spoken-beat vs syllable difference", ""),
    "intra_word_silence_ratio": ("Silence within spoken words", "%"),
    "local_jitter": ("Voice steadiness (exploratory)", ""),
    "local_shimmer": ("Loudness steadiness (exploratory)", ""),
    "time_to_first_touch_ms": ("Time to first touch", "ms"),
    "orthographic_confusion_index": ("Look-alike letter choices", "%"),
    "path_efficiency_ratio": ("Directness of finger paths", "%"),
    "dimensionless_jerk": ("Finger-movement smoothness (jerk)", ""),
    "dwell_time_ms": ("Touch hold time", "ms"),
    "age": ("Age", "years"),
    "age_years": ("Age", "years"),
    "c1_first_try_accuracy": ("Activities correct on first try", "%"),
    "c1_visual_task_index": ("Visual task speed index", ""),
    "c1_sound_task_index": ("Sound task speed index", ""),
    "c1_long_pauses_per_round": ("Long pauses per activity round", ""),
    "time_of_day_hour": ("Time of day", "h"),
}


def _format_value(value, unit):
    if value is None:
        return "not measured"
    if unit == "%":
        return f"{round(value * 100)}%"
    if unit == "ms":
        return f"{round(value)} ms"
    if unit in {"years", "h"}:
        return f"{round(value)} {unit}"
    return f"{value:.2f}"


def shap_phrase(feature, contribution, value=None):
    """Plain-language SHAP line. SHAP is a signed contribution, not a cause."""
    name, unit = SHAP_FEATURE_NAMES.get(feature, (feature.replace("_", " ").capitalize(), ""))
    verb = "raised" if contribution > 0 else "lowered"
    return f"{name} ({_format_value(value, unit)}) {verb} the model estimate."




async def learner_coverage(db, student_id, student_doc=None, days=None):
    """Which evidence sources exist for a learner (data-completeness view)."""
    days = days if isinstance(days, int) else setting("default_window_days", default=30)
    summaries = await records(db, "session_summaries", student_id, setting("limits", "records", default=200))
    speech_rows = await records(db, "speech_features", student_id, setting("limits", "records", default=200))
    window_summaries = in_window(summaries, days)
    window_speech = in_window(speech_rows, days)
    usable = [r for r in window_speech if r.get("measurement_status") in USABLE_SPEECH_STATUSES]
    profiles = await records(db, "learner_profiles", student_id, 5)
    profile = next((p for p in profiles if str(p.get("feature_version") or "").startswith("c3-learner-window")),
                   profiles[0] if profiles else {})
    feedback = await records(db, "professional_feedback", student_id, 1)
    student_doc = student_doc or {}
    questionnaire = student_doc.get("comprehensive_assessment_results") or {}
    sections_done = len([v for v in questionnaire.values() if isinstance(v, list) and v])
    sections_total = setting("alerts", "questionnaire_sections_total", default=4)
    last_times = [parse_time(timestamp(r)) for r in summaries[:1] + speech_rows[:1]]
    last_times = [t for t in last_times if t]
    last_active = max(last_times) if last_times else None
    return {
        "window_days": days,
        "activity_sessions": len(window_summaries),
        "recordings": len(window_speech),
        "usable_recordings": len(usable),
        "usable_recording_rate": (len(usable) / len(window_speech)) if window_speech else None,
        "questionnaire_sections_done": sections_done,
        "questionnaire_sections_total": sections_total,
        "combined_profile_status": profile.get("pipeline_status") or ("not_run" if not profile else "available"),
        "combined_profile_ready": bool(profile.get("model_applied")),
        "professional_review": bool(feedback),
        "last_active_at": stamp(last_active) if last_active else None,
        "_window_summaries": window_summaries,
    }


def learner_alerts(coverage):
    """Rule-based remote-monitoring prompts (descriptive, not clinical)."""
    rules = setting("alerts", default={}) or {}
    alerts = []
    last = parse_time(coverage.get("last_active_at"))
    inactive_days = rules.get("inactive_days", 7)
    if last is None:
        alerts.append({"code": "no_activity", "severity": "info",
                       "message": "No activities recorded yet."})
    elif (datetime.now(timezone.utc) - last).days >= inactive_days:
        alerts.append({"code": "inactive", "severity": "watch",
                       "message": f"No activity in the last {(datetime.now(timezone.utc) - last).days} days."})
    rate = coverage.get("usable_recording_rate")
    if (coverage.get("recordings", 0) >= rules.get("min_recordings_for_usable_rate", 3)
            and rate is not None and rate < rules.get("low_usable_recording_rate", 0.5)):
        alerts.append({"code": "low_usable_recordings", "severity": "watch",
                       "message": f"Only {coverage['usable_recordings']} of {coverage['recordings']} reading recordings were clear enough to measure."})
    high_states = set(rules.get("high_fatigue_states", ["HIGH", "VERY_HIGH"]))
    tired = sum(1 for row in coverage.get("_window_summaries", []) if fatigue_view(row)["state"] in high_states)
    if tired >= rules.get("high_fatigue_sessions", 2):
        alerts.append({"code": "repeated_high_fatigue", "severity": "watch",
                       "message": f"Responses slowed or errors rose late in {tired} recent sessions."})
    if coverage.get("questionnaire_sections_done", 0) < coverage.get("questionnaire_sections_total", 4):
        alerts.append({"code": "questionnaire_incomplete", "severity": "info",
                       "message": f"Parent questionnaire {coverage.get('questionnaire_sections_done', 0)} of {coverage.get('questionnaire_sections_total', 4)} sections done."})
    return alerts


def public_coverage(coverage):
    return {k: v for k, v in coverage.items() if not k.startswith("_")}


# ---------------------------------------------------------------------------
# One pooled C1 view shared by every dashboard (therapist, parent, PDF)
# ---------------------------------------------------------------------------

def _median(values):
    values = sorted(v for v in values if v is not None)
    if not values:
        return None
    mid = len(values) // 2
    return float(values[mid]) if len(values) % 2 else (values[mid - 1] + values[mid]) / 2


def _first_try(event):
    value = event.get("first_attempt_correct")
    return value if isinstance(value, bool) else bool(event.get("is_correct"))


def _dedupe_events(events):
    """Drop repeated copies of the same round (offline replays reuse event_id)."""
    seen, kept = set(), []
    for event in reversed(events or []):
        if not isinstance(event, dict):
            continue
        key = event.get("event_id")
        if key and key in seen:
            continue
        if key:
            seen.add(key)
        kept.append(event)
    return list(reversed(kept))


def pooled_round_metrics(events):
    """Metrics over completed rounds, pooled (every round counts once).

    Abandoned rounds are counted separately and never enter a rate, so a
    session the child left early cannot pull accuracy or attempts down.
    """
    done = [e for e in events if not e.get("is_abandoned")]
    left = len(events) - len(done)
    n = len(done)

    def share(predicate):
        return (sum(1 for e in done if predicate(e)) / n) if n else None

    attempts = [max(1, int(number(e.get("attempt_count")) or 1)) for e in done]
    return {
        "completed_rounds": n,
        "abandoned_rounds": left,
        "first_try_correct": sum(1 for e in done if _first_try(e)),
        "first_attempt_accuracy": share(_first_try),
        "retry_rate": share(lambda e: (number(e.get("attempt_count")) or 1) > 1),
        "mean_attempts_per_round": (sum(attempts) / n) if n else None,
        "eventual_completion_rate": share(lambda e: bool(e.get("final_correct", e.get("is_correct")))),
        "correction_rate": share(lambda e: (number(e.get("correction_count")) or 0) > 0),
        "support_rate": share(lambda e: (number(e.get("scaffold_level_used")) or 0) > 0
                              or (number(e.get("hint_count")) or 0) > 0),
        # Time to first answer (first touch for app versions before Oct 2026).
        "median_response_latency_ms": _median(
            [number(e.get("time_to_first_response_ms")) or number(e.get("first_touch_latency_ms")) for e in done
             if (number(e.get("time_to_first_response_ms")) or number(e.get("first_touch_latency_ms")) or 0) > 0]),
        "stray_drops_per_drag_round": (
            sum(number(e.get("stray_drop_count")) or 0 for e in drags) / len(drags) if (drags := [
                e for e in done if e.get("response_modality") == "drag"]) else None),
        "median_time_to_correct_ms": _median(
            [number(e.get("time_to_correct_ms")) for e in done
             if (number(e.get("time_to_correct_ms")) or 0) > 0]),
        "median_round_time_ms": _median(
            [number(e.get("total_round_latency_ms")) for e in done
             if (number(e.get("total_round_latency_ms")) or 0) > 0]),
    }


def _skill_digits(value):
    """'skill_1', '1' and 1 all mean Skill 1."""
    digits = re.sub(r"\D", "", str(value or ""))
    return digits or "unknown"


def _skill_matches(event, skill_id):
    return _skill_digits(event.get("skill_id")) == _skill_digits(skill_id)


async def window_sessions(db, student_id, days, skill_id=None, fallback=True):
    """Stored telemetry sessions in the window, with de-duplicated rounds."""
    limit = setting("limits", "records", default=200)
    # Touch paths are large and not needed for these numbers.
    projection = {"events.touch_path": 0, "events.touch_stream": 0, "events.attempt_history": 0,
                  "events.scaffold_applications": 0, "device_metrics": 0}
    docs = await db.telemetry_sessions.find({"student_id": student_id}, projection).sort("_id", -1).limit(limit).to_list(length=limit)
    docs = sorted(docs, key=lambda d: timestamp(d) or "", reverse=True)
    if fallback:
        sessions, period = window_or_latest(docs, days)
    else:
        sessions, period = in_window(docs, days), f"Last {days} days"
    rows = []
    for doc in sessions:
        events = _dedupe_events(doc.get("events"))
        if skill_id:
            events = [e for e in events if _skill_matches(e, skill_id)]
            if not events:
                continue
        rows.append((doc, events))
    return rows, period


async def c1_window_metrics(db, student_id, days=None, skill_id=None):
    """The single source for C1 numbers on every dashboard.

    Reads the stored telemetry sessions (the raw rounds the app captured),
    keeps those in the window, removes duplicate rounds and pools completed
    rounds. Falls back to the latest sessions (labelled) when none are in the
    window. ``latest_session`` is reported separately and labelled as such.
    """
    days = days if isinstance(days, int) else setting("default_window_days", default=30)
    rows, period = await window_sessions(db, student_id, days, skill_id)
    all_events = [e for _, events in rows for e in events]
    pooled = pooled_round_metrics(all_events)
    with_rounds = [(doc, ev) for doc, ev in rows if any(not e.get("is_abandoned") for e in ev)]
    latest = None
    if with_rounds:
        doc, events = with_rounds[0]
        latest = {"session_id": doc.get("session_id"), "completed_at": timestamp(doc),
                  **pooled_round_metrics(events)}
    seconds = [number(doc.get("session_duration_seconds")) for doc, _ in rows]
    seconds = [s for s in seconds if s is not None]
    activities = {}
    for e in all_events:
        if e.get("is_abandoned"):
            continue
        key = activity_key(e.get("skill_id"), e.get("activity_id"), e.get("activity_name"))
        if key:
            activities[key] = activities.get(key, 0) + 1
    return {
        "window_days": days,
        "reporting_period": period.replace("sessions", "activity sessions"),
        "sessions_started": len(rows),
        "sessions_with_completed_rounds": len(with_rounds),
        "sessions_ended_early": len(rows) - len(with_rounds),
        "practice_minutes": round(sum(seconds) / 60, 1) if seconds else None,
        "activities_practised": activities,
        **pooled,
        "latest_session": latest,
        "data_source": "telemetry_sessions (completed rounds, de-duplicated)",
    }


async def practised_kcs(db, student_id):
    """Knowledge components the learner has actually answered (completed rounds)."""
    kcs = await db.telemetry_events.distinct(
        "knowledge_component_id",
        {"student_id": student_id, "is_abandoned": {"$ne": True}},
    )
    return {kc for kc in kcs if kc and kc not in {"KC_UNKNOWN", "None"}}


async def practised_mastery(db, student_id, state_doc=None):
    """Average C4 mastery estimate over practised areas only.

    The knowledge state holds a starting value for every area, including areas
    the child has never seen. Averaging those priors made "average mastery"
    look like a measured result.
    """
    if state_doc is None:
        rows = await records(db, "knowledge_states", student_id, 1)
        state_doc = rows[0] if rows else {}
    state = (state_doc or {}).get("knowledge_state") or {}
    practised = await practised_kcs(db, student_id)
    values = {kc: number(v) for kc, v in state.items() if kc in practised and number(v) is not None}
    return {
        "average": (sum(values.values()) / len(values)) if values else None,
        "practised_areas": len(values),
        "total_areas": len([v for v in state.values() if number(v) is not None]),
        "by_area": values,
    }
