from pymongo import MongoClient
import os, json
from datetime import datetime

MONGODB_URL = os.getenv('MONGODB_URL', os.getenv('MONGO_URL', 'mongodb+srv://dyslexiaAdmin:yourpassword@cluster01.evjs7kv.mongodb.net/?appName=Cluster01'))
DB = os.getenv('MONGODB_DB','visual_service')
client = MongoClient(MONGODB_URL)
db = client[DB]

print("=" * 80)
print("SEARCHING FOR 't1' STUDENT RECORDS")
print("=" * 80)

# Search in assessment_results
print("\n1. Assessment Results Collection:")
results = list(db['assessment_results'].find({'studentName': 't1'}, {'_id': 1, 'studentId': 1, 'studentName': 1, 'savedAt': 1}))
print(f"   Found {len(results)} records")
for r in results:
    print(f"     - {r}")

# Search by studentId pattern (in case name was different)
print("\n2. Looking for any 't1' in studentId:")
results = list(db['assessment_results'].find({'studentId': {'$regex': 't1'}}, {'_id': 1, 'studentId': 1, 'studentName': 1, 'savedAt': 1}))
print(f"   Found {len(results)} records")
for r in results:
    print(f"     - {r}")

# Check fluency_progress
print("\n3. Fluency Progress Collection:")
results = list(db['fluency_progress'].find({'studentId': {'$regex': 't1'}}, {'studentId': 1, 'lastUpdated': 1}))
print(f"   Found {len(results)} records")
for r in results:
    print(f"     - {r}")

# Check letter_identification_scores
print("\n4. Letter Identification Scores Collection:")
results = list(db['letter_identification_scores'].find({'studentId': {'$regex': 't1'}}, {'studentId': 1, 'attemptedAt': 1}))
print(f"   Found {len(results)} records")
for r in results:
    print(f"     - {r}")

# Check comprehension_progress
print("\n5. Comprehension Progress Collection:")
results = list(db['comprehension_progress'].find({'studentId': {'$regex': 't1'}}, {'studentId': 1, 'lastUpdated': 1}))
print(f"   Found {len(results)} records")
for r in results:
    print(f"     - {r}")

# Check task_scores
print("\n6. Task Scores Collection:")
results = list(db['task_scores'].find({'student_id': {'$regex': 't1'}}, {'student_id': 1, 'task_name': 1, 'created_at': 1}))
print(f"   Found {len(results)} records")
for r in results:
    print(f"     - {r}")

# Get latest 3 assessment records to see timeline
print("\n7. Latest 3 assessment records (all students):")
latest = list(db['assessment_results'].find({}, {'studentId': 1, 'studentName': 1, 'savedAt': 1}).sort('savedAt', -1).limit(3))
for r in latest:
    print(f"   {r['studentName']} ({r['studentId']}) - {r.get('savedAt', 'N/A')}")

print("\n" + "=" * 80)
