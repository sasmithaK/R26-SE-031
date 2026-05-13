import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dyslexia_app/models/letter_identification_score.dart';
import '../utils/logger.dart';

class LetterIdentificationService {
  // Replace with your backend API base URL
  static const String baseUrl = 'http://localhost:8004/api/v1';

  /// Save a single letter identification score to MongoDB.
  static Future<bool> saveLetterScore(LetterIdentificationScore score) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/letter-identification/score'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(score.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        AppLogger.error('Failed to save letter score: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error saving letter score: $e');
      return false;
    }
  }

  /// Save an entire session to MongoDB.
  static Future<bool> saveSession(LetterIdentificationSession session) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/letter-identification/session'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(session.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        AppLogger.error('Failed to save letter session: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error saving letter session: $e');
      return false;
    }
  }

  /// Get scores for a specific student and letter.
  static Future<List<LetterIdentificationScore>?> getScoresForLetter(
    String studentId,
    String letter,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/letter-identification/student/$studentId/letter/$letter'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scores = (data['scores'] as List)
            .map((s) => LetterIdentificationScore.fromJson(s))
            .toList();
        return scores;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        AppLogger.error('Failed to retrieve scores: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error retrieving scores: $e');
      return null;
    }
  }

  /// Get all scores for a student.
  static Future<List<LetterIdentificationScore>?> getScoresForStudent(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/letter-identification/student/$studentId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scores = (data['scores'] as List)
            .map((s) => LetterIdentificationScore.fromJson(s))
            .toList();
        return scores;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        AppLogger.error('Failed to retrieve student scores: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error retrieving student scores: $e');
      return null;
    }
  }

  /// Get overall statistics for a student.
  static Future<Map<String, dynamic>?> getStudentStatistics(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/letter-identification/student/$studentId/statistics'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        AppLogger.error('Failed to retrieve statistics: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error retrieving statistics: $e');
      return null;
    }
  }
}
