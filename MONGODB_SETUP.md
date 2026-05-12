# MongoDB Migration Setup Guide

## Overview
This guide explains how to migrate questionnaire and task data from hardcoded values to MongoDB. All content remains exactly the same - only the storage location changes.

## What's Been Changed

### Backend (Python Flask)
- **MongoDB Support Added**: Updated `requirements.txt` with MongoDB dependencies
- **Database Layer**: Modified `database.py` to support both SQLite (mastery tracking) and MongoDB (content)
- **API Endpoints**: New endpoints in `main.py`:
  - `GET /api/questionnaires/{category}` - Get questionnaire by category
  - `GET /api/tasks/{task_type}` - Get all tasks of a specific type
  - `GET /api/tasks/by-level/{task_type}/{level}` - Get tasks by type and level
- **Data Seeding**: New `seed_mongodb.py` script to populate MongoDB with all existing data

### Flutter Frontend
- **Content Service**: New `lib/services/content_service.dart` for fetching data from API
- **Questionnaire Screen**: Updated to load questions from MongoDB (with fallback to cached values)
- **Syllable Train Game**: Updated to load syllable rounds from MongoDB (with fallback to defaults)

## Setup Instructions

### 1. Install MongoDB

**Windows:**
```bash
# Download from https://www.mongodb.com/try/download/community
# Run the installer and follow the setup wizard
# Or use Chocolatey:
choco install mongodb-community
```

**macOS:**
```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

**Linux (Ubuntu):**
```bash
sudo apt-get install -y mongodb
sudo systemctl start mongodb
```

### 2. Start MongoDB Service
```bash
# Windows
net start MongoDB

# macOS/Linux
brew services start mongodb-community  # or
sudo systemctl start mongodb
```

### 3. Install Python Dependencies

```bash
cd content-service
pip install -r requirements.txt
```

Dependencies installed:
- fastapi==0.100.0
- uvicorn==0.23.0
- pymongo==4.5.0
- python-dotenv==1.0.0
- pydantic==2.0.0
- joblib==1.3.0

### 4. Seed MongoDB with Data

Run the seed script to populate MongoDB with all questionnaire and task data:

```bash
cd content-service
python seed_mongodb.py
```

You should see output like:
```
🌱 Starting MongoDB seed process...
✓ Connected to MongoDB
✓ Questionnaire data seeded
✓ 40 task records seeded

✅ MongoDB seeding completed successfully!
   Total questionnaires: 1
   Total tasks: 40
```

### 5. Start the Backend Service

```bash
cd content-service
python -m uvicorn main:app --reload --port 5000
```

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:5000
INFO:     Application startup complete
```

### 6. Run the Flutter App

```bash
cd dyslexia_app
flutter pub get
flutter run
```

## Data Structure

### Questionnaire Data
The questionnaire is stored as a single document with 3 parts:
- **Part 1**: Weighted assessment questions (14 questions)
- **Part 2**: Reading behavior observations (8 boolean questions)
- **Part 3**: Classroom observations (5 boolean questions)

### Task Data
Tasks are stored individually, organized by type:
- **syllable_train**: Syllable blending exercises (5 tasks)
- **reading_fluency**: Fluency sentences by level (15 tasks)
- **reading_comprehension**: Comprehension tasks with images (9 tasks)
- **drawing_interpretation**: Drawing tasks (5 tasks)
- **word_matching**: Word matching task (1 task)

## Database Connection

### Default Configuration
- **MongoDB URL**: `mongodb://localhost:27017`
- **Database Name**: `dyslexia_content`
- **Backend Port**: `http://127.0.0.1:5000/api`

### Custom Configuration
To use a different MongoDB instance, set environment variables:

```bash
# .env file in content-service/
MONGO_URL=mongodb://your-host:27017
MONGO_DB=your_database_name
```

## Troubleshooting

### MongoDB Connection Failed
```
⚠ MongoDB connection failed: [Errno 111] Connection refused
  Application will continue with local data fallback
```

**Solution**: Make sure MongoDB service is running
```bash
# Check status
mongod --version

# Start service
sudo systemctl start mongodb  # Linux
brew services start mongodb-community  # macOS
net start MongoDB  # Windows
```

### Port Already in Use
If port 5000 is already in use:
```bash
python -m uvicorn main:app --reload --port 8000
```

Then update the `baseUrl` in `content_service.dart`:
```dart
static const String baseUrl = 'http://127.0.0.1:8000/api';
```

### Data Not Loading in Flutter App
1. Check MongoDB service is running
2. Check backend is running and accessible
3. Check the seed script completed successfully
4. Look at app logs for specific error messages

## Content Management

### To Add New Questionnaire Questions

Edit `seed_mongodb.py` and update the questionnaire document:

```python
questionnaire = {
    'category': 'dyslexia_screening',
    'parts': [
        {
            'part_number': 1,
            'questions': [
                {'id': 0, 'question': 'Your question here', 'weight': 10},
                # ... more questions
            ]
        }
    ]
}
```

Then reseed the database:
```bash
python seed_mongodb.py
```

### To Add New Tasks

Add to the `seed_mongodb.py` tasks list:

```python
tasks.append({
    'type': 'your_task_type',
    'level': 1,
    'your_field': 'your_value',
    # ... other fields
})
```

Then reseed the database:
```bash
python seed_mongodb.py
```

## Verification

### Verify MongoDB has Data
```bash
# Open MongoDB shell
mongosh

# Switch to database
use dyslexia_content

# Check questionnaires
db.questionnaires.find()

# Check tasks
db.tasks.find()

# Count documents
db.tasks.countDocuments({type: 'syllable_train'})
```

### Test API Endpoints
```bash
# Get questionnaire
curl http://127.0.0.1:5000/api/questionnaires/dyslexia_screening

# Get syllable train tasks
curl http://127.0.0.1:5000/api/tasks/syllable_train

# Get reading fluency by level
curl http://127.0.0.1:5000/api/tasks/by-level/reading_fluency/1
```

## Fallback Behavior

All screens have built-in fallback mechanisms:

1. **If MongoDB is unavailable**: The app loads data from hardcoded defaults
2. **If API fails**: The app retries with a "Retry" button
3. **Content is never lost**: Even if database fails, app continues with local data

## Modifying Content Without Code Changes

After MongoDB is set up, you can:
1. Modify questions directly in MongoDB
2. Add new tasks by inserting documents
3. Update weights and parameters
4. All changes take effect immediately (no code recompilation needed)

## Future Improvements

- Add MongoDB UI dashboard for easy content management
- Create admin panel for modifying questionnaires
- Add version control for questionnaire changes
- Implement content versioning for A/B testing
- Add audit logs for content modifications

---

**Note**: All existing screen functionality remains unchanged. This migration only changes how data is stored and retrieved, not how it's displayed or used.
