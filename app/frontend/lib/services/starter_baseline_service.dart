import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/starter_baseline_models.dart';
import 'auth_service.dart';

abstract class StarterBaselineRepository {
  Future<StarterBaselineStatus> getStatus(String studentId);
  Future<StarterBaselineStatus> start(String studentId, String sessionId);
  Future<StarterBaselineStatus> submitResponse(
    String studentId,
    Map<String, dynamic> response,
  );
}

class StarterBaselineService implements StarterBaselineRepository {
  StarterBaselineService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => '${ApiConfig.learningBaseUrl}/starter-baseline';

  Future<Map<String, String>> _headers({String? tokenOverride}) async {
    final token = tokenOverride ?? await AuthService().getAccessToken();
    if (token == null) throw StateError('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> send(Map<String, String> headers) {
      if (method == 'GET') {
        return _client.get(uri, headers: headers);
      }
      return _client.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }

    var response = await send(
      await _headers(),
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode == 401) {
      final refreshed = await AuthService().refreshAccessToken();
      if (refreshed != null) {
        response = await send(
          await _headers(tokenOverride: refreshed),
        ).timeout(const Duration(seconds: 12));
      }
    }
    return response;
  }

  Future<StarterBaselineStatus> _decode(http.Response response) async {
    if (response.statusCode == 401) {
      throw StateError('Authentication expired');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Starter profile request failed';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['detail']?.toString() ?? message;
      } catch (_) {}
      throw StateError(message);
    }
    return StarterBaselineStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<StarterBaselineStatus> getStatus(String studentId) async {
    final response = await _request('GET', Uri.parse('$_baseUrl/$studentId'));
    return _decode(response);
  }

  @override
  Future<StarterBaselineStatus> start(
    String studentId,
    String sessionId,
  ) async {
    final response = await _request(
      'POST',
      Uri.parse('$_baseUrl/$studentId/start'),
      body: {'session_id': sessionId},
    );
    return _decode(response);
  }

  @override
  Future<StarterBaselineStatus> submitResponse(
    String studentId,
    Map<String, dynamic> response,
  ) async {
    final result = await _request(
      'POST',
      Uri.parse('$_baseUrl/$studentId/response'),
      body: response,
    );
    return _decode(result);
  }
}
