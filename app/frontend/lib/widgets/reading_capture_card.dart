import 'dart:async';

import 'package:flutter/material.dart';

import '../models/curriculum_models.dart';
import '../services/telemetry_service.dart';
import '../services/voice_analysis_service.dart';
import '../theme/app_theme.dart';
import 'telemetry_wrapper.dart';

/// Child-friendly, non-blocking C2 capture used by Skills 5 and 6.
///
/// A failed or uncertain machine measurement is stored as such and never shown
/// to the child as a reading failure.
class ReadingCaptureCard extends StatefulWidget {
  final ActivityNode activity;
  final Map<String, dynamic> round;
  final int roundIndex;

  const ReadingCaptureCard({
    super.key,
    required this.activity,
    required this.round,
    required this.roundIndex,
  });

  @override
  State<ReadingCaptureCard> createState() => _ReadingCaptureCardState();
}

class _ReadingCaptureCardState extends State<ReadingCaptureCard> {
  bool _recording = false;
  bool _processing = false;
  String? _status;
  int _stimulusAt = DateTime.now().millisecondsSinceEpoch;
  int _recordingAt = 0;
  int _attempt = 0;

  @override
  void dispose() {
    if (_recording) {
      unawaited(VoiceAnalysisService().stopRecording());
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReadingCaptureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roundIndex != widget.roundIndex) {
      _stimulusAt = DateTime.now().millisecondsSinceEpoch;
      _status = null;
      _attempt = 0;
    }
  }

  Future<void> _toggle() async {
    if (_processing) return;
    if (!_recording) {
      _recordingAt = DateTime.now().millisecondsSinceEpoch;
      await VoiceAnalysisService().startRecording();
      if (!mounted) return;
      if (VoiceAnalysisService().lastError != null) {
        setState(() => _status = 'recording_failed');
        return;
      }
      setState(() {
        _recording = true;
        _status = null;
      });
      return;
    }

    setState(() {
      _recording = false;
      _processing = true;
    });
    final audio = await VoiceAnalysisService().stopRecording();
    if (audio == null) {
      if (mounted) {
        setState(() {
          _processing = false;
          _status = 'recording_failed';
        });
      }
      return;
    }

    if (!mounted) return;
    _attempt += 1;
    final telemetry = TelemetryWrapper.of(context);
    final studentId =
        telemetry?.widget.studentData?['id']?.toString() ??
        telemetry?.widget.studentData?['_id']?.toString();
    final sessionId = TelemetryService().sessionId;
    final canonical = CanonicalItemResolver.resolve(
      widget.activity,
      widget.round,
      widget.roundIndex,
    );
    final expectedText = widget.round['prompt']?.toString() ?? '';
    final variants =
        (widget.round['allowed_spoken_variants'] as List?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[];
    final result = await VoiceAnalysisService().analyzeAudio(
      audio,
      expectedText,
      studentId: studentId,
      sessionId: sessionId,
      eventId: '$sessionId:${canonical.itemId}:speech',
      // Unique per recording: the record-start time keeps a re-recording
      // (or a rebuilt widget) from overwriting an earlier attempt.
      attemptId: '$sessionId:${canonical.itemId}:speech:$_attempt:$_recordingAt',
      skillId: widget.activity.skillId,
      activityId: widget.activity.id,
      itemId: canonical.itemId,
      roundId: widget.roundIndex.toString(),
      allowedVariants: variants,
      expectedSyllables: widget.round['expected_syllables'] as int? ?? 0,
      tStimulus: _stimulusAt,
      tRecordStart: _recordingAt,
    );
    if (!mounted) return;
    setState(() {
      _processing = false;
      _status = result['measurement_status']?.toString() ?? 'request_failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusText = switch (_status) {
      'valid' => 'කියවීම සටහන් කළා ✓',
      'uncertain' => 'කියවීම සටහන් කළා ✓',
      'retry_required' => 'හඬ පැහැදිලි නැහැ. නැවත උත්සාහ කරමු.',
      'recording_failed' ||
      'request_failed' ||
      'persistence_failed' => 'පටිගත කිරීමට නොහැකි විය. නැවත උත්සාහ කරන්න.',
      _ => 'වාක්‍යය කියවා හඬ සටහන් කරන්න',
    };
    return Semantics(
      button: true,
      label: statusText,
      child: Card(
        color: AppColors.calmBlue.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _processing ? null : _toggle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _recording
                      ? AppColors.softCoral
                      : AppColors.calmBlue,
                  child: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _recording ? 'අවසන් වූ පසු මෙතැන ඔබන්න' : statusText,
                    style: AppTypography.sinhala(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
