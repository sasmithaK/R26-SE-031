import 'dart:convert';
import 'package:http/http.dart' as http;

class ContentService {
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  /// Fetch questionnaire data by category
  static Future<Map<String, dynamic>?> getQuestionnaire(String category) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/questionnaires/$category'),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      print('❌ Failed to fetch questionnaire: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error fetching questionnaire: $e');
      return null;
    }
  }

  /// Fetch all tasks of a specific type
  static Future<List<Map<String, dynamic>>?> getTasksByType(String taskType) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/$taskType'),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['tasks'] as List).cast<Map<String, dynamic>>();
      }
      print('❌ Failed to fetch tasks: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error fetching tasks: $e');
      return null;
    }
  }

  /// Fetch tasks by type and level
  static Future<List<Map<String, dynamic>>?> getTasksByLevel(
    String taskType,
    int level,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/by-level/$taskType/$level'),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['tasks'] as List).cast<Map<String, dynamic>>();
      }
      print('❌ Failed to fetch tasks by level: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error fetching tasks by level: $e');
      return null;
    }
  }
}
