import 'dart:convert';

import 'package:http/http.dart' as http;

class QuestionnaireDb {
  QuestionnaireDb._();

  static final QuestionnaireDb instance = QuestionnaireDb._();

  static const String baseUrl = 'http://127.0.0.1:5000/api';

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
    final normalizedPartOneAnswers = <String, int>{};
    partOneAnswers.forEach((key, value) {
      normalizedPartOneAnswers[key.toString()] = value;
    });

    final normalizedPartTwoAnswers = <String, bool>{};
    partTwoAnswers.forEach((key, value) {
      normalizedPartTwoAnswers[key.toString()] = value ?? false;
    });

    final normalizedPartThreeAnswers = <String, bool>{};
    partThreeAnswers.forEach((key, value) {
      normalizedPartThreeAnswers[key.toString()] = value ?? false;
    });

    final payload = {
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
      'part_one_answers': normalizedPartOneAnswers,
      'part_two_answers': normalizedPartTwoAnswers,
      'part_three_answers': normalizedPartThreeAnswers,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/questionnaire'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return 1;
    }

    throw Exception('Failed to save questionnaire submission: ${response.statusCode} ${response.body}');
  }

  Future<List<Map<String, dynamic>>> fetchAllSubmissions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/questionnaire'),
      headers: const {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load questionnaire submissions: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }

    if (decoded is Map<String, dynamic> && decoded['submissions'] is List) {
      return (decoded['submissions'] as List).cast<Map<String, dynamic>>();
    }

    return const <Map<String, dynamic>>[];
  }
}
