import '../config/api_config.dart';
import 'dashboard_client.dart';

class ParentDashboardService {
  String get _baseUrl => ApiConfig.parentDashboardBaseUrl;
  final _client = DashboardClient();
  Future<Map<String, dynamic>> getOverview(String id) => _client.get('$_baseUrl/$id/overview');
  Future<Map<String, dynamic>> getSkills(String id) => _client.get('$_baseUrl/$id/skills');
  Future<Map<String, dynamic>> getProgress(String id) => _client.get('$_baseUrl/$id/progress');
  Future<Map<String, dynamic>> getLearningPattern(String id) => _client.get('$_baseUrl/$id/learning-pattern');
  Future<Map<String, dynamic>> getActivityHistory(String id, [String filter = 'limit=10']) => _client.get('$_baseUrl/$id/activity-history?$filter');
  Future<Map<String, dynamic>> getResearchEvidence(String id) => _client.get('$_baseUrl/$id/research-evidence');
}
