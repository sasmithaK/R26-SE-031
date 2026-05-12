import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/learner_profile.dart';
import 'difficulty_profile_service.dart';

class LearnerProfileService {
  static const String _currentProfileKey = 'current_learner_profile';
  static const String _currentStudentIdKey = 'current_learner_student_id';

  static final Map<String, LearnerProfile> _profiles = {};
  static LearnerProfile? _currentProfile;

  static LearnerProfile? get currentProfile => _currentProfile;

  static Future<LearnerProfile> buildAndSave({
    required String studentId,
    required int letterScore,
    required double wpmScore,
    required int comprehensionScore,
    required int wordErrorCount,
  }) async {
    final profile = LearnerProfile.fromScores(
      studentId: studentId,
      letterScore: letterScore,
      wpmScore: wpmScore,
      comprehensionScore: comprehensionScore,
      wordErrorCount: wordErrorCount,
    );

    await saveProfile(profile);
    return profile;
  }

  static Future<void> saveProfile(LearnerProfile profile) async {
    _profiles[profile.studentId] = profile;
    _currentProfile = profile;
    DifficultyProfileService.cacheLearnerProfile(profile);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProfileKey, jsonEncode(profile.toJson()));
    await prefs.setString(_currentStudentIdKey, profile.studentId);
    await prefs.setInt('learner_profile_tier', profile.profileTier);
    await prefs.setInt('learner_starting_game_level', profile.startingGameLevel);
    await prefs.setInt('learner_letter_score', profile.letterScore);
    await prefs.setDouble('learner_wpm_score', profile.wpmScore);
    await prefs.setInt('learner_comprehension_score', profile.comprehensionScore);
    await prefs.setInt('learner_word_error_count', profile.wordErrorCount);
  }

  static LearnerProfile? getProfile(String studentId) {
    return _profiles[studentId];
  }

  static Future<LearnerProfile?> restoreCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedProfile = prefs.getString(_currentProfileKey);
    if (encodedProfile != null && encodedProfile.isNotEmpty) {
      try {
        final profile = LearnerProfile.fromJson(
          jsonDecode(encodedProfile) as Map<String, dynamic>,
        );
        _profiles[profile.studentId] = profile;
        _currentProfile = profile;
        DifficultyProfileService.cacheLearnerProfile(profile);
        return profile;
      } catch (_) {
        // Fall through to the legacy tier keys.
      }
    }

    await DifficultyProfileService.restoreAssignedTier();
    return null;
  }

  static Future<void> clearCurrentProfile() async {
    _currentProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentProfileKey);
    await prefs.remove(_currentStudentIdKey);
    await prefs.remove('learner_profile_tier');
    await prefs.remove('learner_starting_game_level');
    await prefs.remove('learner_letter_score');
    await prefs.remove('learner_wpm_score');
    await prefs.remove('learner_comprehension_score');
    await prefs.remove('learner_word_error_count');
  }
}