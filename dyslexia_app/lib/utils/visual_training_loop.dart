import '../services/visual_service.dart';
import '../services/task_score_service.dart';
import 'logger.dart';

class VisualTrainingLoop {
  static final VisualTrainingLoop _instance = VisualTrainingLoop._internal();
  factory VisualTrainingLoop() => _instance;
  VisualTrainingLoop._internal();

  int? _currentArmId;
  double? _strainBefore;
  String? _sessionId;
  String? _studentId;

  /// Call this when a game level starts with a specific typography config
  void startLevel({
    required int armId,
    required double visualStrainBefore,
    required String sessionId,
    required String studentId,
  }) {
    _currentArmId = armId;
    _strainBefore = visualStrainBefore;
    _sessionId = sessionId;
    _studentId = studentId;
    AppLogger.info('🎯 MAB Training Started: Arm $_currentArmId, Strain Before: $_strainBefore');
  }

  /// Call this after telemetry is flushed and task is complete
  Future<void> endLevel({double accuracyDelta = 0.0}) async {
    if (_currentArmId == null || _strainBefore == null || _studentId == null) {
      AppLogger.warning('⚠️ MAB Training: Skipping reward because session info is missing');
      return;
    }

    try {
      // 1. Wait a moment for C1 to process telemetry and update MBSV
      await Future.delayed(const Duration(seconds: 2));

      // 2. Fetch updated behavioral state from C1
      final mbsvData = await TaskScoreService.getLatestMBSV(_studentId!);
      double strainAfter = _strainBefore!; // fallback

      if (mbsvData != null && mbsvData['mbsv'] != null) {
        strainAfter = (mbsvData['mbsv']['visual_strain_index'] as num).toDouble();
      }

      AppLogger.info('📈 MAB Reward Data: Strain Before: $_strainBefore, After: $strainAfter, AccDelta: $accuracyDelta');

      // 3. Send reward to C2 Visual Service
      final success = await VisualService.sendReward(
        studentId: _studentId!,
        sessionId: _sessionId ?? 'manual_reward',
        armId: _currentArmId!,
        strainBefore: _strainBefore!,
        strainAfter: strainAfter,
        accuracyDelta: accuracyDelta,
      );

      if (success) {
        AppLogger.info('✅ MAB Reward Sent Successfully');
      } else {
        AppLogger.error('❌ MAB Reward Failed');
      }
    } catch (e) {
      AppLogger.error('❌ MAB Training Loop Error', error: e);
    } finally {
      // Clear for next round
      _currentArmId = null;
      _strainBefore = null;
    }
  }
}
