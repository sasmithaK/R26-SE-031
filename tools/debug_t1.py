from pymongo import MongoClient
import os, json

MONGODB_URL = os.getenv('MONGODB_URL', os.getenv('MONGO_URL', 'mongodb+srv://dyslexiaAdmin:yourpassword@cluster01.evjs7kv.mongodb.net/?appName=Cluster01'))
DB = os.getenv('MONGODB_DB','visual_service')
client = MongoClient(MONGODB_URL)
db = client[DB]

sid = 'student_1778525364743'

print("=" * 80)
print(f"DETAILED CHECK FOR STUDENT {sid}")
print("=" * 80)

# Check task scores
print(f"\n1. Task Scores for {sid}:")
tasks = list(db['task_scores'].find({'student_id': sid}, {'_id': 0}))
print(f"   Total: {len(tasks)} tasks")
for t in sorted(tasks, key=lambda x: x.get('created_at', '')):
    print(f"   - {t.get('task_name')}: score={t.get('score')}, level={t.get('metadata', {}).get('level')}, at={t.get('created_at')}")

# Check comprehension progress
print(f"\n2. Comprehension Progress for {sid}:")
comp = list(db['comprehension_progress'].find({'studentId': sid}, {'_id': 0}))
print(f"   Found: {len(comp)} record(s)")
for c in comp:
    print(f"   - highestLevel: {c.get('highestLevelReached')}, accuracy: {c.get('comprehensionAccuracy')}")

# Check fluency progress  
print(f"\n3. Fluency Progress for {sid}:")
fluency = list(db['fluency_progress'].find({'studentId': sid}, {'_id': 0}))
print(f"   Found: {len(fluency)} record(s)")
for f in fluency:
    print(f"   - avg_wpm: {f.get('avgWpm')}, level: {f.get('fluencyLevel')}, errorCount: {f.get('avgWer')}")

# Check letter identification
print(f"\n4. Letter Identification Scores for {sid}:")
letters = list(db['letter_identification_scores'].find({'studentId': sid}, {'_id': 0}))
print(f"   Found: {len(letters)} score(s)")
for l in letters[:3]:  # Show first 3
    print(f"   - {l.get('letter')}: success={l.get('isSuccessful')}")

# Check if assessment_results exists
print(f"\n5. Assessment Results for {sid}:")
assess = db['assessment_results'].find_one({'studentId': sid})
if assess:
    print(f"   ✓ FOUND")
else:
    print(f"   ✗ NOT FOUND - This is why t1 isn't showing!")

print("\n" + "=" * 80)
print("ANALYSIS:")
print("- Task scores exist (4 tasks completed)")
print("- If comprehension highest level < 3, assessment won't save")
print("- Check comprehension_progress.highestLevelReached")
print("=" * 80)
