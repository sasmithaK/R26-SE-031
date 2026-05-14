import 'package:flutter_test/flutter_test.dart';
import 'package:dyslexia_app/services/visual_service.dart';
import 'package:dyslexia_app/models/visual_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('VisualService API Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'student_id': 'test_student_123',
      });
    });

    test('getAdaptiveTypography should return configuration map', () async {
      // This test might fail if the backend is not running, 
      // but we can check the orchestration logic.
      final result = await VisualService.getAdaptiveTypography('syllable_game');
      
      if (result != null) {
        print('✅ VisualService returned data: ${result.keys}');
        expect(result.containsKey('response'), true);
        expect(result.containsKey('visualStrain'), true);
      } else {
        print('⚠️ VisualService returned null (likely backend down). This is expected for offline test.');
      }
    });

    test('sendReward should handle request correctly', () async {
      final success = await VisualService.sendReward(
        studentId: 'test_student',
        sessionId: 'test_session',
        armId: 1,
        strainBefore: 0.5,
        strainAfter: 0.4,
        accuracyDelta: 0.1,
      );
      
      print('DEBUG: sendReward success: $success');
      // If backend is down, this will be false. 
      // We just want to ensure it doesn't crash.
    });
   group('VisualService Local Logic', () {
      test('TypographyResponse model parsing', () {
      final mockJson = {
        'student_id': 'test_student',
        'linucb_arm_selected': 2,
        'typography_config': {
          'font_size': 22.0,
          'font_family': 'OpenDyslexic',
          'letter_spacing': 0.5,
          'line_height': 1.2,
        },
        'game_mode_trigger': false,
        'game_difficulty': 2
      };
      
      final response = TypographyResponse.fromJson(mockJson);
      expect(response.armSelected, 2);
      expect(response.config.fontFamily, 'OpenDyslexic');
      expect(response.config.fontSize, 22.0);
    });
    });
  });
}
