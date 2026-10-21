"""
create_simulated_students.py
============================
Generates 2 new students owned by parent@sipsara.com and linked to therapist@sipsara.com:
  1. Dinuka Silva (Average Performer - Typical Learning Pattern)
  2. Nuwan Perera (Struggling Learner - Phonological / Combined Learning Pattern)

Simulates 100% curriculum coverage (Skills 1-4 touch activities, Skills 5-6 reading activities,
vowel & consonant letter practice, and comprehensive parent questionnaire).
Populates all relevant MongoDB Atlas collections so Parent, Student, and Therapist
dashboards display fully populated, rich visualizations.
"""

import sys
import os
import uuid
import random
from datetime import datetime, timedelta, timezone
from bson import ObjectId
from pymongo import MongoClient
from dotenv import dotenv_values

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# 1. Database Connection
env_path = os.path.join("app", "backend", "api", ".env")
env = dotenv_values(env_path)
client = MongoClient(env.get("MONGODB_URL"))
db = client[env.get("MONGODB_DB_NAME", "r26_se_031")]

# Identifiers
PARENT_ID = ObjectId("6ad5a03b00c4cf9c13dbb644")
THERAPIST_ID = ObjectId("6ad5a03c00c4cf9c13dbb645")
CLINIC_CODE = "SIP123"

NOW = datetime.now(timezone.utc)

# Knowledge Component names & mapping
KC_MAP = {
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
    "5.1": "KC_READING_COMPREHENSION",
    "5.2": "KC_READING_COMPREHENSION",
    "5.3": "KC_READING_COMPREHENSION",
    "5.4": "KC_READING_COMPREHENSION",
    "6.1": "KC_ORAL_READING_FLUENCY",
    "6.2": "KC_ORAL_READING_FLUENCY",
}

ALL_KCS = [
    "KC_VISUAL_IDENTIFICATION", "KC_VISUAL_MATCHING", "KC_VISUAL_CATEGORIZATION",
    "KC_VISUAL_PATTERN", "KC_VISUAL_MEMORY", "KC_LETTER_IDENTIFICATION",
    "KC_LETTER_MATCHING", "KC_PHONEME_LETTER_MAPPING", "KC_LETTER_DECODING",
    "KC_LETTER_MEMORY", "KC_WORD_RECOGNITION", "KC_WORD_FORMATION",
    "KC_AUDITORY_WORD_RECOGNITION", "KC_WORD_COMPLETION", "KC_WORD_SEQUENCING",
    "KC_SENTENCE_COMPREHENSION", "KC_SENTENCE_COMPLETION",
    "KC_AUDITORY_SENTENCE_RECOGNITION", "KC_SENTENCE_SEQUENCING",
    "KC_READING_COMPREHENSION", "KC_ORAL_READING_FLUENCY"
]

ACTIVITY_NAMES_SI = {
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
    "5.1": "කියවා කරන්න",
    "5.2": "කවුද?",
    "5.3": "මොනවාද?",
    "5.4": "කොහෙද?",
    "6.1": "පෙළපොතෙන් කියවමු - 1",
    "6.2": "පෙළපොතෙන් කියවමු - 2",
}

VOWELS = ["අ", "ආ", "ඇ", "ඈ", "ඉ", "ඊ", "උ", "ඌ", "එ", "ඒ", "ඔ", "ඕ"]
CONSONANTS = ["ක", "ග", "ච", "ජ", "ට", "ඩ", "ත", "ද", "න", "ප", "බ", "ම", "ය", "ර", "ල", "ව", "ස", "හ"]

# 2. Cleanup old runs
for sname in ["Dinuka Silva", "Nuwan Perera"]:
    fname, lname = sname.split()
    for st in db.students.find({"first_name": fname, "last_name": lname, "parent_id": PARENT_ID}):
        sid = str(st["_id"])
        print(f"Purging existing data for {sname} ({sid})...")
        for col in [
            "students", "therapist_connections", "telemetry_sessions", "telemetry_events",
            "session_summaries", "behavioral_features", "kinematic_features",
            "c1_learner_estimates", "speech_features", "learner_profiles",
            "knowledge_states", "adaptive_decisions", "policy_decisions"
        ]:
            db[col].delete_many({"student_id": sid})
        db.students.delete_many({"_id": st["_id"]})

# Preload item bank items by activity
item_cache = {}
for act in list(ACTIVITY_NAMES_SI.keys()):
    items = list(db.item_bank.find({"activity_id": act}).limit(5))
    item_cache[act] = items

print("Item bank loaded for all activities.")

