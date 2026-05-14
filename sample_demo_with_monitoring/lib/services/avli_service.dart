import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mbsv.dart';
import '../models/typography_config.dart';

class AVLIService {
  final String baseUrl = "http://127.0.0.1:8014/api/v1";

  Future<TypographyResponse> getTypography({
    required String studentId,
    required MBSV mbsv,
    required Map<String, dynamic> context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ui/typography'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'session_id': context['session_id'] ?? 'SESSION_${DateTime.now().millisecondsSinceEpoch}',
          'session_number': context['session_number'] ?? 1,
          'visual_strain_index': mbsv.visualStrainIndex,
          'engagement_index': mbsv.engagementIndex,
          'phonological_strain_index': mbsv.phonologicalStrainIndex,
          'current_content_text': context['current_content_text'] ?? '',
          'child_age_years': context['child_age_years'] ?? 7,
        }),
      );

      if (response.statusCode == 200) {
        return TypographyResponse.fromJson(jsonDecode(response.body));
      } else {
        print('Error from C2 (${response.statusCode}): ${response.body}');
        return TypographyResponse(
          studentId: studentId,
          armId: 0,
          config: TypographyConfig.defaultConfig(),
          gameModeTrigger: false,
        );
      }
    } catch (e) {
      print('Failed to connect to Visual Service (C2): $e');
      return TypographyResponse(
        studentId: studentId,
        armId: 0,
        config: TypographyConfig.defaultConfig(),
        gameModeTrigger: false,
      );
    }
  }

  Future<void> sendReward({
    required String studentId,
    required int armId,
    required double reward,
    required double visualStrainBefore,
    required double visualStrainAfter,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ui/reward'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'session_id': 'DEMO_SESSION',
          'arm_id': armId,
          'visual_strain_before': visualStrainBefore,
          'visual_strain_after': visualStrainAfter,
          'reading_accuracy_delta': reward,
        }),
      );
      if (response.statusCode != 200) {
        print('Error sending reward to C2 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('Failed to send reward to C2: $e');
    }
  }
}

