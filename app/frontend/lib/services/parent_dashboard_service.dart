import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import 'dashboard_client.dart';

class ParentDashboardService {
  String get _baseUrl => ApiConfig.parentDashboardBaseUrl;
  final DashboardClient _client = DashboardClient();

  Future<Map<String, dynamic>> getOverview(String id) =>
      _client.get('$_baseUrl/$id/overview');
  Future<Map<String, dynamic>> getAssessmentSummary(String id) =>
      _client.get('$_baseUrl/$id/assessment-summary');
  Future<Map<String, dynamic>> getProgress(String id) =>
      _client.get('$_baseUrl/$id/progress');
  Future<Map<String, dynamic>> getSkills(String id) =>
      _client.get('$_baseUrl/$id/skills');
  Future<Map<String, dynamic>> getLearningPattern(String id) =>
      _client.get('$_baseUrl/$id/learning-pattern');
  Future<Map<String, dynamic>> getComponentAnalytics(String id) =>
      _client.get('$_baseUrl/$id/component-analytics');
  Future<Map<String, dynamic>> getActivityPerformance(
    String id, {
    int days = 30,
  }) => _client.get('$_baseUrl/$id/activity-performance?days=$days');
  Future<Map<String, dynamic>> getResearchEvidence(String id) =>
      _client.get('$_baseUrl/$id/research-evidence');
  Future<Map<String, dynamic>> getAdaptiveInsights(String id) =>
      _client.get('$_baseUrl/$id/adaptive-insights');
  Future<Map<String, dynamic>> getActivityHistory(
    String id, [
    String filter = 'limit=10',
  ]) {
    final query = filter.startsWith('limit=') || filter.startsWith('days=')
        ? filter
        : 'limit=10';
    return _client.get('$_baseUrl/$id/activity-history?$query');
  }

  /// Plain-language learning summary PDF (observations only).
  Future<Uint8List> downloadLearningSummary(String id, {int days = 30}) async {
    final token = await AuthService().getAccessToken();
    if (token == null) throw Exception('Sign in again to download the summary.');
    final response = await http.get(
      Uri.parse('$_baseUrl/$id/report?days=$days'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/pdf'},
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Could not create the summary (HTTP ${response.statusCode}).');
    }
    return response.bodyBytes;
  }
}
