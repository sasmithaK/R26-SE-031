import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SkipService {
  static const String baseUrl = 'http://127.0.0.1:5001/api/v1';

  /// Record a skip event for the current student and task by inserting
  /// a task score document with a numeric `skip_count` field.
  static Future<bool> recordSkip({
    String? studentId,
    required String taskId,
    required String taskName,
    required String sessionId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sid = studentId ?? prefs.getString('student_id') ?? 'unknown_student';

      final payload = {
        'student_id': sid,
        'session_id': sessionId,
        'task_id': taskId,
        'task_name': taskName,
        'score': 0.0,
        'max_score': 0.0,
        'duration_seconds': 0.0,
        'skip_count': 1,
        'metadata': {'skip': true},
      };

      final resp = await http.post(
        Uri.parse('$baseUrl/scores/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      print('Error recording skip: $e');
      return false;
    }
  }
}
