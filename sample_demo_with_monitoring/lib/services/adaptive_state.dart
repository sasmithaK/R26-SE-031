import 'package:flutter/material.dart';
import '../models/mbsv.dart';
import '../models/typography_config.dart';
import 'monitoring_service.dart';
import 'avli_service.dart';

enum EvaluationMode { fixed, adaptive }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String type; // 'telemetry', 'mbsv', 'typography', 'system'

  LogEntry(this.message, this.type) : timestamp = DateTime.now();
}

class AdaptiveState extends ChangeNotifier {
  final MonitoringService _monitoring = MonitoringService();
  final AVLIService _avli = AVLIService();

  MBSV _currentMbsv = MBSV.initial();
  TypographyConfig _currentConfig = TypographyConfig.defaultConfig();
  int _currentArmId = 0;
  bool _gameModeTrigger = false;
  List<LogEntry> _logs = [];
  bool _isLoading = false;
  
  EvaluationMode _evaluationMode = EvaluationMode.adaptive;
  List<double> _rewardHistory = [];

  MBSV get currentMbsv => _currentMbsv;
  TypographyConfig get currentConfig => _currentConfig;
  int get currentArmId => _currentArmId;
  bool get gameModeTrigger => _gameModeTrigger;
  List<LogEntry> get logs => _logs;
  bool get isLoading => _isLoading;
  EvaluationMode get evaluationMode => _evaluationMode;
  List<double> get rewardHistory => _rewardHistory;

  void addLog(String message, String type) {
    _logs.insert(0, LogEntry(message, type));
    if (_logs.length > 100) _logs.removeLast();
    notifyListeners();
  }

  void setEvaluationMode(EvaluationMode mode) {
    _evaluationMode = mode;
    if (mode == EvaluationMode.fixed) {
      _currentConfig = TypographyConfig.defaultConfig();
      addLog("System switched to FIXED mode (Baseline Typography)", "system");
    } else {
      addLog("System switched to ADAPTIVE mode (LinUCB Active)", "system");
    }
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
    // Highlighted with '>' for the log interface as requested
    telemetry.forEach((key, value) {
      addLog("> Telemetry [$key]: $value", "telemetry");
    });

    try {
      // 1. Get MBSV from C1 (Always done for monitoring)
      final mbsv = await _monitoring.sendTelemetry(
        studentId: studentId,
        telemetry: telemetry,
      );
      _currentMbsv = mbsv;
      addLog("MBSV Updated: Visual=${mbsv.visualStrainIndex.toStringAsFixed(2)}, Engagement=${mbsv.engagementIndex.toStringAsFixed(2)}, Cognitive=${mbsv.cognitiveLoadIndex.toStringAsFixed(2)}", "mbsv");

      // 2. Get Typography from C2 if in adaptive mode
      if (_evaluationMode == EvaluationMode.adaptive) {
        final response = await _avli.getTypography(
          studentId: studentId,
          mbsv: mbsv,
          context: context,
        );
        _currentConfig = response.config;
        _currentArmId = response.armId;
        _gameModeTrigger = response.gameModeTrigger;
        
        addLog("Typography Adapted: Arm $_currentArmId (${_currentConfig.fontFamily})", "typography");
        addLog("> Font Size: ${_currentConfig.fontSize}", "typography");
        addLog("> Letter Spacing: ${_currentConfig.letterSpacing}", "typography");
        addLog("> Word Spacing: ${_currentConfig.wordSpacing}", "typography");
        addLog("> Contrast: ${_currentConfig.backgroundContrast}", "typography");
        addLog("> Diacritic Offset: ${_currentConfig.diacriticOffset}", "typography");
        
        if (_gameModeTrigger) addLog("GAMIFICATION TRIGGERED: Engagement Recovery Required", "system");
      }
    } catch (e) {
      addLog("Sync Error: $e", "system");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> submitReward({
    required String studentId,
    required int armId,
    required double reward,
  }) async {
    try {
      _rewardHistory.add(reward);
      if (_rewardHistory.length > 20) _rewardHistory.removeAt(0);

      await _avli.sendReward(
        studentId: studentId, 
        armId: armId, 
        reward: reward,
        visualStrainBefore: _currentMbsv.visualStrainIndex,
        visualStrainAfter: _currentMbsv.visualStrainIndex * 0.9, 
      );
      addLog("Reward Submitted: $reward for Arm $armId", "system");
    } catch (e) {
      addLog("Reward Submit Error: $e", "system");
    }
    notifyListeners();
  }

  void resetGameTrigger() {
    _gameModeTrigger = false;
    addLog("Gamification Session Completed", "system");
    notifyListeners();
  }

  Future<MBSV> sendTelemetry({
    required Map<String, dynamic> telemetry,
  }) async {
    try {
      final mbsv = await _monitoring.sendTelemetry(
        studentId: telemetry['student_id'] ?? 'DEMO_STUDENT_001',
        telemetry: telemetry,
      );
      _currentMbsv = mbsv;
      addLog("MBSV Received: CLI=${mbsv.cognitiveLoadIndex.toStringAsFixed(2)}, PSI=${mbsv.phonologicalStrainIndex.toStringAsFixed(2)}", "mbsv");
      notifyListeners();
      return mbsv;
    } catch (e) {
      addLog("C1 Error: $e", "system");
      notifyListeners();
      return MBSV.initial();
    }
  }
}
