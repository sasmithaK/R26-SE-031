import 'dart:convert';
import 'package:http/http.dart' as http;

class TaskScoreService {
  static const String baseUrl = 'http://localhost:5000/api';

  /// Save a generic task score to the backend which records it to MongoDB.
  static Future<bool> saveTaskScore({
    required String studentId,
    String? taskId,
    required String taskName,
    required double score,
    double? maxScore,
    double? durationSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final payload = {
        'student_id': studentId,
        'task_id': taskId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'task_name': taskName,
        'score': score,
        'max_score': maxScore,
        'duration_seconds': durationSeconds,
        'metadata': metadata ?? {},
      };

      final response = await http.post(
        Uri.parse('\$baseUrl/task-score'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error saving task score: $e');
      return false;
    }
  }
}
