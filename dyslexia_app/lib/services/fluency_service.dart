import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dyslexia_app/models/fluency_progress.dart';
import '../utils/logger.dart';

class FluencyService {
  // Replace with your backend API base URL
  static const String baseUrl = 'http://127.0.0.1:5001/api/v1';

  /// Save or update fluency progress to MongoDB via backend API.
  static Future<bool> saveFluencyProgress(FluencyProgress progress) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fluency'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(progress.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        AppLogger.error('Failed to save fluency progress: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error saving fluency progress: $e');
      return false;
    }
  }

  /// Retrieve fluency progress for a student from MongoDB via backend API.
  static Future<FluencyProgress?> getFluencyProgress(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fluency/$studentId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return FluencyProgress.fromJson(json);
      } else if (response.statusCode == 404) {
        // New student, no record yet
        return null;
      } else {
        AppLogger.error('Failed to retrieve fluency progress: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error retrieving fluency progress: $e');
      return null;
    }
  }

  /// Update fluency progress for a student.
  static Future<bool> updateFluencyProgress(FluencyProgress progress) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/fluency/${progress.studentId}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(progress.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        AppLogger.error('Failed to update fluency progress: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error updating fluency progress: $e');
      return false;
    }
  }

  /// Delete fluency progress for a student (optional).
  static Future<bool> deleteFluencyProgress(String studentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/fluency/$studentId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        AppLogger.error('Failed to delete fluency progress: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error deleting fluency progress: $e');
      return false;
    }
  }
}
