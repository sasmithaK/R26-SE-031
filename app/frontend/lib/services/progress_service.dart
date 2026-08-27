import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'student_service.dart';

class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  SharedPreferences? _prefs;

  // Constants
  static const String _keyCurrentStudentId = 'current_student_id';
  static const String _keyCompletedActivitiesPrefix = 'completed_'; // + studentId
  static const String _keyActivityScoresPrefix = 'scores_'; // + studentId
  static const String _keyActivityStatePrefix = 'state_'; // + studentId
  static const String _keyLastActiveDate = 'last_active_date';
  static const String _keyStreakCount = 'streak_count';
  static const String _keyStreakEarned = 'streak_earned_by_activity';

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> init() async {
    await _ensurePrefs();
  }

  // --- Student Management ---
  
  Future<void> setCurrentStudentId(String studentId) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_keyCurrentStudentId, studentId);
  }

  String get currentStudentId {
    return _prefs?.getString(_keyCurrentStudentId) ?? 'test_student_001';
  }

  // --- Cloud Sync & Local Persistence Merge ---

  /// Safely merges progress data from cloud payload into local storage (never overwriting local offline progress)
  Future<void> loadFromCloud(Map<String, dynamic> studentData) async {
    final prefs = await _ensurePrefs();
    final String studentId = studentData['id']?.toString() ?? currentStudentId;
    final completedKey = '$_keyCompletedActivitiesPrefix$studentId';
    final scoresKey = '$_keyActivityScoresPrefix$studentId';

    // 1. Existing local data
    List<String> localCompleted = prefs.getStringList(completedKey) ?? [];
    String? localScoresJson = prefs.getString(scoresKey);
    Map<String, int> localScores = {};
    if (localScoresJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(localScoresJson);
        localScores = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    // 2. Extract cloud data
    List<dynamic> cloudCompletedRaw = studentData['completed_activities'] ?? [];
    Map<String, dynamic> cloudScoresRaw = studentData['activity_scores'] ?? {};
    
    List<String> cloudCompleted = cloudCompletedRaw.map((e) => e.toString()).toList();
    Map<String, int> cloudScores = {};
    cloudScoresRaw.forEach((k, v) {
      if (v is num) cloudScores[k] = v.toInt();
    });

    // 3. Union merge completed activities (local + cloud)
    final Set<String> mergedCompleted = {...localCompleted, ...cloudCompleted};

    // 4. Merge scores (keep higher score)
    final Map<String, int> mergedScores = {...localScores};
    cloudScores.forEach((key, cloudScore) {
      final localScore = mergedScores[key] ?? 0;
      if (cloudScore > localScore) {
        mergedScores[key] = cloudScore;
      }
    });

    // 5. Save merged data persistently
    await prefs.setStringList(completedKey, mergedCompleted.toList());
    await prefs.setString(scoresKey, json.encode(mergedScores));

    // 6. If local had progress not yet on cloud, trigger sync back
    if (mergedCompleted.length > cloudCompleted.length || mergedScores.length > cloudScores.length) {
      _triggerCloudSync();
    }
  }

  void _triggerCloudSync() async {
    final prefs = await _ensurePrefs();
    final completedKey = '$_keyCompletedActivitiesPrefix$currentStudentId';
    final scoresKey = '$_keyActivityScoresPrefix$currentStudentId';
    
    List<String> completed = prefs.getStringList(completedKey) ?? [];
    String? scoresJson = prefs.getString(scoresKey);
    Map<String, int> scores = {};
    if (scoresJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(scoresJson);
        scores = decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
      } catch (_) {}
    }
    
    // Network sync
    StudentService().syncProgress(currentStudentId, completed, scores);
  }

  // --- Activity Progression ---

  /// Marks an activity as completed for the current student
  Future<void> markActivityCompleted(String skillId, String activityId) async {
    final prefs = _prefs ?? await _ensurePrefs();
    final key = '$_keyCompletedActivitiesPrefix$currentStudentId';
    List<String> completed = prefs.getStringList(key) ?? [];
    
    final activityKey = '${skillId}_$activityId';
    if (!completed.contains(activityKey)) {
      completed.add(activityKey);
      await prefs.setStringList(key, completed);
      // Streak only counts if an activity was actually completed today
      await updateAndGetStreak();
      // Mark streak as genuinely earned
      await prefs.setBool(_keyStreakEarned, true);
      _triggerCloudSync();
    }
    // Automatically clear any partial progress since it's fully completed now!
    await clearActivityState(skillId, activityId);
  }

  /// Checks if an activity is completed
  bool isActivityCompleted(String skillId, String activityId) {
    final key = '$_keyCompletedActivitiesPrefix$currentStudentId';
    List<String> completed = _prefs?.getStringList(key) ?? [];
    if (completed.contains('${skillId}_$activityId')) return true;

    // Fallback: If student played and earned a full score, consider it completed
    final score = getActivityScore(skillId, activityId);
    return score >= 100;
  }

  /// Get the number of completed activities for a given skill
  int getCompletedActivitiesCount(String skillId) {
    final key = '$_keyCompletedActivitiesPrefix$currentStudentId';
    List<String> completed = _prefs?.getStringList(key) ?? [];
    
    int count = 0;
    bool hasAct4 = false;
    for (String id in completed) {
      if (id.startsWith('${skillId}_')) {
        count++;
        if (id == '${skillId}_act_4') {
          hasAct4 = true;
        }
      }
    }

    // Special rule for skill_4: act_4 counts as two activities for progress calculation
    if (skillId == 'skill_4' && hasAct4) {
      count++;
    }

    // Fallback check against activity scores if not listed in completed array
    if (count == 0 && _prefs != null) {
      final scoresKey = '$_keyActivityScoresPrefix$currentStudentId';
      String? scoresJson = _prefs?.getString(scoresKey);
      if (scoresJson != null) {
        try {
          final Map<String, dynamic> scoresMap = json.decode(scoresJson);
          bool fallbackHasAct4 = false;
          for (String k in scoresMap.keys) {
            if (k.startsWith('${skillId}_') && (scoresMap[k] as num) >= 100) {
              count++;
              if (k == '${skillId}_act_4') {
                fallbackHasAct4 = true;
              }
            }
          }
          if (skillId == 'skill_4' && fallbackHasAct4) {
            count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  /// Get the normalized progress for a skill (0.0 to 1.0)
  double getSkillProgress(String skillId, int totalActivities) {
    if (totalActivities <= 0) return 0.0;
    int completed = getCompletedActivitiesCount(skillId);
    return (completed / totalActivities).clamp(0.0, 1.0);
  }

  /// Get a list of all completed activity keys for a given skill
  List<String> getCompletedActivitiesForSkill(String skillId) {
    final key = '$_keyCompletedActivitiesPrefix$currentStudentId';
    List<String> completed = _prefs?.getStringList(key) ?? [];
    
    return completed.where((id) => id.startsWith('${skillId}_')).toList();
  }

  // --- Intro Screen Tracking ---

  Future<void> markSkillIntroSeen(String skillId) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool('intro_seen_skill_${currentStudentId}_$skillId', true);
  }

  bool isSkillIntroSeen(String skillId) {
    return _prefs?.getBool('intro_seen_skill_${currentStudentId}_$skillId') ?? false;
  }

  /// Checks if a skill is unlocked based on:
  /// 1. First skill (index 0) is always unlocked.
  /// 2. Unlocked if ALL activities in preceding skill are completed.
  /// 3. Trial shortcut: Unlocked if student tried this skill and completed its 1st activity (act_1).
  bool isSkillUnlocked(int index, String skillId, String? prevSkillId, int prevTotalActivities) {
    if (index == 0) return true;

    // Progression rule: All activities in previous skill must be completed
    if (prevSkillId != null && prevTotalActivities > 0) {
      int completedCount = 0;
      for (int i = 0; i < prevTotalActivities; i++) {
        if (isActivityCompleted(prevSkillId, 'act_${i + 1}')) {
          completedCount++;
        }
      }
      if (completedCount >= prevTotalActivities) return true;
    }

    // Trial rule: 1st activity of this skill completed with any score > 0
    final firstActivityId = 'act_1';
    final isFirstCompleted = isActivityCompleted(skillId, firstActivityId);
    final firstScore = getActivityScore(skillId, firstActivityId);
    if (isFirstCompleted || firstScore > 0) return true;

    return false;
  }

  // --- Scoring ---

  Future<void> saveActivityScore(String skillId, String activityId, int score) async {
    final prefs = _prefs ?? await _ensurePrefs();
    final key = '$_keyActivityScoresPrefix$currentStudentId';
    String? scoresJson = prefs.getString(key);
    Map<String, dynamic> scores = {};
    if (scoresJson != null) {
      try {
        scores = json.decode(scoresJson);
      } catch (_) {}
    }
    
    scores['${skillId}_$activityId'] = score;
    prefs.setString(key, json.encode(scores));
    _triggerCloudSync();
  }

  int getActivityScore(String skillId, String activityId) {
    final key = '$_keyActivityScoresPrefix$currentStudentId';
    String? scoresJson = _prefs?.getString(key);
    if (scoresJson == null) return 0;
    
    try {
      Map<String, dynamic> scores = json.decode(scoresJson);
      final val = scores['${skillId}_$activityId'];
      if (val is num) return val.toInt();
    } catch (_) {}
    return 0;
  }

  // --- Partial Progress State ---

  Future<void> saveActivityState(String skillId, String activityId, int currentRoundIndex) async {
    final prefs = _prefs ?? await _ensurePrefs();
    final key = '$_keyActivityStatePrefix$currentStudentId';
    String? stateJson = prefs.getString(key);
    Map<String, dynamic> states = {};
    if (stateJson != null) {
      try {
        states = json.decode(stateJson);
      } catch (_) {}
    }
    
    states['${skillId}_$activityId'] = currentRoundIndex;
    prefs.setString(key, json.encode(states));
  }

  int getActivityState(String skillId, String activityId) {
    final key = '$_keyActivityStatePrefix$currentStudentId';
    String? stateJson = _prefs?.getString(key);
    if (stateJson == null) return 0;
    
    try {
      Map<String, dynamic> states = json.decode(stateJson);
      final val = states['${skillId}_$activityId'];
      if (val is num) return val.toInt();
    } catch (_) {}
    return 0;
  }

  Future<void> clearActivityState(String skillId, String activityId) async {
    final prefs = _prefs ?? await _ensurePrefs();
    final key = '$_keyActivityStatePrefix$currentStudentId';
    String? stateJson = prefs.getString(key);
    if (stateJson != null) {
      try {
        Map<String, dynamic> states = json.decode(stateJson);
        states.remove('${skillId}_$activityId');
        prefs.setString(key, json.encode(states));
      } catch (_) {}
    }
  }

  // --- Failure Tracking (Dynamic Difficulty Adjustment) ---
  
  static const String _keyFailureCountPrefix = 'failures_'; // + studentId

  Future<void> incrementFailureCount(String skillId, String activityId) async {
    final prefs = await _ensurePrefs();
    final key = '$_keyFailureCountPrefix$currentStudentId';
    
    String? failsJson = prefs.getString(key);
    Map<String, dynamic> fails = {};
    if (failsJson != null) {
      try {
        fails = json.decode(failsJson);
      } catch (_) {}
    }
    
    final actKey = '${skillId}_$activityId';
    fails[actKey] = (fails[actKey] ?? 0) + 1;
    
    await prefs.setString(key, json.encode(fails));
  }
  
  int getFailureCount(String skillId, String activityId) {
    final key = '$_keyFailureCountPrefix$currentStudentId';
    String? failsJson = _prefs?.getString(key);
    if (failsJson == null) return 0;
    
    try {
      Map<String, dynamic> fails = json.decode(failsJson);
      final val = fails['${skillId}_$activityId'];
      if (val is num) return val.toInt();
    } catch (_) {}
    return 0;
  }
  
  Future<void> resetFailureCount(String skillId, String activityId) async {
    final prefs = await _ensurePrefs();
    final key = '$_keyFailureCountPrefix$currentStudentId';
    
    String? failsJson = prefs.getString(key);
    if (failsJson != null) {
      try {
        Map<String, dynamic> fails = json.decode(failsJson);
        fails.remove('${skillId}_$activityId');
        await prefs.setString(key, json.encode(fails));
      } catch (_) {}
    }
  }

  // --- Streak Tracking ---

  int get currentStreak {
    final earned = _prefs?.getBool(_keyStreakEarned) ?? false;
    if (!earned) return 0;
    return _prefs?.getInt(_keyStreakCount) ?? 0;
  }

  Future<int> updateAndGetStreak() async {
    final prefs = await _ensurePrefs();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final lastActiveStr = prefs.getString(_keyLastActiveDate);
    int streak = prefs.getInt(_keyStreakCount) ?? 0;

    if (lastActiveStr == null) {
      streak = 1;
    } else {
      final parts = lastActiveStr.split('-');
      final lastActive = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final today0 = DateTime(today.year, today.month, today.day);
      final diff = today0.difference(lastActive).inDays;
      if (diff == 0) {
        // Same day
      } else if (diff == 1) {
        streak += 1;
      } else {
        streak = 1; // Streak broken
        await prefs.setBool(_keyStreakEarned, false);
      }
    }

    await prefs.setString(_keyLastActiveDate, todayStr);
    await prefs.setInt(_keyStreakCount, streak);
    return streak;
  }

  // --- Reset Progress ---

  /// Resets all skill progress, activity scores, failures, and intros for a student
  Future<void> resetStudentProgress(String studentId) async {
    final prefs = await _ensurePrefs();
    final completedKey = '$_keyCompletedActivitiesPrefix$studentId';
    final scoresKey = '$_keyActivityScoresPrefix$studentId';
    final failsKey = '$_keyFailureCountPrefix$studentId';
    final stateKey = '$_keyActivityStatePrefix$studentId';

    await prefs.remove(completedKey);
    await prefs.remove(scoresKey);
    await prefs.remove(failsKey);
    await prefs.remove(stateKey);

    // Also reset the streak
    await prefs.remove(_keyStreakCount);
    await prefs.remove(_keyStreakEarned);
    await prefs.remove(_keyLastActiveDate);

    // Clear skill intro seen flags for all skills
    for (int i = 0; i <= 10; i++) {
      await prefs.remove('intro_seen_skill_${studentId}_skill_$i');
    }

    // Sync cloud state (send empty list and map)
    await StudentService().syncProgress(studentId, [], {});
  }
}

