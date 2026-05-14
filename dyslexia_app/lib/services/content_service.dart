import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../utils/logger.dart';

class ContentService {
  static const String baseUrl = ApiConfig.contentUrl;

  /// Fetch the next content item for a student (ZPD + BKT)
  static Future<Map<String, dynamic>?> getNextContent(String studentId, {double cognitiveLoad = 0.5, double fatigue = 0.0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/next/$studentId?cognitive_load_index=$cognitiveLoad&session_fatigue_index=$fatigue'),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      AppLogger.error('Failed to fetch next content: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Error fetching next content: $e');
      return null;
    }
  }

  /// Update student mastery (BKT)
  static Future<Map<String, dynamic>?> updateMastery({
    required String studentId,
    required String sessionId,
    required String skillId,
    required bool isCorrect,
    required int responseLatencyMs,
    double cognitiveLoad = 0.5,
    double fatigue = 0.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mastery/update'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'session_id': sessionId,
          'skill_id': skillId,
          'is_correct': isCorrect,
          'response_latency_ms': responseLatencyMs,
          'cognitive_load_index': cognitiveLoad,
          'session_fatigue_index': fatigue,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      AppLogger.error('Failed to update mastery: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Error updating mastery: $e');
      return null;
    }
  }

  /// Initialize BKT for a new student
  static Future<bool> initializeStudent(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/students/initialize?student_id=$studentId'),
        headers: const {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error initializing student: $e');
      return false;
    }
  }

  /// Legacy methods (Keeping for compatibility but re-routing if possible)
  static Future<Map<String, dynamic>?> getQuestionnaire(String category) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.legacyBaseUrl}/questionnaires/$category'),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getTasksByType(String taskType) async {
    // Re-routing to ZPD content if applicable, else legacy
    // For now, returning null to force developers to use getNextContent
    AppLogger.warning('Legacy getTasksByType called. Use getNextContent for V2.');
    return null; 
  }
}
