import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Service for C4 intervention features (syllable splitting, SM-2 scheduling)
class InlineInterventionService {
  /// Request syllable split for a word from C4
  static Future<List<String>> splitSyllables(String word) async {
    try {
      final url = '${ApiConfig.interventionUrl}/intervention/check';
      final payload = {
        'word': word,
        'event_type': 'syllable_split_request',
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Response structure from C4:
        // { "syllables": ["ගු", "රු", "ව", "රයා"], ... }
        final syllables = (data['syllables'] as List?)?.cast<String>() ?? [];

        debugPrint('[Intervention] Syllables for "$word": ${syllables.join(" · ")}');
        return syllables.isNotEmpty ? syllables : [word];
      } else {
        debugPrint('[Intervention] Syllable split failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Intervention] Syllable split error: $e');
    }

    return [word]; // Fallback: return full word
  }

  /// Get SM-2 review words due today for a student
  static Future<List<Map<String, dynamic>>> getDueReviews(String studentId) async {
    try {
      final url = '${ApiConfig.interventionUrl}/intervention/sm2/schedule/$studentId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['due_words'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        debugPrint('[Intervention] ${items.length} words due for SM-2 review');
        return items;
      }
    } catch (e) {
      debugPrint('[Intervention] SM-2 due error: $e');
    }

    return [];
  }

  /// Report SM-2 review result (for learning curve optimization)
  static Future<bool> reportReviewResult({
    required String studentId,
    required String word,
    required bool correct,
    required int responseTimeMs,
  }) async {
    try {
      final url = '${ApiConfig.interventionUrl}/intervention/sm2/update';
      final payload = {
        'student_id': studentId,
        'word': word,
        'correct': correct,
        'response_time_ms': responseTimeMs,
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Intervention] SM-2 report error: $e');
      return false;
    }
  }
}
