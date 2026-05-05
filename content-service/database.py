import sqlite3

DB_PATH = 'content_state.db'

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS mastery (
            student_id TEXT,
            skill_id TEXT,
            mastery_level REAL,
            last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (student_id, skill_id)
        )
    ''')
    conn.commit()
    conn.close()

def update_mastery(student_id: str, skill_id: str, mastery_level: float):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO mastery (student_id, skill_id, mastery_level, last_updated)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(student_id, skill_id) DO UPDATE SET
            mastery_level = excluded.mastery_level,
            last_updated = CURRENT_TIMESTAMP
    ''', (student_id, skill_id, mastery_level))
    conn.commit()
    conn.close()

def get_mastery(student_id: str, skill_id: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT mastery_level FROM mastery WHERE student_id = ? AND skill_id = ?', (student_id, skill_id))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else 0.0

def get_all_mastery(student_id: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT skill_id, mastery_level FROM mastery WHERE student_id = ?', (student_id,))
    results = cursor.fetchall()
    conn.close()
    return {skill: level for skill, level in results}
