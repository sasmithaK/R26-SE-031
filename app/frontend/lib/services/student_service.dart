import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';

/// Handles all student-related API calls.
/// Separated from AuthService for clean architecture.
class StudentService {
  static String get _baseUrl {
    return ApiConfig.authBaseUrl;
  }

  static String get _telemetryBaseUrl {
    return ApiConfig.telemetryBaseUrl;
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Add a student under the current parent.
  /// Returns a Map with student data on success (including 'id'), or a Map with 'error' key on failure.
  Future<Map<String, dynamic>> addStudent(Map<String, dynamic> studentData) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return {'error': 'Not authenticated.'};

      final response = await http.post(
        Uri.parse('$_baseUrl/students'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(studentData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return {'error': data['detail']};
        } else if (data['detail'] is List) {
          final err = data['detail'][0];
          final field = err['loc']?.last?.toString() ?? 'Field';
          return {'error': '$field: ${err["msg"]}'};
        }
        return {'error': 'Failed to add student.'};
      }
    } catch (e) {
      return {'error': 'Failed to connect to the server.'};
    }
  }

  /// Get list of students for the current authenticated parent.
  /// Returns only students belonging to this parent (server-enforced).
  Future<List<dynamic>> getStudents() async {
    try {
      final token = await _getAccessToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/students'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final students = jsonDecode(response.body) as List<dynamic>;
        // Cache the students for instant loading next time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_students_list', jsonEncode(students));
        return students;
      }
      return await getCachedStudents();
    } catch (e) {
      // Fallback to cache on network error or timeout
      return await getCachedStudents();
    }
  }

  /// Get students from local cache for instant UI rendering
  Future<List<dynamic>> getCachedStudents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_students_list');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        return jsonDecode(cachedStr) as List<dynamic>;
      }
    } catch (e) {
      // Ignore cache errors
    }
    return [];
  }

  /// Update an existing student's details.
  /// Returns null on success, or an error message string on failure.
  Future<String?> updateStudent(String studentId, Map<String, dynamic> studentData) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.put(
        Uri.parse('$_baseUrl/students/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(studentData),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        } else if (data['detail'] is List) {
          final err = data['detail'][0];
          final field = err['loc']?.last?.toString() ?? 'Field';
          return '$field: ${err['msg']}';
        }
        return 'Failed to update student.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }

  /// Delete a student account.
  /// Returns null on success, or an error message string on failure.
  Future<String?> deleteStudent(String studentId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.delete(
        Uri.parse('$_baseUrl/students/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Failed to delete student.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }

  /// Submit assessment results for an existing student.
  /// Returns null on success, or an error message string on failure.
  Future<String?> submitAssessment(String studentId, List<bool> assessmentResults) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.patch(
        Uri.parse('$_baseUrl/students/$studentId/assessment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'assessment_results': assessmentResults}),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Failed to submit assessment.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }

  /// Submit comprehensive assessment results for a specific category.
  /// Returns null on success, or an error message string on failure.
  Future<String?> submitComprehensiveAssessment(String studentId, String category, List<bool> assessmentResults) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.patch(
        Uri.parse('$_baseUrl/students/$studentId/comprehensive-assessment/$category'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'assessment_results': assessmentResults}),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Failed to submit comprehensive assessment.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }

  /// Sync progress data to the backend for an existing student.
  /// Returns null on success, or an error message string on failure.
  Future<String?> syncProgress(String studentId, List<String> completedActivities, Map<String, int> activityScores) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.patch(
        Uri.parse('$_baseUrl/students/$studentId/progress'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'completed_activities': completedActivities,
          'activity_scores': activityScores,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Failed to sync progress.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }

  /// Submit telemetry session data to the backend.
  /// Returns null on success, or an error message string on failure.
  Future<String?> submitTelemetry(Map<String, dynamic> payload) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.post(
        Uri.parse('$_telemetryBaseUrl/telemetry'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Failed to submit telemetry.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }

  /// Fetch raw telemetry session history for a student.
  Future<List<dynamic>> getTelemetry(String studentId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_telemetryBaseUrl/telemetry/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch the ML-generated cognitive analytics profile for a student.
  ///
  /// Returns a Map with cognitive indices, risk assessment, and
  /// intervention recommendations on success, or an empty Map on failure.
  ///
  /// Accessible by: parent (who owns the student) or a connected specialist.
  Future<Map<String, dynamic>> getCognitiveAnalytics(String studentId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return {};

      final response = await http.get(
        Uri.parse('$_telemetryBaseUrl/telemetry/$studentId/analytics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Download the PDF Clinical Report
  Future<String?> downloadClinicalReport(String studentId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.get(
        Uri.parse('$_telemetryBaseUrl/telemetry/$studentId/report/pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Clinical_Report_$studentId.pdf');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Clinical Report');
        return null;
      } else {
        return 'Failed to download report: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error downloading report: $e';
    }
  }

  /// Download the PDF Assessment Report
  Future<String?> downloadAssessmentReport(String studentId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.get(
        Uri.parse('$_telemetryBaseUrl/students/$studentId/assessment/report/pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Assessment_Report_$studentId.pdf');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Comprehensive Assessment Report');
        return null;
      } else {
        return 'Failed to download assessment report: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error downloading assessment report: $e';
    }
  }

  /// Submit a clinical ground-truth label for a student to train ML models.
  Future<String?> submitClinicianLabel(String studentId, String label) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.post(
        Uri.parse('$_telemetryBaseUrl/ml/label/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'label': label}),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Failed to submit clinical label.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }
}
