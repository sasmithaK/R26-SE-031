import os
from motor.motor_asyncio import AsyncIOMotorClient

# Using local MongoDB instance by default
MONGO_DETAILS = os.getenv("MONGO_URI", "mongodb://localhost:27017")

client = AsyncIOMotorClient(MONGO_DETAILS)
database = client.monitoring_db

latest_telemetry_collection = database.get_collection("latest_telemetry")
student_baseline_collection = database.get_collection("student_baseline")
prediction_collection = database.get_collection("learner_predictions")

async def add_prediction(prediction_data: dict):
    prediction = await prediction_collection.insert_one(prediction_data)
    return str(prediction.inserted_id)
