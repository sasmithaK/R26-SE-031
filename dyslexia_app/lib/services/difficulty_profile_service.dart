import 'dart:convert';

import '../models/learner_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DifficultyProfileService {
  static const String _profileKey = 'current_learner_profile';
  static const String _tierKey = 'assigned_tier';
  static const String _startLevelKey = 'assigned_start_level';

  static String _cachedTier = 'Tier 1';
  static int _cachedStartLevel = 1;
  static LearnerProfile? _cachedProfile;

  static int get cachedStartLevel => _cachedStartLevel;
  static int get cachedStartingGameLevel => _cachedStartLevel;
  static String get cachedTier => _cachedTier;
  static int get cachedProfileTier => _cachedProfile?.profileTier ?? _parseTierNumber(_cachedTier);
  static LearnerProfile? get cachedProfile => _cachedProfile;

  static int tierToStartLevel(String tier) {
    switch (tier) {
      case 'Tier 2':
        return 2;
      case 'Tier 3':
        return 3;
      case 'Tier 1':
      default:
        return 1;
    }
  }

  static int _parseTierNumber(String tier) {
    final match = RegExp(r'(\d+)').firstMatch(tier);
    if (match == null) return 1;
    return (int.tryParse(match.group(1) ?? '1') ?? 1).clamp(1, 3).toInt();
  }

  static void cacheLearnerProfile(LearnerProfile profile) {
    _cachedProfile = profile;
    _cachedTier = 'Tier ${profile.profileTier}';
    _cachedStartLevel = clampLevel(profile.startingGameLevel);
  }

  static int clampLevel(int level) {
    if (level < 1) return 1;
    if (level > 3) return 3;
    return level;
  }

  static int startIndexForLevel(int level, int totalItems) {
    if (totalItems <= 0) return 0;
    final normalizedLevel = clampLevel(level) - 1;
    final rawIndex = ((normalizedLevel / 3.0) * totalItems).floor();
    return rawIndex.clamp(0, totalItems - 1);
  }

  static int countForLevel(int level, int minCount, int maxCount) {
    final normalizedLevel = clampLevel(level);
    final count = minCount + (normalizedLevel - 1);
    if (count < minCount) return minCount;
    if (count > maxCount) return maxCount;
    return count;
  }

  static int startTaskIndexForLevel(int level, int totalTasks) {
    if (totalTasks <= 0) return 0;
    return (clampLevel(level) - 1).clamp(0, totalTasks - 1);
  }

  static void cacheAssignedTier(String tier) {
    _cachedProfile = null;
    _cachedTier = tier;
    _cachedStartLevel = tierToStartLevel(tier);
  }

  static Future<void> saveAssignedTier(String tier) async {
    cacheAssignedTier(tier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, tier);
    await prefs.setInt(_startLevelKey, _cachedStartLevel);
  }

  static Future<void> restoreAssignedTier() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedProfile = prefs.getString(_profileKey);
    if (encodedProfile != null && encodedProfile.isNotEmpty) {
      try {
        final profile = LearnerProfile.fromJson(
          jsonDecode(encodedProfile) as Map<String, dynamic>,
        );
        cacheLearnerProfile(profile);
        return;
      } catch (_) {
        // Fall back to the legacy tier keys below.
      }
    }

    final storedTier = prefs.getString(_tierKey);
    final storedStartLevel = prefs.getInt(_startLevelKey);

    if (storedTier != null) {
      _cachedProfile = null;
      _cachedTier = storedTier;
    }
    if (storedStartLevel != null) {
      _cachedStartLevel = clampLevel(storedStartLevel);
    } else if (storedTier != null) {
      _cachedStartLevel = tierToStartLevel(storedTier);
    }
  }
}