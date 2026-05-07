import pymongo
import random
import datetime
from datetime import timedelta

STUDENT_ID = "STU_DEMO_01"
SKILLS = [
    "vowel_a",
    "vowel_recognition",
    "letter_ka",
    "letter_ga",
    "letter_na",
    "letter_ma",
    "pilla_ispilla",
    "pilla_aapilla",
    "syllable_blending",
    "phoneme_isolation"
]

INTERVENTION_TYPES = ["Audio_Hint", "Visual_Split", "Break"]

MONGO_URI = "mongodb+srv://kavindugunasena_db_user:2Vp8ipkprifuEH8t@cluster0.ypxuqen.mongodb.net/"
client = pymongo.MongoClient(MONGO_URI)

def setup_content_db():
    print("Seeding content_db...")
    db = client.content_db
    db.mastery.delete_many({"student_id": STUDENT_ID})
    db.mastery_history.delete_many({"student_id": STUDENT_ID})
    
    now = datetime.datetime.now(datetime.UTC)
    for i, skill in enumerate(SKILLS):
        base_mastery = 0.2 + (i * 0.05)
        current_mastery = min(1.0, base_mastery + random.uniform(0.1, 0.3))
        last_at = now - timedelta(hours=random.randint(1, 12))
        attempts = random.randint(5, 20)
        
        db.mastery.update_one(
            {"student_id": STUDENT_ID, "skill_id": skill},
            {"$set": {
                "mastery_level": current_mastery,
                "last_practiced_at": last_at,
                "attempt_count": attempts
            }},
            upsert=True
        )
        
        # Add some history
        for h in range(5):
            db.mastery_history.insert_one({
                "student_id": STUDENT_ID,
                "skill_id": skill,
                "mastery_level": max(0.1, current_mastery - (5-h)*0.05),
                "timestamp": last_at - timedelta(days=5-h)
            })

def setup_intervention_db():
    print("Seeding intervention_db...")
    db = client.intervention_db
    db.intervention_log.delete_many({"student_id": STUDENT_ID})
    db.failure_tracker.delete_many({"student_id": STUDENT_ID})
    db.outcome_log.delete_many({"student_id": STUDENT_ID})
    
    now = datetime.datetime.now(datetime.UTC)
    for _ in range(15):
        ts = now - timedelta(days=random.randint(0, 5), minutes=random.randint(0, 1440))
        db.intervention_log.insert_one({
            "student_id": STUDENT_ID,
            "intervention_type": random.choice(INTERVENTION_TYPES),
            "weak_skill": random.choice(SKILLS),
            "latency_ms": random.uniform(2000, 7000),
            "erratic_clicks": random.uniform(0, 4),
            "mastery_level": random.uniform(0.2, 0.8),
            "prev_failures": random.randint(0, 2),
            "shap_top_feature": random.choice(["latency_ms", "erratic_clicks", "mastery_level"]),
            "timestamp": ts
        })
    
    db.failure_tracker.insert_one({
        "student_id": STUDENT_ID,
        "failure_count": 0,
        "updated_at": now
    })

def setup_monitoring_db():
    print("Seeding monitoring_db...")
    db = client.monitoring_db
    db.telemetry.delete_many({"student_id": STUDENT_ID})
    db.latest_telemetry.delete_many({"student_id": STUDENT_ID})
    db.student_baseline.delete_many({"student_id": STUDENT_ID})
    
    now = datetime.datetime.now(datetime.UTC)
    db.student_baseline.insert_one({
        "student_id": STUDENT_ID,
        "mean_hesitation": 2800.0,
        "std_hesitation": 500.0,
        "mean_correction": 0.1,
        "std_correction": 0.04,
        "session_count": 20,
        "updated_at": now
    })
    
    db.latest_telemetry.insert_one({
        "student_id": STUDENT_ID,
        "cognitive_load": 0,
        "hesitation_time_ms": 1500.0,
        "erratic_clicks": 0.0,
        "updated_at": now
    })

if __name__ == "__main__":
    print(f"Starting MongoDB data seeding for student: {STUDENT_ID}")
    try:
        setup_content_db()
        setup_intervention_db()
        setup_monitoring_db()
        print("MongoDB seeding completed successfully!")
    except Exception as e:
        print(f"Error seeding MongoDB: {e}")
