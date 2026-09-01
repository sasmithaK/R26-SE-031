import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/c1/c1_parent_summary.dart';
import '../models/c1/c1_trend_point.dart';

class C1ParentService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<ParentC1Summary?> getSummary(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.c1BaseUrl}/students/$studentId/summary'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return ParentC1Summary.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting C1 summary: $e');
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
}
