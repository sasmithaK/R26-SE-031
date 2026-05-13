import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dyslexia_app/models/comprehension_progress.dart';
import '../utils/logger.dart';

class ComprehensionService {
  static const String baseUrl = 'http://127.0.0.1:5001/api/v1';

  /// Save or update comprehension progress in MongoDB
  static Future<bool> saveComprehensionProgress(
    ComprehensionProgress progress,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comprehension'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(progress.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      AppLogger.error('Error saving comprehension progress', error: e);
      return false;
    }
  }

  /// Retrieve comprehension progress for a student
  static Future<ComprehensionProgress?> getComprehensionProgress(
    String studentId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comprehension/$studentId'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ComprehensionProgress.fromJson(json);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching comprehension progress', error: e);
      return null;
    }
  }

  /// Update comprehension progress (PUT)
  static Future<bool> updateComprehensionProgress(
    ComprehensionProgress progress,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/comprehension'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(progress.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error updating comprehension progress', error: e);
      return false;
    }
  }

  /// Delete comprehension progress record
  static Future<bool> deleteComprehensionProgress(String studentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/comprehension/$studentId'),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      AppLogger.error('Error deleting comprehension progress', error: e);
      return false;
    }
  }

  /// Get all students in a class
  static Future<List<ComprehensionProgress>> getClassComprehension(
    String classId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comprehension/class/$classId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        return json
            .map((item) => ComprehensionProgress.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching class comprehension data', error: e);
      return [];
    }
  }
}
