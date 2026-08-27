import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class SpecialistService {
  String get _baseUrl => ApiConfig.specialistBaseUrl;
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Lookup specialist by clinic code
  Future<Map<String, dynamic>?> lookupSpecialist(String clinicCode) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/lookup/$clinicCode'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error looking up specialist: $e');
      return null;
    }
  }

  // Connect student to specialist
  Future<String?> connectSpecialist(String studentId, String clinicCode) async {
    try {
      final token = await _getToken();
      if (token == null) return 'No auth token found';

      final response = await http.post(
        Uri.parse('$_baseUrl/connect'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'student_id': studentId,
          'clinic_code': clinicCode,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? 'Failed to connect';
      }
    } catch (e) {
      debugPrint('Error connecting specialist: $e');
      return 'Network error';
    }
  }
}
