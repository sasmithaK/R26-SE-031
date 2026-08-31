import 'package:flutter/material.dart';
import '../models/curriculum_models.dart';
import '../screens/games/game_factory.dart';

class SessionActivity {
  final Widget screen;
  final String title;
  final int durationSeconds;

  SessionActivity({
    required this.screen,
    required this.title,
    required this.durationSeconds,
  });
}

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  /// Generates a curated 10-minute playlist of activities based on the student's level.
  /// For now, it returns a static progressive list.
  List<SessionActivity> generateDailySession({Map<String, dynamic>? studentData}) {
    return [
      SessionActivity(
        screen: GameFactory.buildGame(ActivityNode(
          id: 'act_1',
          title: 'සැඟවුණු පින්තූර',
          telemetryTags: ['visual_hidden_search'],
          templateType: 'visual_hidden_search',
          rounds: [],
        ), studentData: studentData),
        title: 'සැඟවුණු පින්තූර',
        durationSeconds: 60,
      ),
      SessionActivity(
        screen: GameFactory.buildGame(ActivityNode(
          id: 'act_2',
          title: 'රටා සම්පූර්ණ කරන්න',
          telemetryTags: ['visual_pattern_adventure'],
          templateType: 'visual_pattern_adventure',
          rounds: [],
        ), studentData: studentData),
        title: 'රටා සම්පූර්ණ කරන්න',
        durationSeconds: 60,
      ),
      SessionActivity(
        screen: GameFactory.buildGame(ActivityNode(
          id: 'act_3',
          title: 'වර්ගීකරණය',
          telemetryTags: ['visual_sorting_adventure'],
          templateType: 'visual_sorting_adventure',
          rounds: [],
        ), studentData: studentData),
        title: 'වර්ගීකරණය',
        durationSeconds: 90,
      ),
      SessionActivity(
        screen: GameFactory.buildGame(ActivityNode(
          id: 'act_4',
          title: 'වෙනස් පින්තූරය',
          telemetryTags: ['visual_odd_one_out'],
          templateType: 'visual_odd_one_out',
          rounds: [],
        ), studentData: studentData),
        title: 'වෙනස් පින්තූරය',
        durationSeconds: 60,
      ),
      SessionActivity(
        screen: GameFactory.buildGame(ActivityNode(
          id: 'act_5',
          title: 'මතක තබා ගන්න',
          telemetryTags: ['visual_memory_hats'],
          templateType: 'visual_memory_hats',
          rounds: [],
        ), studentData: studentData),
        title: 'මතක තබා ගන්න',
        durationSeconds: 90,
      ),
    ];
  }
}
