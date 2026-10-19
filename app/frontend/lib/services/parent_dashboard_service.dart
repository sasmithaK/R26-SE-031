import '../config/api_config.dart';
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
}
