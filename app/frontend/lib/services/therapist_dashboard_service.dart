import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'dashboard_client.dart';

class TherapistDashboardService {
  String get _baseUrl => ApiConfig.therapistDashboardBaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  final _client = DashboardClient();
  Future<Map<String, dynamic>> getOverview(String id) => _client.get('$_baseUrl/$id/overview');
  Future<Map<String, dynamic>> getC1Behavioral(String id) => _client.get('$_baseUrl/$id/c1-behavioral');
  Future<Map<String, dynamic>> getC2Speech(String id) => _client.get('$_baseUrl/$id/c2-speech');
  Future<Map<String, dynamic>> getC3Profile(String id) => _client.get('$_baseUrl/$id/c3-profile');
  Future<Map<String, dynamic>> generateC3AiSummary(String id) => _client.post('$_baseUrl/students/$id/c3-ai-summary');
  Future<Map<String, dynamic>> getC4Adaptive(String id) => _client.get('$_baseUrl/$id/c4-adaptive');
  Future<Map<String, dynamic>> getPerformanceTree(String id) => _client.get('$_baseUrl/students/$id/performance-tree');
  Future<Map<String, dynamic>> getResearchEvidence(String id) => _client.get('$_baseUrl/$id/research-evidence');

  Future<Uint8List> downloadReport(String studentId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/$studentId/report/pdf'),
      headers: {...headers, 'Accept': 'application/pdf'},
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to download report');
  }

  Future<Map<String, dynamic>> markAssessmentReviewed(String studentId, String category, bool reviewed) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$_baseUrl/$studentId/review-assessment/$category'),
      headers: headers,
      body: '{"reviewed": $reviewed}',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update assessment review status');
  }
}
