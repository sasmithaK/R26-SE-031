"""
Backend API for Fluency Progress Tracking & Letter Identification Assessment with MongoDB
This is a simple Flask app to handle fluency progress and letter identification data.
MongoDB stores student assessment data.

Setup:
1. pip install flask pymongo
2. Ensure MongoDB is running on localhost:27017
3. Run: python fluency_api.py
"""

from flask import Flask, request, jsonify
from pymongo import MongoClient
from datetime import datetime
import os
from pathlib import Path

app = Flask(__name__)


@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    return response

# MongoDB Connection
def _load_mongo_uri() -> str:
    env_uri = os.getenv('MONGO_URI')
    if env_uri:
        return env_uri

    env_file = Path(__file__).with_name('.env')
    if env_file.exists():
        for raw_line in env_file.read_text(encoding='utf-8').splitlines():
            line = raw_line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            if key.strip() == 'MONGO_URI':
                return value.strip().strip('"').strip("'")

    return 'mongodb+srv://dyslexiaAdmin:yourpassword@cluster01.evjs7kv.mongodb.net/?appName=Cluster01'


MONGO_URI = _load_mongo_uri()
DB_NAME = 'dyslexia_app'
FLUENCY_COLLECTION = 'fluency_progress'
LETTER_ID_COLLECTION = 'letter_identification'
COMPREHENSION_COLLECTION = 'comprehension_progress'
QUESTIONNAIRE_COLLECTION = 'questionnaire_submissions'

try:
    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=20000)
    client.admin.command('ping')
    db = client[DB_NAME]
    fluency_collection = db[FLUENCY_COLLECTION]
    letter_id_collection = db[LETTER_ID_COLLECTION]
    comprehension_collection = db[COMPREHENSION_COLLECTION]
    questionnaire_collection = db[QUESTIONNAIRE_COLLECTION]
    print(f"✓ Connected to MongoDB: {MONGO_URI.split('@')[-1] if '@' in MONGO_URI else MONGO_URI}")
except Exception as e:
    print(f"✗ MongoDB connection failed: {e}")


@app.route('/api/questionnaire', methods=['POST'])
@app.route('/api/questionnair', methods=['POST'])
@app.route('/api/questionniar', methods=['POST'])
def save_questionnaire_submission():
    """Save questionnaire submission to MongoDB."""
    try:
        data = request.get_json() or {}

        required_fields = [
            'respondent_role',
            'respondent_name',
            'student_name',
            'student_age',
            'student_grade',
            'part_one_score',
            'risk_level',
            'part_two_count',
            'part_three_count',
            'part_one_answers',
            'part_two_answers',
            'part_three_answers',
        ]
        missing_fields = [field for field in required_fields if field not in data]
        if missing_fields:
            return jsonify({'error': f"Missing fields: {', '.join(missing_fields)}"}), 400

        result = questionnaire_collection.insert_one({
            'created_at': data.get('created_at', datetime.now().isoformat()),
            'respondent_role': data['respondent_role'],
            'respondent_name': data['respondent_name'],
            'student_name': data['student_name'],
            'student_age': data['student_age'],
            'student_grade': data['student_grade'],
            'part_one_score': data['part_one_score'],
            'risk_level': data['risk_level'],
            'part_two_count': data['part_two_count'],
            'part_three_count': data['part_three_count'],
            'part_one_answers': data['part_one_answers'],
            'part_two_answers': data['part_two_answers'],
            'part_three_answers': data['part_three_answers'],
        })

        return jsonify({
            'message': 'Questionnaire submission saved',
            'submissionId': str(result.inserted_id),
        }), 201
    except Exception as e:
        app.logger.exception('Failed to save questionnaire submission')
        return jsonify({'error': str(e)}), 500


@app.route('/api/questionnaire', methods=['GET'])
@app.route('/api/questionnair', methods=['GET'])
@app.route('/api/questionniar', methods=['GET'])
def get_questionnaire_submissions():
    """Fetch all questionnaire submissions from MongoDB."""
    try:
        records = list(questionnaire_collection.find().sort('created_at', -1))

        for record in records:
            record.pop('_id', None)

        return jsonify(records), 200
    except Exception as e:
        app.logger.exception('Failed to fetch questionnaire submissions')
        return jsonify({'error': str(e)}), 500

