import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// MBSV (Multimodal Behavioral Strain Vector) snapshot
class MBSVSnapshot {
  final double visualStrainIndex;
  final double cognitiveLoadIndex;
  final double phonologicalStrainIndex;
  final double engagementIndex;
  final double sessionFatigueIndex;
  final List<int> errorPatternVector;
  final DateTime timestamp;

  MBSVSnapshot({
    this.visualStrainIndex = 0.0,
    this.cognitiveLoadIndex = 0.0,
    this.phonologicalStrainIndex = 0.0,
    this.engagementIndex = 0.5,
    this.sessionFatigueIndex = 0.0,
    this.errorPatternVector = const [0, 0, 0, 0],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Deserialize from JSON returned by C1
  factory MBSVSnapshot.fromJson(Map<String, dynamic> json) {
    try {
      return MBSVSnapshot(
        visualStrainIndex: (json['visual_strain_index'] as num? ?? 0).toDouble(),
        cognitiveLoadIndex: (json['cognitive_load_index'] as num? ?? 0).toDouble(),
        phonologicalStrainIndex: (json['phonological_strain_index'] as num? ?? 0).toDouble(),
        engagementIndex: (json['engagement_index'] as num? ?? 0.5).toDouble(),
        sessionFatigueIndex: (json['session_fatigue_index'] as num? ?? 0).toDouble(),
        errorPatternVector: (json['error_pattern_vector'] as List?)?.cast<int>() ?? [0, 0, 0, 0],
      );
    } catch (e) {
      debugPrint('Error parsing MBSV snapshot: $e');
      return MBSVSnapshot();
    }
  }

  @override
  String toString() =>
      'MBSV(v=$visualStrainIndex, c=$cognitiveLoadIndex, p=$phonologicalStrainIndex, e=$engagementIndex, f=$sessionFatigueIndex)';
}

/// Service that polls C1 for MBSV updates and broadcasts to the app
class MBSVListenerService extends ChangeNotifier {
  static final MBSVListenerService _instance = MBSVListenerService._();

  factory MBSVListenerService() => _instance;

  MBSVListenerService._();

  /// Current MBSV snapshot
  MBSVSnapshot current = MBSVSnapshot();

  /// Polling timer
  Timer? _timer;
  bool isRunning = false;
  DateTime? lastSuccessfulPoll;
  int successfulPollCount = 0;

  /// Start polling for MBSV updates
  void start(String studentId, {Duration interval = const Duration(seconds: 5)}) {
    if (isRunning) {
      debugPrint('[MBSV] Already running for $studentId');
      return;
    }

    isRunning = true;
    _timer?.cancel();

    // Poll immediately
    _poll(studentId);

    // Then poll periodically
    _timer = Timer.periodic(interval, (_) => _poll(studentId));
    debugPrint('[MBSV] Polling started for student: $studentId, interval: ${interval.inSeconds}s');
  }

  /// Stop polling
  void stop() {
    _timer?.cancel();
    isRunning = false;
    debugPrint('[MBSV] Polling stopped');
  }

  /// Poll C1 for current MBSV
  Future<void> _poll(String studentId) async {
    try {
      final url = '${ApiConfig.monitoringUrl}/mbsv/$studentId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // The response might be wrapped in an 'mbsv' field
        final mbsvData = json['mbsv'] ?? json;
        final newSnapshot = MBSVSnapshot.fromJson(mbsvData);

        // Only notify if values changed significantly
        if (_hasSignificantChange(newSnapshot)) {
          current = newSnapshot;
          lastSuccessfulPoll = DateTime.now();
          successfulPollCount++;
          notifyListeners();
          debugPrint('[MBSV] Updated: $current');
        }
      } else {
        debugPrint('[MBSV] C1 returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[MBSV] Poll error: $e');
      // Keep last known value — don't reset
    }
  }

  /// Check if new snapshot has significant changes (avoid unnecessary rebuilds)
  bool _hasSignificantChange(MBSVSnapshot newSnapshot) {
    const threshold = 0.05; // 5% change threshold
    return ((_getDistance(current.visualStrainIndex, newSnapshot.visualStrainIndex) > threshold) ||
        (_getDistance(current.phonologicalStrainIndex, newSnapshot.phonologicalStrainIndex) > threshold) ||
        (_getDistance(current.engagementIndex, newSnapshot.engagementIndex) > threshold));
  }

  double _getDistance(double a, double b) => (a - b).abs();

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
