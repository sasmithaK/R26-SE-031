import 'dart:convert';
import 'package:flutter/services.dart';

/// Holds all configurable display text for the Skills Dashboard.
/// Loaded from assets/data/dashboard_config.json at runtime.
class DashboardConfig {
  final GreetingConfig greeting;
  final StreakConfig streak;
  final ProgressConfig progress;
  final String lockedSnackbar;

  DashboardConfig({
    required this.greeting,
    required this.streak,
    required this.progress,
    required this.lockedSnackbar,
  });

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    return DashboardConfig(
      greeting: GreetingConfig.fromJson(json['greeting'] ?? {}),
      streak: StreakConfig.fromJson(json['streak'] ?? {}),
      progress: ProgressConfig.fromJson(json['progress'] ?? {}),
      lockedSnackbar: json['locked_snackbar'] ?? '🔒 Complete the previous skill first!',
    );
  }

  /// Loads the config from the bundled asset file.
  static Future<DashboardConfig> load() async {
    final String raw = await rootBundle.loadString('assets/data/dashboard_config.json');
    return DashboardConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  /// Returns the greeting string for the given hour, with {name} substituted.
  String greetingFor(int hour, String name) {
    String template;
    if (hour < 12) {
      template = greeting.morning;
    } else if (hour < 17) {
      template = greeting.afternoon;
    } else if (hour < 20) {
      template = greeting.evening;
    } else {
      template = greeting.night;
    }
    return template.replaceAll('{name}', name);
  }

  /// Returns the subtitle for a given streak count.
  String subtitleFor(int streak) {
    if (streak > 1) return '$streak ${this.streak.multiDayLabel}';
    return this.streak.zeroLabel;
  }
}

class GreetingConfig {
  final String morning;
  final String afternoon;
  final String evening;
  final String night;

  GreetingConfig({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.night,
  });

  factory GreetingConfig.fromJson(Map<String, dynamic> json) {
    return GreetingConfig(
      morning: json['morning'] ?? 'Good morning, {name}!',
      afternoon: json['afternoon'] ?? 'Good afternoon, {name}!',
      evening: json['evening'] ?? 'Good evening, {name}!',
      night: json['night'] ?? 'Good night, {name}!',
    );
  }
}

class StreakConfig {
  final String multiDayLabel;
  final String zeroLabel;

  StreakConfig({required this.multiDayLabel, required this.zeroLabel});

  factory StreakConfig.fromJson(Map<String, dynamic> json) {
    return StreakConfig(
      multiDayLabel: json['multi_day_label'] ?? 'day streak! Keep going! 🔥',
      zeroLabel: json['zero_label'] ?? 'Ready to earn some stars? ⭐',
    );
  }
}

class ProgressConfig {
  final int maxStars;
  final String labelNotStarted;
  final String labelInProgress;
  final String labelLocked;

  ProgressConfig({
    required this.maxStars,
    required this.labelNotStarted,
    required this.labelInProgress,
    required this.labelLocked,
  });

  factory ProgressConfig.fromJson(Map<String, dynamic> json) {
    return ProgressConfig(
      maxStars: json['max_stars'] ?? 5,
      labelNotStarted: json['label_not_started'] ?? 'tap to start! 👆',
      labelInProgress: json['label_in_progress'] ?? 'your stars ⭐',
      labelLocked: json['label_locked'] ?? 'locked 🔒',
    );
  }
}
