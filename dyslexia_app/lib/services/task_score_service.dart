import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../utils/logger.dart';

class TaskScoreService {
  // static const String baseUrl = ApiConfig.monitoringUrl;
  static const String baseUrl = 'http://127.0.0.1:5001/api/v1';

  /// Send telemetry payload to C1 Monitoring Service
  static Future<Map<String, dynamic>?> sendTelemetry(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/telemetry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      AppLogger.error('Failed to send telemetry: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Error sending telemetry: $e');
      return null;
    }
  }

  /// Get the latest MBSV for a student
  static Future<Map<String, dynamic>?> getLatestMBSV(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mbsv/$studentId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching MBSV: $e');
      return null;
    }
  }

  /// Legacy: Save a generic task score
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

      // Re-routing to legacy if still needed, or monitoring service fallback
      final response = await http.post(
        Uri.parse('${ApiConfig.legacyBaseUrl}/scores/save'), // Assuming legacy path
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      AppLogger.error('Error saving task score: $e');
      return false;
    }
  }
}
