import 'dart:convert';
import 'package:http/http.dart' as http;

class ScoreService {
  static const String _baseUrl = 'http://127.0.0.1:8004';

  static Future<void> saveTaskScore({
    required String studentId,
    required String taskId,
    required String taskName,
    required double score,
    double? maxScore,
    double? durationSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/scores/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'task_id': taskId,
          'task_name': taskName,
          'score': score,
          'max_score': maxScore,
          'duration_seconds': durationSeconds,
          'metadata': metadata,
        }),
      );
    } catch (_) {
      // Keep the game flow uninterrupted if the backend is unavailable.
    }
  }
}