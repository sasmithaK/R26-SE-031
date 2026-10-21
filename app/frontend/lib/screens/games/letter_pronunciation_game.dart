import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/curriculum_models.dart';
import '../../services/telemetry_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_analysis_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/telemetry_wrapper.dart';

/// One child-friendly listen-and-say flow shared by the vowel and consonant
/// letter banks. Each recording attempt is persisted independently by C2.
class LetterPronunciationGame extends StatefulWidget {
  final ActivityNode activityNode;
  final Map<String, dynamic>? studentData;

  const LetterPronunciationGame({
    super.key,
    required this.activityNode,
    this.studentData,
  });

  @override
  State<LetterPronunciationGame> createState() =>
      _LetterPronunciationGameState();
}

class _LetterPronunciationGameState extends State<LetterPronunciationGame> {
  static const _noVoiceLimit = 6;
  static const _recordingLimit = 12;

  int _roundIndex = 0;
  int _secondsLeft = _noVoiceLimit;
  int _attemptNumber = 0;
  int _stimulusAt = 0;
  int _recordingStartedAt = 0;
  bool _recording = false;
  bool _processing = false;
  bool _soundDetected = false;
  int _recordingGeneration = 0;
  bool _activityComplete = false;
  String? _status;
  Timer? _timer;

  List<Map<String, dynamic>> get _rounds => widget.activityNode.rounds;
  Map<String, dynamic> get _round => _rounds[_roundIndex];
  String get _letter =>
      _round['letter']?.toString() ?? _round['prompt']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _stimulusAt = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) unawaited(VoiceAnalysisService().stopRecording());
    super.dispose();
  }

  Future<void> _playReference() async {
    TelemetryWrapper.of(context)?.logAudioReplay();
    final played = await TtsService().speakOnDevice(
      _letter,
      waitUntilComplete: true,
      playbackRate: 0.85,
    );
    if (!played && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'සිංහල හඬ ලබාගත නොහැක. දුරකථනයේ Text-to-speech සැකසුම්වලින් Sinhala හඬ බාගත කර නැවත උත්සාහ කරන්න.',
          ),
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _processing || _activityComplete) return;
    _attemptNumber++;
    final generation = ++_recordingGeneration;
    _soundDetected = false;
    _secondsLeft = _noVoiceLimit;
    final recordStartedAt = DateTime.now().millisecondsSinceEpoch;
    _recordingStartedAt = recordStartedAt;
    await VoiceAnalysisService().startRecording(
      onSoundDetected: () {
        if (!mounted || _soundDetected || generation != _recordingGeneration) {
          return;
        }
        setState(() {
          _soundDetected = true;
          _secondsLeft = _recordingLimit - _noVoiceLimit;
        });
      },
    );
    if (!mounted) return;
    if (VoiceAnalysisService().lastError != null) {
      setState(() => _status = 'recording_failed');
      return;
    }
    setState(() {
      _recording = true;
      _status = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || generation != _recordingGeneration) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        unawaited(
          _finishRecording(recordStartedAt, noVoiceTimeout: !_soundDetected),
        );
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _finishRecording(
    int recordStartedAt, {
    bool noVoiceTimeout = false,
  }) async {
    if (!_recording || _processing) return;
    ++_recordingGeneration;
    _timer?.cancel();
    setState(() {
      _recording = false;
      _processing = true;
    });
    final audio = await VoiceAnalysisService().stopRecording();
    if (!mounted) return;
    if (audio == null) {
      setState(() {
        _processing = false;
        _status = 'recording_failed';
      });
      return;
    }

    if (noVoiceTimeout) {
      setState(() {
        _processing = false;
        _status = 'no_voice';
      });
      return;
    }

    final telemetry = TelemetryWrapper.of(context);
    final student = telemetry?.widget.studentData ?? widget.studentData ?? {};
    final studentId =
        student['student_id']?.toString() ??
        student['id']?.toString() ??
        student['_id']?.toString();
    final sessionId = TelemetryService().sessionId;
    final itemId = _round['item_id']?.toString() ?? '';
    final result = await VoiceAnalysisService().analyzeAudio(
      audio,
      _round['expected_text']?.toString() ?? _letter,
      studentId: studentId,
      sessionId: sessionId,
      eventId: '$sessionId:$itemId:letter',
      attemptId: '$sessionId:$itemId:$_attemptNumber:$recordStartedAt',
      skillId: widget.activityNode.skillId,
      taskKind: 'letter_pronunciation',
      activityId: widget.activityNode.id,
      itemId: itemId,
      roundId: _roundIndex.toString(),
      allowedVariants: (_round['allowed_spoken_variants'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      expectedSyllables: 1,
      tStimulus: _stimulusAt,
      tRecordStart: recordStartedAt,
    );
    if (!mounted) return;
    setState(() {
      _processing = false;
      final status = result['measurement_status']?.toString() ?? 'uncertain';
      final persistence = result['persistence_status']?.toString();
      if (persistence != null && persistence != 'saved') {
        _status = 'save_failed';
      } else if (result['retryable'] == true ||
          status == 'service_warming_up' ||
          status == 'service_timeout') {
        _status = 'service_retry';
      } else if (status == 'request_failed' || status == 'persistence_failed') {
        _status = 'save_failed';
      } else {
        _status = status == 'valid' ? 'saved' : 'retry';
      }
    });
  }

  void _nextLetter() {
    if (_roundIndex + 1 >= _rounds.length) {
      setState(() => _activityComplete = true);
      TelemetryWrapper.of(context)?.completeActivity(context);
      return;
    }
    setState(() {
      _roundIndex++;
      _attemptNumber = 0;
      _status = null;
      _soundDetected = false;
      _secondsLeft = _noVoiceLimit;
      _stimulusAt = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVowel = widget.activityNode.skillId == 'skill_sinhala_vowels';
    final statusText = switch (_status) {
      'saved' => 'හඬ සටහන් කළා. හොඳ උත්සාහයක්! ',
      'retry' => 'හඬ පැහැදිලිව මැනිය නොහැකි වුණා. නැවත උත්සාහ කරමු.',
      'no_voice' => 'ඔබේ හඬ ඇසුණේ නැහැ. මයික් එකට ළං වී නැවත උත්සාහ කරමු.',
      'service_retry' =>
        'විශ්ලේෂණ සේවාව සූදානම් වෙමින්. මොහොතකින් නැවත උත්සාහ කරමු.',
      'save_failed' => 'මෙම උත්සාහය සුරැකුණේ නැහැ. කරුණාකර නැවත උත්සාහ කරන්න.',
      'recording_failed' =>
        'පටිගත කළ නොහැක. මයික් අවසරය පරීක්ෂා කර නැවත උත්සාහ කරන්න.',
      _ =>
        _recording
            ? (_soundDetected ? 'හොඳයි, කියාගෙන යන්න!' : 'ඔබේ හඬ අසමින්...')
            : 'පළමුව අකුර අසා, පසුව මයික් බොත්තම ඔබන්න.',
    };
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.calmBlue.withValues(
                        alpha: .12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_roundIndex + 1} / ${_rounds.length}',
                    style: AppTypography.heading(fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(
                      isVowel
                          ? 'ස්වර අකුරු අසා කියවමු'
                          : 'ව්‍යංජන අකුරු අසා කියවමු',
                      textAlign: TextAlign.center,
                      style: AppTypography.sinhala(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: 220,
                      height: 220,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: AppColors.borderBlue,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x184A90D9),
                            blurRadius: 18,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Text(
                        _letter,
                        style: AppTypography.sinhala(
                          fontSize: 104,
                          fontWeight: FontWeight.w800,
                          color: AppColors.calmBlueDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _processing || _recording
                          ? null
                          : _playReference,
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('අකුරට සවන් දෙන්න'),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: FilledButton(
                        onPressed: _processing
                            ? null
                            : _recording
                            ? () => _finishRecording(_recordingStartedAt)
                            : _startRecording,
                        style: FilledButton.styleFrom(
                          backgroundColor: _recording
                              ? AppColors.softCoral
                              : AppColors.calmBlue,
                          shape: const CircleBorder(),
                        ),
                        child: _processing
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _recording
                                        ? Icons.stop_rounded
                                        : Icons.mic_rounded,
                                    size: 34,
                                  ),
                                  if (_recording)
                                    Text(
                                      '$_secondsLeft s',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: AppTypography.sinhala(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_attemptNumber > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'මෙම අකුර සඳහා උත්සාහ $_attemptNumber',
                        style: AppTypography.sinhala(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _recording || _processing ? null : _nextLetter,
                      icon: Icon(
                        _roundIndex + 1 == _rounds.length
                            ? Icons.flag_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _roundIndex + 1 == _rounds.length
                            ? 'අවසන් කරන්න'
                            : 'ඊළඟ අකුර',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
