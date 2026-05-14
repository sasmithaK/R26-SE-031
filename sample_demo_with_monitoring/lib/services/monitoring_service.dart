import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mbsv.dart';

class MonitoringService {
  final String baseUrl = "http://127.0.0.1:8011/api/v1";

  Future<MBSV> sendTelemetry({
    required String studentId,
    required Map<String, dynamic> telemetry,
  }) async {
    try {
      final body = {
        'student_id': studentId,
        'task_id': telemetry['task_id'] ?? 'word_matching_01',
        'session_id': telemetry['session_id'] ?? 'DEMO_SESSION',
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
        'event_type': telemetry['event_type'] ?? 'TAP',
        'session_latency_ms': telemetry['response_latency'] ?? 0,
        'hesitation_ms': telemetry['hesitation_ms'] ?? 0,
        'swipe_velocity': telemetry['swipe_velocity'] ?? 0.0,
        'correction_rate': telemetry['correction_rate'] ?? 0.0,
        'replay_count': telemetry['replay_count'] ?? 0,
        'hint_request_count': telemetry['hint_request_count'] ?? 0,
        'touch_events': telemetry['touch_events'] ?? [],
        'stylus_deviation': telemetry['stylus_deviation'] ?? 0.0,
        'read_aloud_pause_ms': telemetry['read_aloud_pause_ms'] ?? 0,
        'syllable_rate': telemetry['syllable_rate'] ?? 0.0,
        'disfluency_count': telemetry['disfluency_count'] ?? 0,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/telemetry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MBSV.fromJson(data['mbsv']);
      } else {
        print('Error from C1 (${response.statusCode}): ${response.body}');
        return MBSV.initial();
      }
    } catch (e) {
      print('Failed to connect to Monitoring Service (C1): $e');
      return MBSV.initial();
    }
  }
}

