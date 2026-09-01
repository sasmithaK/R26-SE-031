import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DashboardClient {
  Future<Map<String, dynamic>> get(String url) async {
    final token = await AuthService().getAccessToken();
    if (token == null) throw Exception('Sign in again to view this dashboard.');
    final response = await http.get(Uri.parse(url), headers: {
      'Authorization': 'Bearer $token', 'Accept': 'application/json',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Dashboard request failed: HTTP ${response.statusCode} (${Uri.parse(url).path}).');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) throw const FormatException('Invalid dashboard response');
    return data;
  }

  Future<Map<String, dynamic>> post(String url) async {
    final token = await AuthService().getAccessToken();
    if (token == null) throw Exception('Sign in again to view this dashboard.');
    final response = await http.post(Uri.parse(url), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Dashboard request failed: HTTP ${response.statusCode} (${Uri.parse(url).path}).');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) throw const FormatException('Invalid dashboard response');
    return data;
  }
}
