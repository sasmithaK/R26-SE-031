import 'package:flutter/material.dart';
import '../models/mbsv.dart';
import '../models/typography_config.dart';
import 'monitoring_service.dart';
import 'avli_service.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String type; // 'telemetry', 'mbsv', 'typography', 'system'

  LogEntry(this.message, this.type) : timestamp = DateTime.now();
}

enum EvaluationMode { fixed, adaptive }

class AdaptiveState extends ChangeNotifier {
  final MonitoringService _monitoring = MonitoringService();
  final AVLIService _avli = AVLIService();

  MBSV _currentMbsv = MBSV.initial();
  TypographyConfig _currentConfig = TypographyConfig.defaultConfig();
  int _currentArmId = 0;
  bool _gameModeTrigger = false;
  List<LogEntry> _logs = [];
  List<double> _rewardHistory = [];
  bool _isLoading = false;
  EvaluationMode _evaluationMode = EvaluationMode.adaptive;

  MBSV get currentMbsv => _currentMbsv;
  TypographyConfig get currentConfig => _currentConfig;
  int get currentArmId => _currentArmId;
  bool get gameModeTrigger => _gameModeTrigger;
  List<LogEntry> get logs => _logs;
  List<double> get rewardHistory => _rewardHistory;
  bool get isLoading => _isLoading;
  EvaluationMode get evaluationMode => _evaluationMode;

  void setEvaluationMode(EvaluationMode mode) {
    _evaluationMode = mode;
    addLog("Evaluation Mode Switched: ${mode.name.toUpperCase()}", "system");
    notifyListeners();
  }

  void resetGameTrigger() {
    if (_gameModeTrigger) {
      _gameModeTrigger = false;
      addLog("Gamification Context Reset", "system");
      notifyListeners();
    }
  }

  void addLog(String message, String type) {
    _logs.insert(0, LogEntry(message, type));
    if (_logs.length > 50) _logs.removeLast();
    notifyListeners();
  }

  Future<void> processInteraction({
    required String studentId,
    required Map<String, dynamic> telemetry,
    required Map<String, dynamic> context,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Individual telemetry logging for granular pedagogical monitoring
    telemetry.forEach((key, value) {
      addLog("Telemetry [$key]: $value", "telemetry");
    });

    // 1. Get MBSV from C1 (Always monitor even in fixed mode)
    final mbsv = await _monitoring.sendTelemetry(
      studentId: studentId,
      telemetry: telemetry,
    );
    _currentMbsv = mbsv;
    addLog("MBSV Updated: Visual=${mbsv.visualStrainIndex.toStringAsFixed(2)}, Engagement=${mbsv.engagementIndex.toStringAsFixed(2)}, Cognitive=${mbsv.cognitiveLoadIndex.toStringAsFixed(2)}", "mbsv");

    // 2. Handle Typography Adaptation
    if (_evaluationMode == EvaluationMode.adaptive) {
      final response = await _avli.getTypography(
        studentId: studentId,
        mbsv: mbsv,
        context: context,
      );
      _currentConfig = response.config;
      _currentArmId = response.armId;
      _gameModeTrigger = response.gameModeTrigger;
      
      // Highlight the 5 critical parameters in logs as requested for viva
      addLog("Typography Adapted (Arm $_currentArmId):", "typography");
      addLog("  > font_size: ${_currentConfig.fontSize}", "typography");
      addLog("  > letter_spacing: ${_currentConfig.letterSpacing}", "typography");
      addLog("  > word_spacing: ${_currentConfig.wordSpacing}", "typography");
      addLog("  > contrast: ${_currentConfig.backgroundContrast}", "typography");
      addLog("  > diacritic_offset: ${_currentConfig.diacriticOffset}", "typography");
    } else {
      addLog("Evaluation: FIXED MODE (Baseline UI preserved)", "system");
    }

    if (_gameModeTrigger) addLog("GAMIFICATION TRIGGERED: Engagement Recovery Required", "system");

    _isLoading = false;
    notifyListeners();
  }

  Future<void> submitReward({
    required String studentId,
    required int armId,
    required double reward,
  }) async {
    _rewardHistory.add(reward);
    if (_rewardHistory.length > 20) _rewardHistory.removeAt(0);

    if (_evaluationMode == EvaluationMode.fixed) {
      notifyListeners();
      return;
    }

    await _avli.sendReward(
      studentId: studentId, 
      armId: armId, 
      reward: reward,
      visualStrainBefore: _currentMbsv.visualStrainIndex,
      visualStrainAfter: _currentMbsv.visualStrainIndex * 0.9,
    );
    addLog("Reward Sent: $reward for Arm $armId", "system");
    notifyListeners();
  }
}
