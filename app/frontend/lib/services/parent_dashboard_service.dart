import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

class ParentDashboardService {
  final String _baseUrl = ApiConfig.authBaseUrl.replaceFirst('/auth', '/parent/students');

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getOverview(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$studentId/overview'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return _getMockOverview(studentId);
    } catch (e) {
      return _getMockOverview(studentId);
    }
  }

  Future<Map<String, dynamic>> getSkills(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$studentId/skills'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return _getMockSkills(studentId);
    } catch (e) {
      return _getMockSkills(studentId);
    }
  }

  Future<Map<String, dynamic>> getLearningPattern(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$studentId/learning-pattern'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return _getMockLearningPattern(studentId);
    } catch (e) {
      return _getMockLearningPattern(studentId);
    }
  }

  Future<Map<String, dynamic>> getActivityHistory(String studentId, [String filter = "limit=10"]) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$studentId/activity-history?$filter'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return _getMockActivityHistory(studentId);
    } catch (e) {
      return _getMockActivityHistory(studentId);
    }
  }

  Future<Map<String, dynamic>> getAdaptiveInsights(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$studentId/adaptive-insights'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return _getMockAdaptiveInsights(studentId);
    } catch (e) {
      return _getMockAdaptiveInsights(studentId);
    }
  }

  // --- Mocks fallback ---

  Map<String, dynamic> _getMockOverview(String studentId) {
    return {
      "updated_at": DateTime.now().toIso8601String(),
      "accuracy": 82,
      "practice_time_minutes": 25,
      "sessions_completed": 5,
      "current_skill": "Letter Shapes",
      "fatigue_status": "Low",
      "response_speed_status": "Quick"
    };
  }

  Map<String, dynamic> _getMockSkills(String studentId) {
    return {
      "skills": [
        {"skill_name": "Letters", "mastery_percentage": 85, "status": "Mastered"},
        {"skill_name": "Words", "mastery_percentage": 50, "status": "Progressing"}
      ]
    };
  }

  Map<String, dynamic> _getMockLearningPattern(String studentId) {
    return {
      "primary_learning_pattern": "Visual-Letter Learning Pattern",
      "confidence_level": "Moderate",
      "supporting_observations": [
        "Repeated similar-letter errors",
      ],
      "recommended_practice": "Practice visual differences."
    };
  }

  Map<String, dynamic> _getMockActivityHistory(String studentId) {
    return {
      "history": [
        {"session_date": "2026-08-28", "activity_name": "Game 1", "accuracy": 80, "duration_minutes": 10}
      ]
    };
  }

  Map<String, dynamic> _getMockAdaptiveInsights(String studentId) {
    return {
      "updated_at": DateTime.now().toIso8601String(),
      "student_id": studentId,
      "reporting_period": "All Time",
      "activities": []
    };
  }
}
