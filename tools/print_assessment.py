from pymongo import MongoClient
from bson.objectid import ObjectId
import os, json

MONGODB_URL = os.getenv('MONGODB_URL', os.getenv('MONGO_URL', 'mongodb+srv://dyslexiaAdmin:yourpassword@cluster01.evjs7kv.mongodb.net/?appName=Cluster01'))
DB = os.getenv('MONGODB_DB','visual_service')
client = MongoClient(MONGODB_URL)
db = client[DB]

obj_id = ObjectId('6a02144a5b82bd631224f8b8')
doc = db['assessment_results'].find_one({'_id': obj_id})
print(json.dumps(doc, default=str, indent=2))
