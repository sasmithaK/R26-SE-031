import asyncio
from datetime import datetime
import uuid
import sys
import os
from dotenv import load_dotenv

# Load .env from app/backend/api
load_dotenv(os.path.join(os.path.dirname(__file__), "app", "backend", "api", ".env"))

# Add app backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "app", "backend"))
from shared.database import get_db, connect_to_mongo, close_mongo_connection

async def seed_data():
    await connect_to_mongo()
    db = get_db()
    
    student_id = "STU123"
    
    # 1. Clear old data for student
    await db.telemetry_events.delete_many({"student_id": student_id})
    await db.speech_features.delete_many({"student_id": student_id}) # Changed from speech_analysis
    await db.learner_profiles.delete_many({"student_id": student_id})
    await db.adaptive_decisions.delete_many({"student_id": student_id})
    await db.knowledge_states.delete_many({"student_id": student_id})
    await db.session_summaries.delete_many({"student_id": student_id})
    
    # 2. Insert Telemetry
    for i in range(5):
        event_id = str(uuid.uuid4())
        await db.telemetry_events.insert_one({
            "event_id": event_id,
            "student_id": student_id,
            "session_id": f"SES00{i+1}",
            "activity_id": "Activity_1",
            "item_id": "Item_1",
            "timestamp": datetime.utcnow().isoformat(),
            "is_correct": True if i % 2 == 0 else False,
            "first_touch_latency_ms": 1500,
            "total_round_latency_ms": 25000, # 25 seconds practice
            "hesitation_count": 1,
            "misclick_count": 0,
            "audio_replay_count": 0
        })
        
        # Insert Speech for the latest one
        if i == 4:
            await db.speech_features.insert_one({
                "student_id": student_id,
                "session_id": f"SES00{i+1}",
                "timestamp": datetime.utcnow().isoformat(),
                "created_at": datetime.utcnow(),
                "expected_text": "ගමට යමු",
                "recognized_text": "ගමට යමු",
                "word_error_rate": 0.0,
                "acoustic_latency_ms": 1400,
                "pause_count": 0,
                "intra_word_silence_ratio": 0.0,
                "speech_duration_ms": 2500.0,
                "voice_onset_ms": 400.0,
                "syllabic_event_mismatch": 0,
                "local_jitter": 0.02,
                "local_shimmer": 0.03,
                "recording_quality": "Good"
            })
            
    # 2.5 Insert Session Summaries
    for i in range(5):
        await db.session_summaries.insert_one({
            "student_id": student_id,
            "session_id": f"SES00{i+1}",
            "completed_at": datetime.utcnow().isoformat() + "Z",
            "overall": {
                "accuracy": 0.7 + (i * 0.05),
                "latency_ms": 2000 - (i * 100)
            },
            "error_profile": {
                "Visual-Orthographic": 2,
                "Phonological": 1
            },
            "behavioral_fatigue_proxy": 0.1,
            "knowledge_components": {
                "KC_AKSHARA_IDENTITY": {
                    "trials": 5,
                    "accuracy": 0.8,
                    "median_response_latency_ms": 1500,
                    "error_distribution": {}
                },
                "KC_WORD_RECOGNITION": {
                    "trials": 3,
                    "accuracy": 0.6,
                    "median_response_latency_ms": 2200,
                    "error_distribution": {"visual_confusion": 1.0}
                }
            },
            "activity_breakdown": {
                "Activity_1": {
                    "accuracy": 0.8,
                    "trials": 3,
                    "median_response_latency_ms": 1500
                }
            }
        })
        
    # 2.6 Insert Knowledge State
    await db.knowledge_states.insert_one({
        "student_id": student_id,
        "updated_at": datetime.utcnow().isoformat() + "Z",
        "knowledge_state": {
            "Visual Recognition": 0.85,
            "Basic Letter Recognition": 0.70,
            "Form Simple Words": 0.65,
            "Form Simple Sentences": 0.50,
            "Reading Comprehension": 0.40
        },
        "theta_estimate": 0.55,
        "theta_se": 0.12
    })
            
    # 3. Insert Learner Profile
    await db.learner_profiles.insert_one({
        "student_id": student_id,
        "session_id": "SES005",
        "timestamp": datetime.utcnow().isoformat(),
        "created_at": datetime.utcnow(),
        "learner_profile": {
            "class_probabilities": {"Typical": 0.12, "Visual-Orthographic": 0.18, "Phonological": 0.61, "Combined": 0.09},
            "primary_pattern": "Phonological"
        },
        "shap_explanations": {
            "top_contributing_features": [
                {"feature_name": "latency_ms", "shap_impact": "+0.35", "observed_value": 2400.5, "direction": "increased"},
                {"feature_name": "word_error_rate", "shap_impact": "+0.22", "observed_value": 0.15, "direction": "increased"},
                {"feature_name": "accuracy", "shap_impact": "-0.15", "observed_value": 0.78, "direction": "decreased"}
            ]
        },
        "llm_summary": "The model identifies a strong Phonological pattern. The student demonstrates increased latency in phoneme-grapheme mapping and elevated word error rate during speech tasks.",
        "llm_recommendations": "Recommend focusing on auditory-visual integration tasks and phonological awareness activities."
    })
    
    # 4. Insert Adaptive Decision
    await db.adaptive_decisions.insert_one({
        "student_id": student_id,
        "session_id": "SES005",
        "activity_id": "Activity_1",
        "created_at": datetime.utcnow().isoformat() + "Z",
        "mastery_before": 0.60,
        "mastery_after": 0.68,
        "behavioral_fatigue_indicator": 0.12,
        "previous_difficulty": 0.4,
        "selected_difficulty": 0.5,
        "scaffold_level": 1,
        "next_activity": "Skill_5",
        "decision": "ADVANCE",
        "decision_reason": "Mastery improved without fatigue"
    })
    
    await close_mongo_connection()
    print("Database seeded with sample multimodal data.")

if __name__ == "__main__":
    asyncio.run(seed_data())
