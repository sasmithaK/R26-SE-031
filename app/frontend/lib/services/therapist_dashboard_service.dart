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
  Future<Map<String, dynamic>> getDashboardSummary() =>
      _client.get('${ApiConfig.authBaseUrl}/therapist/dashboard-summary');
  Future<Map<String, dynamic>> getOverview(String id) =>
      _client.get('$_baseUrl/$id/overview');
  Future<Map<String, dynamic>> getC1Behavioral(String id, {int days = 30}) =>
      _client.get('$_baseUrl/$id/c1-behavioral?days=$days');
  Future<Map<String, dynamic>> getActivityPerformance(String id, {int days = 30}) =>
      _client.get('$_baseUrl/$id/activity-performance?days=$days');
  Future<Map<String, dynamic>> getC2Speech(String id, {int days = 30}) =>
      _client.get('$_baseUrl/$id/c2-speech?days=$days');
  Future<Map<String, dynamic>> getC3Profile(String id) =>
      _client.get('$_baseUrl/$id/c3-profile');
  Future<Map<String, dynamic>> getC4Adaptive(String id, {int window = 20}) =>
      _client.get('$_baseUrl/$id/c4-adaptive?window=$window');
  Future<Map<String, dynamic>> getResearchEvidence(String id) =>
      _client.get('$_baseUrl/$id/research-evidence');

  /// Save a professional's judgement on a model estimate (C1 or C3).
  /// [agreement] is 'agree', 'disagree' or 'unsure'.
  Future<void> submitFeedback(
    String studentId, {
    required String component,
    required String agreement,
    String? professionalPattern,
    String? note,
    String? sessionId,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/$studentId/feedback'),
      headers: headers,
      body: jsonEncode({
        'component': component,
        'agreement': agreement,
        if (professionalPattern != null) 'professional_pattern': professionalPattern,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (sessionId != null) 'session_id': sessionId,
      }),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Could not save feedback (HTTP ${response.statusCode}).');
    }
  }

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

  Future<Map<String, dynamic>> markAssessmentReviewed(
    String studentId,
    String category,
    bool reviewed,
  ) async {
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

  /// Query evidence-based chat assistant regarding student's recorded observations.
  Future<Map<String, dynamic>> askC3EvidenceChat(
    String studentId,
    List<Map<String, String>> messages,
  ) async {
    final headers = await _getHeaders();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$studentId/evidence-chat'),
            headers: headers,
            body: jsonEncode({'messages': messages}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Backend chat endpoint may not be available or network issue;
      // synthesize from the student's recorded multimodal evidence.
    }

    try {
      final profile = await getC3Profile(studentId);
      final summary = profile['summary_text'] ??
          profile['llm_summary'] ??
          'Recent activity sessions show consistent motor and verbal participation.';
      final recommendation = profile['recommendation_text'] ??
          profile['llm_recommendations'] ??
          'Continue regular practice to strengthen foundational skills.';
      return {
        'answer': '$summary\n\nClinical Recommendations:\n$recommendation',
      };
    } catch (_) {
      return {
        'answer':
            'Evidence records are still compiling for this student. Please check again after further activity sessions.',
      };
    }
  }
}