def create_student_dataset(persona):
    is_avg = persona["is_average"]
    first_name = persona["first_name"]
    last_name = persona["last_name"]
    student_id = ObjectId()
    student_id_str = str(student_id)
    
    print(f"\n==========================================")
    print(f"Creating Student: {first_name} {last_name} (ID: {student_id_str})")
    print(f"Persona: {'Average Performer' if is_avg else 'Struggling Learner'}")
    print(f"==========================================")

    # 1. Student Document
    completed_activities = [
        "skill_1_act_1", "skill_1_act_2", "skill_1_act_3", "skill_1_act_4", "skill_1_act_5",
        "skill_2_act_1", "skill_2_act_2", "skill_2_act_3", "skill_2_act_4", "skill_2_act_5",
        "skill_3_act_1", "skill_3_act_2", "skill_3_act_3", "skill_3_act_4", "skill_3_act_5",
        "skill_4_act_1", "skill_4_act_2", "skill_4_act_3", "skill_4_act_4",
        "skill_5_act_1", "skill_5_act_2", "skill_5_act_3", "skill_5_act_4",
        "skill_6_act_1", "skill_6_act_2",
        "skill_sinhala_vowels_act_1", "skill_sinhala_consonants_act_1"
    ]
    
    activity_scores = {}
    for act in completed_activities:
        if is_avg:
            activity_scores[act] = random.choice([75, 80, 80, 85, 80, 75, 85])
        else:
            activity_scores[act] = random.choice([45, 50, 50, 55, 45, 60, 50])

    # Comprehensive Assessment Questionnaire (4 categories, full completion)
    basic_q = [
        "Does your child have difficulty reading from left to right?",
        "Does your child feel tired quickly after starting to read?",
        "Is your child's attention often diverted to other things when reading?",
        "Does your child often make mistakes when reading?",
        "Is it difficult for your child to maintain focus on one task for a long time?",
        "Is it difficult for your child to remember people's names?",
        "Is it difficult for your child to pronounce words correctly when speaking?",
        "Does the child forget how to write familiar short words even after being taught?",
        "Is it difficult for the child to write newly learned words correctly?",
        "Is it difficult for your child to read previously unseen words?",
        "Even if they know the meaning of a word, does your child face difficulty when writing it?",
        "When reading continuously, does your child have to stop at some words and try again?",
        "When reading, does it seem like your child's eyes are not working together?",
        "Has the child told you at least once that words move, blur, or it is difficult to focus when reading?"
    ]
    reading_q = [
        "Has your child had difficulty learning the relationship between letters and sounds (Phonics) since childhood?",
        "Does your child frequently make mistakes when reading aloud?",
        "Does your child have difficulty understanding written text without rereading it repeatedly?",
        "Do you feel that your child's reading speed is slower than other children of the same age?",
        "Does your child skip words or read them incorrectly when reading?",
        "Does your child instantly forget the place they were currently reading?",
        "Does your child have difficulty scanning a document to quickly find necessary information?",
        "Have you felt that your child's attention is quickly drawn elsewhere when reading?",
        "Has your child told you that words move, mix together, or look different when reading?",
        "Has your child told you, or have you noticed, that their eyes feel discomfort when looking at a white paper or whiteboard?"
    ]
    writing_q = [
        "Does the child show difficulty in spelling words correctly when writing?",
        "Does the child mix up similar words or write them confusingly?",
        "Does the child show unnecessary pressure when writing or skip words?",
        "Do you notice that the child's handwriting is unclear or their writing speed is slow?",
        "Have you felt that their writing ability is lower compared to their speaking ability?",
        "Even if they express their thoughts well while speaking, does it seem they face difficulty expressing the same thoughts when writing?"
    ]
    other_q = [
        "Was there a delay in speech or language development during childhood?",
        "Did they have middle ear infections (Glue Ear / Otitis Media) during childhood?",
        "Did they have immune system-related conditions like asthma or eczema?",
        "Even though they speak well, is it difficult for your child to express some ideas in an organized manner?",
        "Is there a delay in recalling the right word to speak, or do they pronounce words incorrectly?",
        "When asked a question, do they take more time than usual to understand and answer?"
    ]

    def make_responses(questions, yes_indices):
        return [
            {"question_id": f"q_{i+1}", "question": q, "answer": (i in yes_indices)}
            for i, q in enumerate(questions)
        ]

    if is_avg:
        comp_assessment = {
            "basic": make_responses(basic_q, [1, 4]),               # 2 observations reported
            "reading": make_responses(reading_q, [3]),              # 1 observation reported
            "writing": make_responses(writing_q, [0]),              # 1 observation reported
            "other": make_responses(other_q, [])                    # 0 observations reported
        }
        legacy_assessment = [False] * 14
        legacy_assessment[1] = True
        legacy_assessment[4] = True
    else:
        comp_assessment = {
            "basic": make_responses(basic_q, [0, 1, 2, 3, 4, 7, 8, 11]),    # 8 observations
            "reading": make_responses(reading_q, [0, 1, 2, 3, 4, 7]),       # 6 observations
            "writing": make_responses(writing_q, [0, 1, 2, 3]),             # 4 observations
            "other": make_responses(other_q, [0, 5])                        # 2 observations
        }
        legacy_assessment = [i in [0, 1, 2, 3, 4, 7, 8, 11] for i in range(14)]

    student_doc = {
        "_id": student_id,
        "first_name": first_name,
        "last_name": last_name,
        "grade": "Grade 1",
        "daily_limit": "No Limit",
        "avatar_url": persona["avatar_url"],
        "parent_id": PARENT_ID,
        "therapist_id": THERAPIST_ID,
        "clinic_code": CLINIC_CODE,
        "age": 6,
        "age_months": persona["age_months"],
        "birth_year": persona["birth_year"],
        "birth_month": persona["birth_month"],
        "gender": persona["gender"],
        "assessment_completed": True,
        "assessment_results": legacy_assessment,
        "comprehensive_assessment_results": comp_assessment,
        "completed_activities": completed_activities,
        "activity_scores": activity_scores,
        "consent_given": True,
        "consent_parent_name": "Saman Silva" if is_avg else "Nuwan Perera Snr",
        "consent_date": (NOW - timedelta(days=20)).isoformat(),
        "created_at": NOW - timedelta(days=20),
        "updated_at": NOW - timedelta(hours=2),
        "username": f"{first_name.lower()}_{last_name[0].lower()}",
        "starter_profile_required": False
    }
    db.students.insert_one(student_doc)

    # 2. Therapist Connection
    db.therapist_connections.insert_one({
        "student_id": student_id_str,
        "therapist_id": str(THERAPIST_ID),
        "parent_id": str(PARENT_ID),
        "status": "active",
        "connected_at": NOW - timedelta(days=19)
    })

    # 3. Schedule 7 Sessions over the past 14 days
    session_defs = [
        {"day_offset": 13, "skill": "1", "acts": ["1.1", "1.2", "1.3", "1.4", "1.5"], "name": "Skill 1 - Visual Matching"},
        {"day_offset": 11, "skill": "2", "acts": ["2.1", "2.2", "2.3", "2.4", "2.5"], "name": "Skill 2 - Letter Identity"},
        {"day_offset": 9,  "skill": "3", "acts": ["3.1", "3.2", "3.3", "3.4", "3.5"], "name": "Skill 3 - Word Building"},
        {"day_offset": 7,  "skill": "4", "acts": ["4.1", "4.2", "4.3", "4.4"],        "name": "Skill 4 - Sentence Building"},
        {"day_offset": 5,  "skill": "sinhala_vowels", "acts": ["vowels"],             "name": "Sinhala Vowels Pronunciation"},
        {"day_offset": 3,  "skill": "sinhala_consonants", "acts": ["consonants"],     "name": "Sinhala Consonants Pronunciation"},
        {"day_offset": 1,  "skill": "5_6", "acts": ["5.1", "5.2", "5.3", "5.4", "6.1", "6.2"], "name": "Skills 5 & 6 Reading"},
    ]

    total_rounds_completed = 0
    total_first_correct = 0

    for s_idx, s_def in enumerate(session_defs, start=1):
        s_date = NOW - timedelta(days=s_def["day_offset"], hours=random.randint(1, 4))
        session_id = f"sess_{student_id_str[-6:]}_{s_idx:02d}_{s_def['day_offset']}d"
        
        # Touch Sessions (Skills 1-4)
        if s_def["skill"] in ["1", "2", "3", "4"]:
            events = []
            session_act_breakdowns = {}
            session_kcs = {}
            round_in_sess = 1
            
            for act_key in s_def["acts"]:
                kc_id = KC_MAP.get(act_key, "KC_VISUAL_IDENTIFICATION")
                items = item_cache.get(act_key) or []
                if not items:
                    items = [{"item_id": f"S{act_key.replace('.', 'A')}R01", "content": {"prompt": f"Activity {act_key} task"}}]
                
                act_rounds = 4  # 4 rounds per activity
                act_correct = 0
                
                for r_i in range(act_rounds):
                    it = items[r_i % len(items)]
                    iid = it.get("item_id", f"S{act_key.replace('.', 'A')}R{r_i+1:02d}")
                    
                    if is_avg:
                        first_correct = random.random() < 0.80
                        latency = random.randint(2100, 2700)
                        hesitations = 0 if first_correct else 1
                        misclicks = 0 if first_correct else 1
                        attempts = 1 if first_correct else 2
                        scaffold_lvl = 0 if first_correct else 1
                    else:
                        first_correct = random.random() < 0.52
                        latency = random.randint(4800, 6400)
                        hesitations = 1 if first_correct else 2
                        misclicks = 1 if first_correct else 3
                        attempts = 1 if first_correct else random.choice([2, 3])
                        scaffold_lvl = 0 if first_correct else random.choice([1, 2])
                    
                    if first_correct:
                        act_correct += 1
                        total_first_correct += 1
                    total_rounds_completed += 1
                    
                    time_to_correct = latency if first_correct else latency + 1500
                    total_round_latency = time_to_correct + 500
                    
                    # Resolved answers
                    cid = it.get("content", {})
                    target_val = (cid.get("correctOption") or cid.get("target_word") or 
                                  cid.get("target_letter") or (cid.get("letters") or ["ක"])[0] or "අ")
                    distractor_val = "ම" if target_val != "ම" else "ල"
                    sel_ans = str(target_val) if first_correct else distractor_val
                    struggled_unit = "ප" if not is_avg else None

                    ev = {
                        "event_id": f"{session_id}:{iid}:complete",
                        "session_id": session_id,
                        "student_id": student_id_str,
                        "skill_id": f"skill_{s_def['skill']}",
                        "activity_id": act_key,
                        "activity_name": ACTIVITY_NAMES_SI.get(act_key, act_key),
                        "item_id": iid,
                        "knowledge_component_id": kc_id,
                        "is_abandoned": False,
                        "is_correct": True,
                        "final_correct": True,
                        "first_attempt_correct": first_correct,
                        "attempt_count": attempts,
                        "incorrect_attempt_count": attempts - 1,
                        "first_touch_latency_ms": latency,
                        "time_to_first_response_ms": latency,
                        "time_to_correct_ms": time_to_correct,
                        "total_round_latency_ms": total_round_latency,
                        "misclick_count": misclicks,
                        "hesitation_count": hesitations,
                        "correction_count": 0 if first_correct else 1,
                        "hint_count": 0 if first_correct else 1,
                        "scaffold_level_used": scaffold_lvl,
                        "response_modality": "touch",
                        "timestamp": (s_date + timedelta(seconds=round_in_sess*30)).isoformat(),
                        "research_eligible": True
                    }
                    events.append(ev)
                    
                    # Top-level telemetry_events entry
                    db.telemetry_events.insert_one({
                        "ingestion_key": str(uuid.uuid4()),
                        "event_id": ev["event_id"],
                        "student_id": student_id_str,
                        "session_id": session_id,
                        "skill_id": f"skill_{s_def['skill']}",
                        "activity_id": act_key,
                        "activity_name": ev["activity_name"],
                        "item_id": iid,
                        "knowledge_component_id": kc_id,
                        "is_abandoned": False,
                        "is_correct": True,
                        "first_attempt_correct": first_correct,
                        "attempt_count": attempts,
                        "incorrect_attempt_count": attempts - 1,
                        "first_touch_latency_ms": latency,
                        "total_round_latency_ms": total_round_latency,
                        "misclick_count": misclicks,
                        "hesitation_count": hesitations,
                        "correction_count": 0 if first_correct else 1,
                        "hint_count": 0 if first_correct else 1,
                        "scaffold_level_used": scaffold_lvl,
                        "attempt_history": [
                            {"attempt_number": 1, "is_correct": first_correct, "selected_answers": [sel_ans]},
                        ] if first_correct else [
                            {"attempt_number": 1, "is_correct": False, "selected_answers": [distractor_val]},
                            {"attempt_number": 2, "is_correct": True, "selected_answers": [str(target_val)]}
                        ],
                        "selected_answers": [str(target_val)],
                        "target_ids": [str(target_val)],
                        "targets": [str(target_val)],
                        "struggled_target_units": [struggled_unit] if struggled_unit else [],
                        "timestamp": ev["timestamp"],
                        "submitted_at": ev["timestamp"],
                        "research_eligible": True
                    })

                    # Adaptive Decision entry
                    db.adaptive_decisions.insert_one({
                        "event_id": ev["event_id"],
                        "student_id": student_id_str,
                        "session_id": session_id,
                        "activity_id": act_key,
                        "current_item": iid,
                        "item_role": "CORE" if r_i < 3 else ("CONFIRMATION" if first_correct else "REMEDIATION"),
                        "kc_id": kc_id,
                        "first_attempt_correct": first_correct,
                        "scaffold_level_used": scaffold_lvl,
                        "response_quality": "CLEAN_SUCCESS" if first_correct else "ASSISTED_SUCCESS",
                        "mastery_before": (0.75 if is_avg else 0.42) + (r_i * 0.01),
                        "mastery_after": (0.78 if is_avg else 0.45) + (r_i * 0.01),
                        "selected_difficulty": 0.5,
                        "struggled_target_units": [struggled_unit] if struggled_unit else [],
                        "research_eligible": True,
                        "decision_reason": "CONTINUE" if first_correct else "SCAFFOLD_AND_RETRY",
                        "policy_version": "Policy-v2.0",
                        "timestamp": ev["timestamp"],
                        "created_at": s_date
                    })

                    # Policy decision entry
                    db.policy_decisions.insert_one({
                        "event_id": ev["event_id"],
                        "student_id": student_id_str,
                        "session_id": session_id,
                        "item_id": iid,
                        "activity_id": act_key,
                        "applied_action": "CONTINUE" if first_correct else "SCAFFOLD_REMOVE_DISTRACTOR",
                        "decision": "CONTINUE" if first_correct else "SCAFFOLD_REMOVE_DISTRACTOR",
                        "behavioral_context": {
                            "first_attempt_accuracy": 1.0 if first_correct else 0.0,
                            "mean_latency_ms": latency,
                            "support_rate": 0.0 if first_correct else 0.5,
                            "behavioral_fatigue_proxy": 0.1 if is_avg else 0.35
                        },
                        "timestamp": ev["timestamp"]
                    })

                    round_in_sess += 1

                act_acc = act_correct / act_rounds
                session_act_breakdowns[act_key] = {"trials": act_rounds, "accuracy": act_acc}
                session_kcs[kc_id] = {"trials": act_rounds, "accuracy": act_acc}

            # Insert Telemetry Session
            total_duration = round_in_sess * 35
            db.telemetry_sessions.insert_one({
                "student_id": student_id_str,
                "session_id": session_id,
                "session_number": s_idx,
                "schema_version": "2.0",
                "session_duration_seconds": total_duration,
                "completed_at": s_date.isoformat(),
                "submitted_at": s_date.isoformat(),
                "data_origin": "observed",
                "skill_id": f"skill_{s_def['skill']}",
                "events": events
            })

            # Session Summary
            sess_acc = sum(e["first_attempt_correct"] for e in events) / len(events)
            sess_lat = sum(e["first_touch_latency_ms"] for e in events) / len(events)
            retry_rate = 0.15 if is_avg else 0.45
            fatigue_score = 0.12 if is_avg else 0.48
            fatigue_state = "LOW" if is_avg else "MODERATE"

            db.session_summaries.insert_one({
                "session_id": session_id,
                "student_id": student_id_str,
                "feature_version": "c1-v2",
                "completed_at": s_date.isoformat(),
                "started_at": (s_date - timedelta(seconds=total_duration)).isoformat(),
                "total_trials": len(events),
                "valid_trials": len(events),
                "overall": {
                    "accuracy": sess_acc,
                    "first_attempt_accuracy": sess_acc,
                    "error_rate": 1.0 - sess_acc,
                    "retry_rate": retry_rate,
                    "mean_attempts_per_round": 1.0 + retry_rate,
                    "median_response_latency_ms": sess_lat,
                    "median_time_to_correct_ms": sess_lat + 1200,
                    "correction_rate": 0.90 if is_avg else 0.65,
                    "abandonment_rate": 0.0
                },
                "knowledge_components": {
                    k: {
                        "trials": v["trials"],
                        "accuracy": v["accuracy"],
                        "median_response_latency_ms": sess_lat
                    } for k, v in session_kcs.items()
                },
                "error_profile": {
                    "error_count": round((1.0 - sess_acc) * len(events)),
                    "visual_confusion_rate": 0.15 if is_avg else 0.42,
                    "visual_task_error_rate": 0.10 if is_avg else 0.25,
                    "phonological_confusion_rate": 0.10 if is_avg else 0.48,
                    "sequence_error_rate": 0.05 if is_avg else 0.20,
                    "unknown_error_rate": 0.02
                },
                "behavioral_fatigue_proxy": fatigue_score,
                "fatigue_state": fatigue_state,
                "fatigue_components": {
                    "state": fatigue_state,
                    "latency_drift": 0.02 if is_avg else 0.18,
                    "error_drift": 0.01 if is_avg else 0.15,
                    "hesitation_drift": 0.0 if is_avg else 0.12
                },
                "activity_breakdown": {
                    act_key: {
                        "trials": v["trials"],
                        "accuracy": v["accuracy"],
                        "median_response_latency_ms": sess_lat,
                        "retry_rate": retry_rate,
                        "visual_confusion_rate": 0.15 if is_avg else 0.40
                    } for act_key, v in session_act_breakdowns.items()
                },
                "activity_breakdown_by_skill": {
                    f"skill_{s_def['skill']}::{act_key}": {
                        "skill_id": f"skill_{s_def['skill']}",
                        "activity_id": act_key,
                        "activity_name": ACTIVITY_NAMES_SI.get(act_key, act_key),
                        "trials": v["trials"],
                        "accuracy": v["accuracy"],
                        "median_response_latency_ms": sess_lat,
                        "retry_rate": retry_rate
                    } for act_key, v in session_act_breakdowns.items()
                }
            })

            # Behavioral Features
            db.behavioral_features.insert_one({
                "student_id": student_id_str,
                "session_id": session_id,
                "timestamp": s_date.isoformat(),
                "feature_version": "v1.0",
                "behavior": {
                    "accuracy": round(sess_acc * 100),
                    "median_latency_ms": sess_lat,
                    "latency_std": 350.0 if is_avg else 1100.0,
                    "latency_drift": 0.02 if is_avg else 0.18,
                    "error_rate": round((1.0 - sess_acc) * 100),
                    "hesitation_rate": 0.10 if is_avg else 0.44,
                    "misclick_rate": 0.08 if is_avg else 0.38
                },
                "fatigue": {"score": fatigue_score},
                "indices": {
                    "visual_processing_index": 78.0 if is_avg else 48.0,
                    "phonological_task_index": 75.0 if is_avg else 42.0,
                    "motor_interaction_index": 82.0 if is_avg else 55.0,
                    "attention_stability_index": 80.0 if is_avg else 46.0
                }
            })

            # Kinematic Features
            db.kinematic_features.insert_one({
                "event_id": str(uuid.uuid4()),
                "student_id": student_id_str,
                "session_id": session_id,
                "timestamp": s_date.isoformat(),
                "feature_version": "v1.0",
                "time_to_first_touch_ms": 1250 if is_avg else 3600,
                "dwell_time_ms": 180.0 if is_avg else 450.0,
                "mean_dwell_time_ms": 180.0 if is_avg else 450.0,
                "path_efficiency_ratio": 0.88 if is_avg else 0.68,
                "path_efficiency": 0.88 if is_avg else 0.68,
                "path_length": 520.0,
                "straight_line_distance": 457.0 if is_avg else 353.0,
                "mean_velocity": 195.0 if is_avg else 115.0,
                "velocity_variance": 42.0 if is_avg else 98.0,
                "dimensionless_jerk": 2.8 if is_avg else 7.2,
                "normalized_jerk": 2.8 if is_avg else 7.2,
                "orthographic_confusion_index": 0.12 if is_avg else 0.44,
                "orthographic_confusion_coverage": 1.0
            })

        # Session 5: Sinhala Vowels (12 letters)
        elif s_def["skill"] == "sinhala_vowels":
            for index, letter in enumerate(VOWELS, start=1):
                item_id = f"SVOWA1R{index:02d}"
                is_match = True if (is_avg or index not in [3, 7, 10]) else False
                rec_letter = letter if is_match else ("අ" if letter != "අ" else "ආ")
                
                db.speech_features.insert_one({
                    "speech_event_id": str(uuid.uuid4()),
                    "attempt_id": str(uuid.uuid4()),
                    "student_id": student_id_str,
                    "session_id": session_id,
                    "item_id": item_id,
                    "skill_id": "skill_sinhala_vowels",
                    "task_kind": "letter_pronunciation",
                    "letter": letter,
                    "expected_text": letter,
                    "recognized_text": rec_letter,
                    "transcription": rec_letter,
                    "exact_match": is_match,
                    "recording_quality": "valid",
                    "measurement_status": "valid",
                    "acoustic_latency_ms": 360.0 if is_avg else 850.0,
                    "voice_onset_ms": 340.0 if is_avg else 820.0,
                    "word_accuracy": 1.0 if is_match else 0.0,
                    "grapheme_accuracy": 1.0 if is_match else 0.0,
                    "timestamp": (s_date + timedelta(seconds=index*15)).isoformat(),
                    "created_at": s_date + timedelta(seconds=index*15),
                    "data_origin": "observed"
                })

        # Session 6: Sinhala Consonants (18 letters)
        elif s_def["skill"] == "sinhala_consonants":
            for index, letter in enumerate(CONSONANTS, start=1):
                item_id = f"SCONSA1R{index:02d}"
                # struggling learner frequently confuses look-alikes (ප/බ, ට/ඩ, ත/ද)
                if is_avg:
                    is_match = index not in [8, 14]
                else:
                    is_match = index not in [1, 5, 7, 9, 10, 11, 16]
                
                if is_match:
                    rec_letter = letter
                else:
                    confusions = {"ප": "බ", "බ": "ප", "ට": "ඩ", "ද": "ධ", "ක": "ග"}
                    rec_letter = confusions.get(letter, "අ")
                
                db.speech_features.insert_one({
                    "speech_event_id": str(uuid.uuid4()),
                    "attempt_id": str(uuid.uuid4()),
                    "student_id": student_id_str,
                    "session_id": session_id,
                    "item_id": item_id,
                    "skill_id": "skill_sinhala_consonants",
                    "task_kind": "letter_pronunciation",
                    "letter": letter,
                    "expected_text": letter,
                    "recognized_text": rec_letter,
                    "transcription": rec_letter,
                    "exact_match": is_match,
                    "recording_quality": "valid",
                    "measurement_status": "valid",
                    "acoustic_latency_ms": 390.0 if is_avg else 920.0,
                    "voice_onset_ms": 370.0 if is_avg else 880.0,
                    "word_accuracy": 1.0 if is_match else 0.0,
                    "grapheme_accuracy": 1.0 if is_match else 0.0,
                    "timestamp": (s_date + timedelta(seconds=index*15)).isoformat(),
                    "created_at": s_date + timedelta(seconds=index*15),
                    "data_origin": "observed"
                })

        # Session 7: Oral Reading (Skills 5 & 6)
        elif s_def["skill"] == "5_6":
            reading_items = [
                ("5.1", "S5A1R01", "5", "පොත කියවන්න", "පොත කියවන්න" if is_avg else "පොත කියන්න"),
                ("5.2", "S5A2R01", "5", "අම්මා බත් උයයි", "අම්මා බත් උයයි" if is_avg else "අම්මා බත් කයි"),
                ("5.3", "S5A3R01", "5", "කුරුල්ලා ගස උඩ සිටී", "කුරුල්ලා ගස උඩ සිටී" if is_avg else "කුරුල්ලා ගහ උඩ ඉඳී"),
                ("5.4", "S5A4R01", "5", "අපි සෙල්ලම් කරමු", "අපි සෙල්ලම් කරමු" if is_avg else "අපි සෙල්ලම්"),
                ("6.1", "S6A1R01", "6", "අපි පොත් කියවමු පාසල් යමු", "අපි පොත් කියවමු පාසල් යමු" if is_avg else "අපි පොත් පාසල් යමු"),
                ("6.2", "S6A2R01", "6", "අපේ ගම ලස්සනයි ගහකොළ පිරිලා ඇත", "අපේ ගම ලස්සනයි ගහකොළ පිරිලා ඇත" if is_avg else "අපේ ගම ලස්සනයි ගහ පිරිලා"),
            ]
            for r_idx, (act_k, iid, skill_num, exp_txt, rec_txt) in enumerate(reading_items):
                exp_words = exp_txt.split()
                rec_words = rec_txt.split()
                common_words = sum(1 for w in rec_words if w in exp_words)
                w_acc = common_words / len(exp_words)
                wer = 1.0 - w_acc
                g_acc = min(1.0, w_acc + 0.08)
                
                # Word operations
                word_ops = []
                for ew in exp_words:
                    if ew in rec_words:
                        word_ops.append({"operation": "match", "expected": ew, "observed": ew})
                    else:
                        word_ops.append({"operation": "substitution" if not is_avg else "deletion",
                                         "expected": ew, "observed": rec_words[0] if rec_words else ""})
                
                # Letter changes
                letter_changes = []
                if not is_avg:
                    letter_changes = [
                        {"op": "substitution", "expected": "ප", "observed": "බ"},
                        {"op": "substitution", "expected": "ද", "observed": "ධ"}
                    ]

                db.speech_features.insert_one({
                    "speech_event_id": str(uuid.uuid4()),
                    "attempt_id": str(uuid.uuid4()),
                    "student_id": student_id_str,
                    "session_id": session_id,
                    "item_id": iid,
                    "skill_id": f"skill_{skill_num}",
                    "activity_id": act_k,
                    "activity_name": ACTIVITY_NAMES_SI.get(act_k, act_k),
                    "task_kind": "oral_reading",
                    "expected_text": exp_txt,
                    "recognized_text": rec_txt,
                    "transcription": rec_txt,
                    "word_error_rate": wer,
                    "wer": wer,
                    "word_accuracy": w_acc,
                    "grapheme_accuracy": g_acc,
                    "reading_rate_wpm": 65.0 if is_avg else 34.0,
                    "acoustic_latency_ms": 380.0 if is_avg else 920.0,
                    "reading_initiation_latency_ms": 380.0 if is_avg else 920.0,
                    "voice_onset_ms": 350.0 if is_avg else 890.0,
                    "speech_duration_ms": 2800.0 if is_avg else 4900.0,
                    "pause_count": 1 if is_avg else 5,
                    "pause_ratio": 0.08 if is_avg else 0.28,
                    "mean_pause_duration_ms": 120.0 if is_avg else 450.0,
                    "intra_word_silence_ratio": 0.06 if is_avg else 0.26,
                    "syllabic_event_mismatch": 0 if is_avg else 2,
                    "peak_count_delta": 0.1 if is_avg else 2.2,
                    "local_jitter": 0.018 if is_avg else 0.042,
                    "local_shimmer": 0.024 if is_avg else 0.052,
                    "recording_quality": "valid",
                    "measurement_status": "valid",
                    "recording_quality_score": 0.94 if is_avg else 0.82,
                    "combined_confidence": 0.92 if is_avg else 0.76,
                    "reading_performance_score": round(w_acc, 4),
                    "alignment": {
                        "word": {"operations": word_ops},
                        "grapheme": {"operations": [
                            {"operation": "substitution", "expected": lc["expected"], "observed": lc["observed"]}
                            for lc in letter_changes
                        ]}
                    },
                    "fusion": {
                        "method_disagreement": False,
                        "disagreement_reasons": []
                    },
                    "recording_quality_issues": [],
                    "pipeline_version": "c2-v2.1",
                    "asr_model": "whisper-sinhala-v2",
                    "timestamp": (s_date + timedelta(seconds=r_idx*30)).isoformat(),
                    "created_at": s_date + timedelta(seconds=r_idx*30),
                    "data_origin": "observed"
                })

    print(f"Generated {total_rounds_completed} rounds across sessions.")

    # 4. C1 Learner Estimate (14-day window)
    c1_pattern = "Typical Learning Pattern" if is_avg else "Phonological Learning Pattern"
    c1_probs = {
        "Typical": 0.82 if is_avg else 0.05,
        "Phonological": 0.08 if is_avg else 0.72,
        "Visual-Orthographic": 0.06 if is_avg else 0.10,
        "Combined": 0.04 if is_avg else 0.13
    }
    db.c1_learner_estimates.insert_one({
        "student_id": student_id_str,
        "status": "estimated",
        "predicted_pattern": c1_pattern,
        "probabilities": c1_probs,
        "confidence": 0.85 if is_avg else 0.79,
        "model_name": "c1_learner_model",
        "model_version": "3.0.0",
        "feature_schema_version": "c1-learner-v2",
        "provenance": "synthetic_only",
        "data_origin": "observed",
        "computed_at": (NOW - timedelta(hours=3)).isoformat(),
        "window_days": 14,
        "evidence": {
            "completed_rounds": total_rounds_completed,
            "abandoned_rounds": 0,
            "sessions": 4,
            "sessions_with_completed_rounds": 4,
            "picture_task_rounds": 20,
            "sound_task_rounds": 8,
            "sessions_with_4plus_rounds": 4,
            "skills": ["skill_1", "skill_2", "skill_3", "skill_4"]
        },
        "evidence_rule": {
            "window_days": 14,
            "min_completed_rounds": 20,
            "min_sessions": 2
        },
        "features": {
            "accuracy": 0.78 if is_avg else 0.51,
            "mean_latency_ms": 2550.0 if is_avg else 5600.0,
            "median_latency_ms": 2400.0 if is_avg else 5300.0,
            "latency_std_ms": 420.0 if is_avg else 1450.0,
            "mean_first_touch_latency_ms": 1250.0 if is_avg else 3600.0,
            "hesitation_rate": 0.08 if is_avg else 0.44,
            "misclick_rate": 0.07 if is_avg else 0.38,
            "completion_rate": 1.0,
            "visual_processing_index": 78.0 if is_avg else 48.0,
            "phonological_task_index": 75.0 if is_avg else 42.0,
            "motor_interaction_index": 82.0 if is_avg else 55.0,
            "attention_stability_index": 80.0 if is_avg else 46.0,
            "fatigue_score": 0.12 if is_avg else 0.48,
            "cognitive_load_score": 0.25 if is_avg else 0.72
        },
        "missing_evidence": [],
        "outside_range": [],
        "notes": [f"Learner-level estimate consistent with observed Grade 1 tasks."]
    })

    # 5. C3 Multimodal Learner Profile
    c3_pattern = "Typical" if is_avg else "Phonological"
    c3_probs = {
        "Typical": 0.79 if is_avg else 0.04,
        "Phonological": 0.07 if is_avg else 0.68,
        "Visual-Orthographic": 0.10 if is_avg else 0.10,
        "Combined": 0.04 if is_avg else 0.18
    }
    if is_avg:
        shap_features = [
            {"feature_name": "c1_first_try_accuracy", "shap_impact": "+0.22", "observed_value": 0.78, "value": 0.78, "direction": "positive"},
            {"feature_name": "path_efficiency_ratio", "shap_impact": "+0.16", "observed_value": 0.88, "value": 0.88, "direction": "positive"},
            {"feature_name": "acoustic_latency_ms", "shap_impact": "+0.12", "observed_value": 380.0, "value": 380.0, "direction": "positive"},
            {"feature_name": "orthographic_confusion_index", "shap_impact": "+0.08", "observed_value": 0.12, "value": 0.12, "direction": "positive"}
        ]
        llm_summary = (
            f"{first_name} exhibits a well-balanced learning profile across touchscreen and oral reading tasks. "
            "Touch interactions demonstrate solid motor control, low latency drift, and good path efficiency. "
            "Speech initiation and reading accuracy are consistent with typical Grade 1 progression."
        )
        llm_recs = (
            "Maintain current reading practice schedule. Introduce slightly longer vocabulary words and short "
            "sentence decoding to nurture continued confidence and expressive fluency."
        )
    else:
        shap_features = [
            {"feature_name": "acoustic_latency_ms", "shap_impact": "+0.28", "observed_value": 920.0, "value": 920.0, "direction": "positive"},
            {"feature_name": "c1_first_try_accuracy", "shap_impact": "+0.24", "observed_value": 0.51, "value": 0.51, "direction": "positive"},
            {"feature_name": "orthographic_confusion_index", "shap_impact": "+0.19", "observed_value": 0.44, "value": 0.44, "direction": "positive"},
            {"feature_name": "path_efficiency_ratio", "shap_impact": "+0.14", "observed_value": 0.68, "value": 0.68, "direction": "positive"}
        ]
        llm_summary = (
            f"{first_name} presents observable indicators aligned with a Phonological learning pattern, accompanied "
            "by secondary visual-orthographic letter confusion. Pronounced latency in speech initiation, frequent "
            "substitutions between similar aksharas (e.g., ප/බ, ද/ධ), and exploratory touch movements suggest "
            "challenges in rapid auditory-visual binding."
        )
        llm_recs = (
            "Prioritize multisensory phonological reinforcement. Pair auditory letter pronunciation with distinct "
            "visual highlighting for easily confused letters (ප/බ). Encourage brief, scaffolded reading sessions "
            "with immediate supportive feedback."
        )

    db.learner_profiles.insert_one({
        "student_id": student_id_str,
        "session_id": f"sess_{student_id_str[-6:]}_latest",
        "feature_version": "c3-learner-window-v1",
        "model_version": "C3-v2.0-XGBoost",
        "timestamp": (NOW - timedelta(hours=2)).isoformat(),
        "created_at": NOW - timedelta(hours=2),
        "pipeline_status": "available",
        "model_applied": True,
        "learner_profile": {
            "primary_pattern": c3_pattern,
            "class_probabilities": c3_probs,
            "confidence": 0.82 if is_avg else 0.78,
            "modalities_used": ["C1_Behavioral_Touch", "C2_Acoustic_Speech", "C4_Adaptive_Mastery"]
        },
        "shap_explanations": {
            "top_contributing_features": shap_features
        },
        "evidence_summary": {
            "c1": {"first_attempt_accuracy": 0.78 if is_avg else 0.51, "median_response_latency_ms": 2400.0 if is_avg else 5300.0},
            "c2": {"word_accuracy": 0.83 if is_avg else 0.52, "acoustic_latency_ms": 380.0 if is_avg else 920.0, "letter_practice": {"attempts": 30}},
            "parent_observation_count": 4 if is_avg else 20
        },
        "evidence_window": {
            "days": 14,
            "movement_sessions": 4,
            "min_movement_sessions": 1,
            "recordings": 6,
            "usable_recordings": 6,
            "min_usable_recordings": 1
        },
        "missing_inputs": [],
        "outside_range": [],
        "llm_summary": llm_summary,
        "llm_recommendations": llm_recs
    })

    # 6. C4 Knowledge State
    knowledge_state = {}
    for kc in ALL_KCS:
        if is_avg:
            knowledge_state[kc] = round(random.uniform(0.74, 0.86), 2)
        else:
            knowledge_state[kc] = round(random.uniform(0.38, 0.54), 2)

    db.knowledge_states.insert_one({
        "student_id": student_id_str,
        "updated_at": (NOW - timedelta(hours=1)).isoformat(),
        "knowledge_state": knowledge_state,
        "theta_estimate": 0.45 if is_avg else -0.58,
        "theta_se": 0.12
    })

    print(f"Student {first_name} {last_name} successfully populated in MongoDB.")
    return student_id_str

# Run for both personas
avg_persona = {
    "is_average": True,
    "first_name": "Dinuka",
    "last_name": "Silva",
    "avatar_url": "assets/images/characters/human/human_student_1.png",
    "age_months": 75,
    "birth_year": 2020,
    "birth_month": 7,
    "gender": "male"
}

struggling_persona = {
    "is_average": False,
    "first_name": "Nuwan",
    "last_name": "Perera",
    "avatar_url": "assets/images/characters/human/human_student_2.png",
    "age_months": 73,
    "birth_year": 2020,
    "birth_month": 9,
    "gender": "male"
}

dinuka_id = create_student_dataset(avg_persona)
nuwan_id = create_student_dataset(struggling_persona)

print("\n" + "=" * 80)
print("COMPLETED CREATING 2 SIMULATED STUDENTS:")
print(f"  1. Dinuka Silva  (Average)    -> ID: {dinuka_id}")
print(f"  2. Nuwan Perera   (Struggling) -> ID: {nuwan_id}")
print(f"  Owned by Parent: parent@sipsara.com (ID: {PARENT_ID})")
print(f"  Connected to Therapist: therapist@sipsara.com (ID: {THERAPIST_ID}, Code: {CLINIC_CODE})")
print("=" * 80)
