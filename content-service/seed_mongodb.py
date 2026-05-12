"""
Script to seed MongoDB with all questionnaire and task data
This preserves all existing content exactly as it is in the Flutter app
"""

from pymongo import MongoClient
import os

# MongoDB Configuration
MONGO_URL = os.getenv('MONGO_URL', 'mongodb://localhost:27017')
MONGO_DB = os.getenv('MONGO_DB', 'dyslexia_content')


def connect_mongo():
    """Connect to MongoDB"""
    client = MongoClient(MONGO_URL)
    db = client[MONGO_DB]
    return client, db


def seed_questionnaires(db):
    """Seed questionnaire data"""
    # Clear existing data
    db['questionnaires'].delete_many({})
    
    questionnaire = {
        'category': 'dyslexia_screening',
        'title': 'Dyslexia Screening Questionnaire',
        'parts': [
            {
                'part_number': 1,
                'title': 'Part One - Scores',
                'description': 'Weighted assessment questions',
                'questions': [
                    {'id': 0, 'question': 'වම සහ දකුණ වෙන්කර හඳුනා ගැනීමට අපහසු ද?', 'weight': 10},
                    {'id': 1, 'question': 'කියවීමේදී ඉක්මනින් තෙහෙට්ටුව දැනෙනවා ද?', 'weight': 10},
                    {'id': 2, 'question': 'කියවද්දී සිත වෙනත් දෙයක් වෙත යාම නිතර සිදුවේද?', 'weight': 10},
                    {'id': 3, 'question': 'කියවීමේදී වැරදි බොහෝවිට සිදුවේද?', 'weight': 20},
                    {'id': 4, 'question': 'අවධානය රඳවා ගැනීමට අපහසු ද?', 'weight': 20},
                    {'id': 5, 'question': 'නම් මතක තබා ගැනීමට අපහසු ද?', 'weight': 20},
                    {'id': 6, 'question': 'කතා කරන විට වචන නිවැරදිව උච්චාරණයට අපහසු ද?', 'weight': 10},
                    {'id': 7, 'question': 'ඔබ දන්නා කෙටි වචනවල අක්ෂර වින්යාසය අමතක වනවා ද?', 'weight': 20},
                    {'id': 8, 'question': 'පෙර ලියවී නොදුටු වචනවල අක්ෂර වින්යාසය අපහසු ද?', 'weight': 30},
                    {'id': 9, 'question': 'හුරු නැති වචන කියවීමට අපහසු ද?', 'weight': 30},
                    {'id': 10, 'question': 'ලියන්න බැරි නමුත් භාවිතා කරන විශාල වචන තේරුම් ගන්නවා ද?', 'weight': 20},
                    {'id': 11, 'question': 'කියවිය නොහැකි වචනවලදී නවතිනවා ද?', 'weight': 10},
                    {'id': 12, 'question': 'කියවීමේදී ඇස් සම්බන්ධීකරණය අඩු වගේ දැනෙනවා ද?', 'weight': 10},
                    {'id': 13, 'question': 'කියවීමේදී වචන හලනවා/අඳුරු/අවධානයට ගන්න අපහසු වගේ පෙනේද?', 'weight': 30},
                ]
            },
            {
                'part_number': 2,
                'title': 'Part Two - Reading Behaviors',
                'description': 'Boolean assessment of reading behaviors',
                'questions': [
                    {'id': 0, 'question': 'දරුවා කියවීම සම්බන්ධ ක්‍රියාකාරකම්වලින් වැළකී සිටීමට උත්සාහ කරනවාද?'},
                    {'id': 1, 'question': 'දරුවා තම පන්තියේ අනෙකුත් දරුවන්ට වඩා මන්දගාමීව කියවනවාද?'},
                    {'id': 2, 'question': 'දරුවා කියවීමේදී වචන මඟහැර යනවාද?'},
                    {'id': 3, 'question': 'දරුවා කියවීමේදී තමන් කියවමින් සිටින ස්ථානය අහිමි කරගන්නවාද?'},
                    {'id': 4, 'question': 'දරුවා වචනය සම්පූර්ණයෙන් කියවීම වෙනුවට අනුමාන කරමින් කියවීමට උත්සාහ කරනවාද?'},
                    {'id': 5, 'question': 'දරුවා නව හෝ නොහුරු වචන කියවීමට අපහසුතාවයක් දක්වනවාද?'},
                    {'id': 6, 'question': 'දරුවා වාක්‍යයක් තේරුම් ගැනීම සඳහා නැවත නැවත කියවීමට අවශ්‍ය වනවාද?'},
                    {'id': 7, 'question': 'දරුවා ටික වේලාවක් කියවීමෙන් පසු ඉක්මනින් වෙහෙසට පත්වනවාද?'},
                ]
            },
            {
                'part_number': 3,
                'title': 'Part Three - Academic Classroom Observation',
                'description': 'Boolean assessment of classroom observations',
                'questions': [
                    {'id': 0, 'question': 'ලිඛිතව ලබාදෙන තොරතුරු වලට වඩා කථනය මඟින් ලබාදෙන තොරතුරු දරුවාට වඩා හොඳින් අවබෝධ කරගත හැකිද?'},
                    {'id': 1, 'question': 'දරුවා කථන ක්‍රියාකාරකම්වල හොඳින් සහභාගී වන නමුත් ලිඛිත කාර්යයන්හි අපහසුතා පෙන්වනවාද?'},
                    {'id': 2, 'question': 'කියවීම සම්බන්ධ කාර්යයන් සම්පූර්ණ කිරීමට දරුවා අනෙකුත් දරුවන්ට වඩා වැඩි කාලයක් ගන්නවාද?'},
                    {'id': 3, 'question': 'දරුවා ශබ්ද නගා කියවීමෙන් වැළකී සිටීමට උත්සාහ කරනවාද?'},
                    {'id': 4, 'question': 'කියවීම හෝ ලිවීම සම්බන්ධ අධ්‍යයන ක්‍රියාකාරකම්වලදී දරුවා කලකිරීම, ආතිය හෝ අසහනය පෙන්වනවාද?'},




                ]
            }
        ]
    }
    
    db['questionnaires'].insert_one(questionnaire)
    print("✓ Questionnaire data seeded")


