import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assessment_results.dart';

class AssessmentResultsService {
  static const String baseUrl = 'http://10.73.171.253:5001/api/v1';

  /// Convert letter score (0-3) to rating
  static String rateLetterScore(int score) {
    if (score == 0 || score == 1) return 'weak';
    if (score == 2) return 'moderate';
    return 'strong'; // 3
  }

  /// Convert WPM to rating (Grade 1 dyslexic benchmark)
  static String rateWordsPerMinute(double wpm) {
    if (wpm < 15) return 'weak';
    if (wpm >= 15 && wpm <= 25) return 'moderate';
    return 'strong'; // > 25
  }

  /// Convert comprehension score (0-3) to rating
  static String rateComprehensionScore(int score) {
    if (score == 0 || score == 1) return 'weak';
    if (score == 2) return 'moderate';
    return 'strong'; // 3
  }

  /// Convert word error count to rating
  static String rateWordErrors(int errorCount) {
    if (errorCount > 3) return 'weak';
    if (errorCount == 2 || errorCount == 3) return 'moderate';
    return 'strong'; // 0 or 1
  }

  /// Calculate tier (1, 2, or 3) based on four ratings
  /// Tier 1 - Developing Well: Most moderate/strong ratings
  /// Tier 2 - Needs Moderate Support: Mix of weak and moderate
  /// Tier 3 - Needs High Support: Most weak ratings
  static Map<String, dynamic> calculateTier(
    String letterRating,
    String wpmRating,
    String comprehensionRating,
    String errorRating,
  ) {
    final ratings = [letterRating, wpmRating, comprehensionRating, errorRating];
    
    int weakCount = ratings.where((r) => r == 'weak').length;
    int moderateCount = ratings.where((r) => r == 'moderate').length;
    int strongCount = ratings.where((r) => r == 'strong').length;
    
    int tier;
    String tierDescription;
    String tierSupport;
    
    // Determine tier based on counts (Tier 1 = easy, Tier 3 = hard)
    if (weakCount >= 2) {
      // Most weak ratings => highest support needed
      tier = 3;
      tierDescription = 'Tier 3 - Needs High Support';
      tierSupport = 'Most of the four ratings came back as weak. This child is struggling significantly.';
    } else if (strongCount >= 2 && weakCount == 0) {
      // Most moderate or strong, no weak
      tier = 1;
      tierDescription = 'Tier 1 - Developing Well';
      tierSupport = 'Most ratings came back as moderate or strong. This child is managing reasonably well.';
    } else if (strongCount >= 2 && weakCount <= 1) {
      // Good mix, mostly strong/moderate
      tier = 1;
      tierDescription = 'Tier 1 - Developing Well';
      tierSupport = 'Most ratings came back as moderate or strong. This child is managing reasonably well.';
    } else {
      // Mix of weak and moderate, or moderate dominant
      tier = 2;
      tierDescription = 'Tier 2 - Needs Moderate Support';
      tierSupport = 'Mix of weak and moderate ratings. This child has some skills but struggles in certain areas.';
    }
    
    return {
      'tier': tier,
      'tierDescription': tierDescription,
      'tierSupport': tierSupport,
      'breakdown': {
        'weak': weakCount,
        'moderate': moderateCount,
        'strong': strongCount,
      },
    };
  }

  /// Create AssessmentResults from individual task scores
  static AssessmentResults createAssessmentResults({
    required String studentId,
    required String studentName,
    required int studentAge,
    required String studentGrade,
    required int letterScore,
    required double wordsPerMinute,
    required int comprehensionScore,
    required int wordErrorCount,
  }) {
    final letterRating = rateLetterScore(letterScore);
    final wpmRating = rateWordsPerMinute(wordsPerMinute);
    final comprehensionRating = rateComprehensionScore(comprehensionScore);
    final errorRating = rateWordErrors(wordErrorCount);

    // Calculate tier based on all four ratings
    final tierData = calculateTier(
      letterRating,
      wpmRating,
      comprehensionRating,
      errorRating,
    );

    return AssessmentResults(
      studentId: studentId,
      studentName: studentName,
      studentAge: studentAge,
      studentGrade: studentGrade,
      letterScore: letterScore,
      wordsPerMinute: wordsPerMinute,
      comprehensionScore: comprehensionScore,
      wordErrorCount: wordErrorCount,
      letterRating: letterRating,
      wpmRating: wpmRating,
      comprehensionRating: comprehensionRating,
      errorRating: errorRating,
      tier: tierData['tier'] as int,
      tierDescription: tierData['tierDescription'] as String,
      tierSupport: tierData['tierSupport'] as String,
      assessedAt: DateTime.now(),
    );
  }

  /// Save assessment results to MongoDB
  static Future<bool> saveAssessmentResults(AssessmentResults results) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/assessment-results'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(results.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Assessment results saved successfully for ${results.studentId}');
        return true;
      } else {
        print('❌ Failed to save assessment results: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error saving assessment results: $e');
      return false;
    }
  }

  /// Get assessment history for a student
  static Future<List<AssessmentResults>> getAssessmentHistory(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assessment-results/$studentId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;
        return jsonData
            .map((json) => AssessmentResults.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        print('Failed to fetch assessment history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching assessment history: $e');
      return [];
    }
  }

  /// Get latest assessment results for a student
  static Future<AssessmentResults?> getLatestAssessment(String studentId) async {
    final history = await getAssessmentHistory(studentId);
    if (history.isEmpty) return null;
    return history.last; // Assuming MongoDB returns in chronological order
  }
}