@app.route('/api/fluency', methods=['POST'])
def save_fluency_progress():
    """Save or update fluency progress to MongoDB."""
    try:
        data = request.get_json()
        student_id = data.get('studentId')
        
        if not student_id:
            return jsonify({'error': 'studentId is required'}), 400
        
        # Upsert: update if exists, insert if new
        result = fluency_collection.update_one(
            {'studentId': student_id},
            {'$set': {
                'studentId': student_id,
                'sessionsCompleted': data.get('sessionsCompleted', 0),
                'avgWpm': data.get('avgWpm', 0.0),
                'fluencyLevel': data.get('fluencyLevel', 1),
                'avgWer': data.get('avgWer', 0.0),  # Word Error Rate
                'breakdownLevel': data.get('breakdownLevel', 0),  # Level where fluency broke down
                'lastUpdated': data.get('lastUpdated', datetime.now().isoformat()),
            }},
            upsert=True
        )
        
        return jsonify({
            'message': 'Fluency progress saved',
            'studentId': student_id,
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/fluency/<student_id>', methods=['GET'])
def get_fluency_progress(student_id):
    """Retrieve fluency progress for a student."""
    try:
        record = fluency_collection.find_one({'studentId': student_id})
        
        if not record:
            return jsonify({'error': 'Student not found'}), 404
        
        # Remove MongoDB's internal ID from response
        record.pop('_id', None)
        return jsonify(record), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/fluency/<student_id>', methods=['PUT'])
def update_fluency_progress(student_id):
    """Update fluency progress for a student."""
    try:
        data = request.get_json()
        
        result = fluency_collection.update_one(
            {'studentId': student_id},
            {'$set': {
                'sessionsCompleted': data.get('sessionsCompleted', 0),
                'avgWpm': data.get('avgWpm', 0.0),
                'fluencyLevel': data.get('fluencyLevel', 1),
                'avgWer': data.get('avgWer', 0.0),
                'breakdownLevel': data.get('breakdownLevel', 0),
                'lastUpdated': data.get('lastUpdated', datetime.now().isoformat()),
            }}
        )
        
        if result.matched_count == 0:
            return jsonify({'error': 'Student not found'}), 404
        
        return jsonify({'message': 'Fluency progress updated'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/fluency/<student_id>', methods=['DELETE'])
def delete_fluency_progress(student_id):
    """Delete fluency progress for a student."""
    try:
        result = fluency_collection.delete_one({'studentId': student_id})
        
        if result.deleted_count == 0:
            return jsonify({'error': 'Student not found'}), 404
        
        return jsonify({'message': 'Fluency progress deleted'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/fluency/class/<class_id>', methods=['GET'])
def get_class_fluency_progress(class_id):
    """Get fluency progress for all students in a class (for monitoring)."""
    try:
        # This endpoint assumes you have a class_id field in MongoDB
        records = list(fluency_collection.find({'classId': class_id}))
        
        for record in records:
            record.pop('_id', None)
        
        return jsonify({'students': records}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ================= LETTER IDENTIFICATION ENDPOINTS =================

@app.route('/api/letter-identification/score', methods=['POST'])
def save_letter_score():
    """Save a single letter identification score to MongoDB."""
    try:
        data = request.get_json()
        student_id = data.get('studentId')
        
        if not student_id:
            return jsonify({'error': 'studentId is required'}), 400
        
        # Insert the score
        result = letter_id_collection.insert_one({
            'studentId': student_id,
            'letter': data.get('letter'),
            'visualDiscriminationCorrect': data.get('visualDiscriminationCorrect'),
            'visualDiscriminationTime': data.get('visualDiscriminationTime'),
            'phonologicalAwarenessCorrect': data.get('phonologicalAwarenessCorrect'),
            'phonologicalAwarenessTime': data.get('phonologicalAwarenessTime'),
            'isSuccessful': data.get('isSuccessful'),
            'totalTime': data.get('totalTime'),
            'attemptedAt': data.get('attemptedAt'),
        })
        
        return jsonify({
            'message': 'Letter identification score saved',
            'studentId': student_id,
            'scoreId': str(result.inserted_id),
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/letter-identification/session', methods=['POST'])
def save_letter_session():
    """Save an entire letter identification session to MongoDB."""
    try:
        data = request.get_json()
        student_id = data.get('studentId')
        
        if not student_id:
            return jsonify({'error': 'studentId is required'}), 400
        
        # Insert the session
        result = letter_id_collection.insert_one({
            'type': 'session',
            'studentId': student_id,
            'scores': data.get('scores', []),
            'visualDiscriminationAccuracy': data.get('visualDiscriminationAccuracy'),
            'phonologicalAwarenessAccuracy': data.get('phonologicalAwarenessAccuracy'),
            'overallSuccessRate': data.get('overallSuccessRate'),
            'startedAt': data.get('startedAt'),
            'completedAt': data.get('completedAt'),
        })
        
        return jsonify({
            'message': 'Letter identification session saved',
            'studentId': student_id,
            'sessionId': str(result.inserted_id),
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/letter-identification/student/<student_id>/letter/<letter>', methods=['GET'])
def get_scores_for_letter(student_id, letter):
    """Get scores for a specific student and letter."""
    try:
        scores = list(letter_id_collection.find({
            'studentId': student_id,
            'letter': letter,
            'type': {'$ne': 'session'}
        }))
        
        for score in scores:
            score.pop('_id', None)
        
        if not scores:
            return jsonify({'error': 'No scores found'}), 404
        
        return jsonify({'scores': scores}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/letter-identification/student/<student_id>', methods=['GET'])
def get_scores_for_student(student_id):
    """Get all scores for a student."""
    try:
        scores = list(letter_id_collection.find({
            'studentId': student_id,
            'type': {'$ne': 'session'}
        }))
        
        for score in scores:
            score.pop('_id', None)
        
        if not scores:
            return jsonify({'scores': []}), 200
        
        return jsonify({'scores': scores}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/letter-identification/student/<student_id>/statistics', methods=['GET'])
def get_letter_statistics(student_id):
    """Get overall statistics for a student's letter identification performance."""
    try:
        scores = list(letter_id_collection.find({
            'studentId': student_id,
            'type': {'$ne': 'session'}
        }))
        
        if not scores:
            return jsonify({
                'studentId': student_id,
                'visualAccuracy': 0,
                'phonologicalAccuracy': 0,
                'overallAccuracy': 0,
                'totalAttempts': 0,
            }), 200
        
        visual_correct = sum(1 for s in scores if s.get('visualDiscriminationCorrect'))
        phonological_correct = sum(1 for s in scores if s.get('phonologicalAwarenessCorrect'))
        both_correct = sum(1 for s in scores if s.get('visualDiscriminationCorrect') and s.get('phonologicalAwarenessCorrect'))
        total = len(scores)
        
        return jsonify({
            'studentId': student_id,
            'visualDiscriminationAccuracy': (visual_correct / total * 100) if total > 0 else 0,
            'phonologicalAwarenessAccuracy': (phonological_correct / total * 100) if total > 0 else 0,
            'overallSuccessRate': (both_correct / total * 100) if total > 0 else 0,
            'totalAttempts': total,
            'lettersAttempted': len(set(s.get('letter') for s in scores)),
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ================= READING COMPREHENSION ENDPOINTS =================

@app.route('/api/comprehension', methods=['POST'])
def save_comprehension_progress():
    """Save or update comprehension progress to MongoDB."""
    try:
        data = request.get_json()
        student_id = data.get('studentId')
        
        if not student_id:
            return jsonify({'error': 'studentId is required'}), 400
        
        # Upsert: update if exists, insert if new
        result = comprehension_collection.update_one(
            {'studentId': student_id},
            {'$set': {
                'studentId': student_id,
                'sessionsCompleted': data.get('sessionsCompleted', 0),
                'avgReadingTimeSeconds': data.get('avgReadingTimeSeconds', 0.0),
                'comprehensionAccuracy': data.get('comprehensionAccuracy', 0.0),
                'highestLevelReached': data.get('highestLevelReached', 1),
                'failureLevel': data.get('failureLevel', 0),
                'lastUpdated': data.get('lastUpdated', datetime.now().isoformat()),
            }},
            upsert=True
        )
        
        return jsonify({
            'message': 'Comprehension progress saved',
            'studentId': student_id,
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/comprehension/<student_id>', methods=['GET'])
def get_comprehension_progress(student_id):
    """Retrieve comprehension progress for a student."""
    try:
        record = comprehension_collection.find_one({'studentId': student_id})
        
        if not record:
            return jsonify({'error': 'Student not found'}), 404
        
        # Remove MongoDB's internal ID from response
        record.pop('_id', None)
        return jsonify(record), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/comprehension/<student_id>', methods=['PUT'])
def update_comprehension_progress(student_id):
    """Update comprehension progress for a student."""
    try:
        data = request.get_json()
        
        result = comprehension_collection.update_one(
            {'studentId': student_id},
            {'$set': {
                'sessionsCompleted': data.get('sessionsCompleted', 0),
                'avgReadingTimeSeconds': data.get('avgReadingTimeSeconds', 0.0),
                'comprehensionAccuracy': data.get('comprehensionAccuracy', 0.0),
                'highestLevelReached': data.get('highestLevelReached', 1),
                'failureLevel': data.get('failureLevel', 0),
                'lastUpdated': data.get('lastUpdated', datetime.now().isoformat()),
            }}
        )
        
        if result.matched_count == 0:
            return jsonify({'error': 'Student not found'}), 404
        
        return jsonify({'message': 'Comprehension progress updated'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/comprehension/<student_id>', methods=['DELETE'])
def delete_comprehension_progress(student_id):
    """Delete comprehension progress for a student."""
    try:
        result = comprehension_collection.delete_one({'studentId': student_id})
        
        if result.deleted_count == 0:
            return jsonify({'error': 'Student not found'}), 404
        
        return jsonify({'message': 'Comprehension progress deleted'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/comprehension/class/<class_id>', methods=['GET'])
def get_class_comprehension_progress(class_id):
    """Get comprehension progress for all students in a class (for monitoring)."""
    try:
        records = list(comprehension_collection.find({'classId': class_id}))
        
        for record in records:
            record.pop('_id', None)
        
        return jsonify({'students': records}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'OK', 'service': 'fluency-api'}), 200

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
