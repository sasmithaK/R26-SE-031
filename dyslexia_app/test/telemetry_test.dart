import 'package:flutter_test/flutter_test.dart';
import 'package:dyslexia_app/utils/telemetry_collector.dart';
import 'package:dyslexia_app/models/telemetry.dart';
import 'dart:convert';

void main() {
  group('TelemetryCollector Tests', () {
    test('Should capture and format telemetry data correctly', () {
      final collector = TelemetryCollector(
        studentId: 'test_student',
        taskId: 'test_game',
        sessionId: 'test_session',
      );

      // Simulate interactions
      collector.recordTouch(100.0, 200.0);
      collector.recordTouch(150.0, 250.0);
      collector.recordHint();
      collector.recordReplay();
      collector.recordCorrection();

      final payload = collector.finalize('COMPLETED');
      final json = payload.toJson();

      print('DEBUG: Telemetry Payload JSON: ${jsonEncode(json)}');

      expect(json['student_id'], 'test_student');
      expect(json['task_id'], 'test_game');
      expect(json['event_type'], 'COMPLETED');
      expect(json['hint_request_count'], 1);
      expect(json['replay_count'], 1);
      expect(json['touch_events'].length, 2);
      expect(json['correction_rate'], greaterThan(0));
    });
  });
}