def seed_tasks(db):
    """Seed all task data"""
    # Clear existing data
    db['tasks'].delete_many({})
    
    tasks = []
    
    # 1. Syllable Training Tasks
    syllable_rounds = [
        {
            'type': 'syllable_train',
            'level': 1,
            'word': 'මල',
            'carriages': ['ම', 'ල'],
            'trainColors': ['#FF8A80', '#80D8FF'],
        },
        {
            'type': 'syllable_train',
            'level': 2,
            'word': 'ගස',
            'carriages': ['ග', 'ස'],
            'trainColors': ['#A5D6A7', '#FFCC80'],
        },
        {
            'type': 'syllable_train',
            'level': 3,
            'word': 'ගෙය',
            'carriages': ['ගෙ', 'ය'],
            'trainColors': ['#B39DDB', '#81D4FA'],
        },
        {
            'type': 'syllable_train',
            'level': 4,
            'word': 'අම්මා',
            'carriages': ['අ', 'ම්', 'මා'],
            'trainColors': ['#FFAB91', '#CE93D8', '#FFAB91'],
        },
        {
            'type': 'syllable_train',
            'level': 5,
            'word': 'පාසල',
            'carriages': ['පා', 'ස', 'ල'],
            'trainColors': ['#80CBC4', '#FFF59D', '#FFAB91'],
        },
    ]
    tasks.extend(syllable_rounds)
    
    # 2. Reading Fluency Sentences by Level
    reading_fluency_sentences = [
        # Level 1
        {'type': 'reading_fluency', 'level': 1, 'sentence': 'බල්ලා දුවයි'},
        {'type': 'reading_fluency', 'level': 1, 'sentence': 'අම්මා එයි.'},
        {'type': 'reading_fluency', 'level': 1, 'sentence': 'මල් පිපේ.'},
        {'type': 'reading_fluency', 'level': 1, 'sentence': 'ගෙදර තියනවා.'},
        {'type': 'reading_fluency', 'level': 1, 'sentence': 'සිසුන් කියවයි.'},
        # Level 2
        {'type': 'reading_fluency', 'level': 2, 'sentence': 'මල් වත්ත ලස්සනයි.'},
        {'type': 'reading_fluency', 'level': 2, 'sentence': 'අම්මා කෑම පිසියි.'},
        {'type': 'reading_fluency', 'level': 2, 'sentence': 'අපි පාසලට යමු.'},
        {'type': 'reading_fluency', 'level': 2, 'sentence': 'නංගී පොත කියවයි.'},
        {'type': 'reading_fluency', 'level': 2, 'sentence': 'තාත්තා වැඩ කරයි.'},
        # Level 3
        {'type': 'reading_fluency', 'level': 3, 'sentence': 'ගෙදර ළඟ ගසක් තිබේ.'},
        {'type': 'reading_fluency', 'level': 3, 'sentence': 'අපි උදේ පාසලට යමු.'},
        {'type': 'reading_fluency', 'level': 3, 'sentence': 'නංගී ලස්සන මලක් අඳියි.'},
        {'type': 'reading_fluency', 'level': 3, 'sentence': 'අම්මා කෑම පිසිනවා.'},
        {'type': 'reading_fluency', 'level': 3, 'sentence': 'ගුරුවරයා පාඩම උගන්වයි.'},
    ]
    tasks.extend(reading_fluency_sentences)
    
    # 3. Drawing Interpretation Sentences
    drawing_tasks = [
        {'type': 'drawing_interpretation', 'index': 0, 'sentence': 'මල් පිපීලා තියෙනවා.'},
        {'type': 'drawing_interpretation', 'index': 1, 'sentence': 'ඉර එළිය තියෙනවා'},
        {'type': 'drawing_interpretation', 'index': 2, 'sentence': 'කුරුල්ලෝ පියාඹනවා.'},
        {'type': 'drawing_interpretation', 'index': 3, 'sentence': 'අම්මා බත් උයනවා.'},
        {'type': 'drawing_interpretation', 'index': 4, 'sentence': 'තාත්තා වැඩට යනවා'},
    ]
    tasks.extend(drawing_tasks)
    
    # 4. Word Matching Task
    word_matching = {
        'type': 'word_matching',
        'target_word': 'ගහ',
        'image_path': 'assets/images/tree_character.png',
        'options': ['මල', 'ගහ', 'කොළය', 'පලතුර'],
    }
    tasks.append(word_matching)
    
    # 5. Reading Comprehension Tasks by Level
    comprehension_tasks = [
        # Level 1
        {
            'type': 'reading_comprehension',
            'level': 1,
            'sentence': 'බල්ලා දුවනවා.',
            'correct_image_index': 2,
            'images': ['assets/images/sitdog.jpg', 'assets/images/sleepingDog.jpg', 'assets/images/DogRunning.jpg'],
        },
        {
            'type': 'reading_comprehension',
            'level': 1,
            'sentence': 'මල් පිපේ.',
            'correct_image_index': 0,
            'images': ['assets/images/flowerr.jpg', 'assets/images/tree1.jpg', 'assets/images/bird.jpg'],
        },
        {
            'type': 'reading_comprehension',
            'level': 1,
            'sentence': 'අම්මා එයි.',
            'correct_image_index': 0,
            'images': ['assets/images/mother.jpg', 'assets/images/father4.jpg', 'assets/images/grandmother.jpg'],
        },
        # Level 2
        {
            'type': 'reading_comprehension',
            'level': 2,
            'sentence': 'ගෙදර ළඟ ගසක් තිබේ.',
            'correct_image_index': 0,
            'images': ['assets/images/road.jpg', 'assets/images/housetree.jpg', 'assets/images/river.jpg'],
        },
        {
            'type': 'reading_comprehension',
            'level': 2,
            'sentence': 'අපි පාසලට යමු.',
            'correct_image_index': 0,
            'images': ['assets/images/ball.jpg', 'assets/images/play.jpg', 'assets/images/school.jpg'],
        },
        {
            'type': 'reading_comprehension',
            'level': 2,
            'sentence': 'ගුරුවරයා පොත කියවනවා.',
            'correct_image_index': 0,
            'images': ['assets/images/sing.jpg', 'assets/images/teach.jpg', 'assets/images/batta.jpg'],
        },
        # Level 3
        {
            'type': 'reading_comprehension',
            'level': 3,
            'sentence': 'ළමයා ගෙදර ගොස් කෑම කෑවා.',
            'correct_image_index': 0,
            'images': ['assets/images/childcook.jpg', 'assets/images/tv.jpg', 'assets/images/fameat.jpg'],
        },
        {
            'type': 'reading_comprehension',
            'level': 3,
            'sentence': 'අම්මා කෑම හදානවා.',
            'correct_image_index': 0,
            'images': ['assets/images/backer.jpg', 'assets/images/macook.jpg', 'assets/images/grandmacook.jpg'],
        },
        {
            'type': 'reading_comprehension',
            'level': 3,
            'sentence': 'ගස් වලින් පලතුරු වැටෙනවා.',
            'correct_image_index': 0,
            'images': ['assets/images/fruitree.jpg', 'assets/images/grocerry.jpg', 'assets/images/share.jpg'],
        },
    ]
    tasks.extend(comprehension_tasks)
    
    # Insert all tasks
    db['tasks'].insert_many(tasks)
    print(f"✓ {len(tasks)} task records seeded")


def main():
    """Main seed function"""
    print("🌱 Starting MongoDB seed process...")
    
    try:
        client, db = connect_mongo()
        print("✓ Connected to MongoDB")
        
        seed_questionnaires(db)
        seed_tasks(db)
        
        print("\n✅ MongoDB seeding completed successfully!")
        print(f"   Total questionnaires: {db['questionnaires'].count_documents({})}")
        print(f"   Total tasks: {db['tasks'].count_documents({})}")
        
        client.close()
        
    except Exception as e:
        print(f"❌ Error during seeding: {e}")
        raise


if __name__ == '__main__':
    main()
