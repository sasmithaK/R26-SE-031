import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class QuestionnaireDb {
  QuestionnaireDb._();

  static final QuestionnaireDb instance = QuestionnaireDb._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, 'questionnaire_records.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE questionnaire_submissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            respondent_role TEXT NOT NULL,
            respondent_name TEXT NOT NULL,
            student_name TEXT NOT NULL,
            student_age INTEGER NOT NULL,
            student_grade TEXT NOT NULL,
            part_one_score INTEGER NOT NULL,
            risk_level TEXT NOT NULL,
            part_two_count INTEGER NOT NULL,
            part_three_count INTEGER NOT NULL DEFAULT 0,
            part_one_answers TEXT NOT NULL,
            part_two_answers TEXT NOT NULL,
            part_three_answers TEXT NOT NULL DEFAULT '{}'
          )
        ''');
      },
    );
  }

  Future<int> insertSubmission({
    required String respondentRole,
    required String respondentName,
    required String studentName,
    required int studentAge,
    required String studentGrade,
    required int partOneScore,
    required String riskLevel,
    required int partTwoCount,
    required int partThreeCount,
    required Map<int, int> partOneAnswers,
    required Map<int, bool?> partTwoAnswers,
    required Map<int, bool?> partThreeAnswers,
  }) async {
    final db = await database;

    final normalizedPartTwoAnswers = <int, bool>{};
    partTwoAnswers.forEach((key, value) {
      normalizedPartTwoAnswers[key] = value ?? false;
    });

    final normalizedPartThreeAnswers = <int, bool>{};
    partThreeAnswers.forEach((key, value) {
      normalizedPartThreeAnswers[key] = value ?? false;
    });

    return db.insert(
      'questionnaire_submissions',
      {
        'created_at': DateTime.now().toIso8601String(),
        'respondent_role': respondentRole,
        'respondent_name': respondentName,
        'student_name': studentName,
        'student_age': studentAge,
        'student_grade': studentGrade,
        'part_one_score': partOneScore,
        'risk_level': riskLevel,
        'part_two_count': partTwoCount,
        'part_three_count': partThreeCount,
        'part_one_answers': jsonEncode(partOneAnswers),
        'part_two_answers': jsonEncode(normalizedPartTwoAnswers),
        'part_three_answers': jsonEncode(normalizedPartThreeAnswers),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAllSubmissions() async {
    final db = await database;
    return db.query(
      'questionnaire_submissions',
      orderBy: 'datetime(created_at) DESC',
    );
  }
}
