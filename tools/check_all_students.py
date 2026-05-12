from pymongo import MongoClient
import os, json
from collections import defaultdict

MONGODB_URL = os.getenv('MONGODB_URL', os.getenv('MONGO_URL', 'mongodb+srv://dyslexiaAdmin:yourpassword@cluster01.evjs7kv.mongodb.net/?appName=Cluster01'))
DB = os.getenv('MONGODB_DB','visual_service')
client = MongoClient(MONGODB_URL)
db = client[DB]

print("=" * 80)
print("CHECKING ALL STUDENT RECORDS")
print("=" * 80)

# Get all unique student names and their IDs from assessment_results
print("\nAll students in assessment_results:")
students = db['assessment_results'].aggregate([
    {'$group': {'_id': '$studentId', 'names': {'$addToSet': '$studentName'}, 'count': {'$sum': 1}, 'latestSave': {'$max': '$savedAt'}}},
    {'$sort': {'latestSave': -1}}
])
for s in students:
    print(f"  ID: {s['_id']}")
    print(f"    Names: {s['names']}")
    print(f"    Records: {s['count']}")
    print(f"    Latest: {s['latestSave']}")

# Check task_scores for any t1 references
print("\n\nAll students in task_scores (partial assessment data):")
students = db['task_scores'].aggregate([
    {'$group': {'_id': '$student_id', 'count': {'$sum': 1}, 'latestCreate': {'$max': '$created_at'}}},
    {'$sort': {'latestCreate': -1}},
    {'$limit': 10}
])
for s in students:
    print(f"  ID: {s['_id']} - {s['count']} scores - Latest: {s['latestCreate']}")

# Check for t1 anywhere
print("\n\nDirect search for 't1' pattern in all collections:")
colls = ['assessment_results', 'task_scores', 'fluency_progress', 'letter_identification_scores', 'comprehension_progress']
for coll_name in colls:
    count = db[coll_name].count_documents({'$or': [
        {'studentName': {'$regex': 't1', '$options': 'i'}},
        {'student_id': {'$regex': 't1', '$options': 'i'}},
        {'studentId': {'$regex': 't1', '$options': 'i'}}
    ]})
    if count > 0:
        print(f"  {coll_name}: {count} records")

print("\n" + "=" * 80)
