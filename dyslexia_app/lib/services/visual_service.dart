import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/visual_config.dart';
import 'task_score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class VisualService {
  static const String baseUrl = ApiConfig.visualUrl;

  /// High-level helper to fetch typography based on current student state
  /// Returns a Map with 'response' (TypographyResponse) and 'visualStrain' (double)
  static Future<Map<String, dynamic>?> getAdaptiveTypography(String gameType, {String? sessionId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString('student_id') ?? 'student_demo';
      final activeSessionId = sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Get latest behavioral state (MBSV) from Monitoring Service
      final mbsvData = await TaskScoreService.getLatestMBSV(studentId);
      double visualStrain = 0.5;
      double engagement = 0.5;

      if (mbsvData != null && mbsvData['mbsv'] != null) {
        visualStrain = (mbsvData['mbsv']['visual_strain_index'] as num).toDouble();
        engagement = (mbsvData['mbsv']['engagement_index'] as num).toDouble();
      }

      // 2. Get adaptive typography from Visual Service (LinUCB Agent)
      final response = await getTypographyConfig(
        studentId: studentId,
        sessionId: activeSessionId,
        visualStrain: visualStrain,
        engagement: engagement,
        contentText: gameType,
      );

      if (response == null) return null;

      return {
        'response': response,
        'visualStrain': visualStrain,
      };
    } catch (e) {
      AppLogger.error('❌ VisualService helper error', error: e);
      return null;
    }
  }

  /// Get adaptive typography config from C2 Visual Service
  static Future<TypographyResponse?> getTypographyConfig({
    required String studentId,
    required String sessionId,
    required double visualStrain,
    required double engagement,
    double phonologicalStrain = 0.0,
    String? contentText,
  }) async {
    try {
      final payload = {
        'student_id': studentId,
        'session_id': sessionId,
        'visual_strain_index': visualStrain,
        'engagement_index': engagement,
        'phonological_strain_index': phonologicalStrain,
        'current_content_text': contentText,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ui/typography'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return TypographyResponse.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error fetching typography', error: e);
      return null;
    }
  }

  /// Send reward/feedback to C2 to update Multi-Armed Bandit (LinUCB)
  static Future<bool> sendReward({
    required String studentId,
    required String sessionId,
    required int armId,
    required double strainBefore,
    required double strainAfter,
    double accuracyDelta = 0.0,
  }) async {
    try {
      final payload = {
        'student_id': studentId,
        'session_id': sessionId,
        'arm_id': armId,
        'visual_strain_before': strainBefore,
        'visual_strain_after': strainAfter,
        'reading_accuracy_delta': accuracyDelta,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ui/reward'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('❌ Error sending reward', error: e);
      return false;
    }
  }
}
