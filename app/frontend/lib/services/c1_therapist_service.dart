import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/c1/c1_therapist_state.dart';
import '../models/c1/c1_trend_point.dart';
import '../models/c1/c1_session_summary.dart';
import '../models/c1/c1_session_detail.dart';

class C1TherapistService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<TherapistC1State?> getState(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.c1BaseUrl}/students/$studentId/state'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return TherapistC1State.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting C1 state: $e');
      return null;
    }
  }

  Future<List<C1TrendPoint>> getTrend(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.c1BaseUrl}/students/$studentId/trend'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        Iterable list = json.decode(response.body);
        return list.map((m) => C1TrendPoint.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting C1 trend: $e');
      return [];
    }
  }

  Future<List<C1SessionSummary>> getSessions(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.c1BaseUrl}/students/$studentId/sessions'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        Iterable list = json.decode(response.body);
        return list.map((m) => C1SessionSummary.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting C1 sessions: $e');
      return [];
    }
  }

  Future<C1SessionDetail?> getSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.c1BaseUrl}/sessions/$sessionId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return C1SessionDetail.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting C1 session detail: $e');
      return null;
    }
  }
}
