import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String monitoringUrl = 'http://127.0.0.1:8001/api/v1';
  static const String contentUrl = 'http://127.0.0.1:8002/api/v1';
  static const String interventionUrl = 'http://127.0.0.1:8003/api/v1';
  static const String visualUrl = 'http://127.0.0.1:8004/api/v1';

  // 1. Send Telemetry to Monitoring Service
  static Future<Map<String, dynamic>> sendTelemetry(String studentId, double hesitation, double velocity, double correction) async {
    final response = await http.post(
      Uri.parse('$monitoringUrl/telemetry'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "student_id": studentId,
        "session_id": "SES001",
        "hesitation_time_ms": hesitation,
        "swipe_velocity": velocity,
        "correction_rate": correction
      }),
    );
    return jsonDecode(response.body);
  }

  // 2. Trigger Intervention Manually (Simulation)
  static Future<Map<String, dynamic>> triggerIntervention(String studentId, int cognitiveLoad) async {
    final response = await http.post(
      Uri.parse('$interventionUrl/intervention/trigger'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "student_id": studentId,
        "cognitive_load_level": cognitiveLoad
      }),
    );
    return jsonDecode(response.body);
  }

  // 3. Get UI Layout
  static Future<Map<String, dynamic>> getUILayout(String studentId) async {
    final response = await http.post(
      Uri.parse('$visualUrl/ui/layout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "student_id": studentId,
        "task_type": "WordMatcher"
      }),
    );
    return jsonDecode(response.body);
  }
}
