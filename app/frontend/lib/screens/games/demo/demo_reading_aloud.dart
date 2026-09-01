import 'package:flutter/material.dart';
import '../../../models/curriculum_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/telemetry_wrapper.dart';
import '../../../services/voice_analysis_service.dart';

class DemoReadingAloud extends StatefulWidget {
  final ActivityNode activityNode;

  const DemoReadingAloud({super.key, required this.activityNode});

  @override
  State<DemoReadingAloud> createState() => _DemoReadingAloudState();
}

class _DemoReadingAloudState extends State<DemoReadingAloud>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isAnalyzing = false;

  final String _targetSentence = "අම්මා කිරි බොයි"; // Sample Sinhala sentence
  Map<String, dynamic>? _analysisResults;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _analysisResults = null;
    });

    // Telemetry wrapper state manages standard interaction logging.

    await VoiceAnalysisService().startRecording();
  }

  void _stopRecording() async {
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });

    final telemetry = TelemetryWrapper.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Stop recording and get the file
    final audioFile = await VoiceAnalysisService().stopRecording();

    if (audioFile != null) {
      String? studentId;
      String sessionId = DateTime.now().toIso8601String();
      String activityId = widget.activityNode.id;
      String itemId = 'demo_item';
      
      if (telemetry != null) {
        studentId = telemetry.widget.studentData?['id']?.toString() ?? telemetry.widget.studentData?['_id']?.toString();
      }
      
      if (studentId == null || studentId.isEmpty) {
        debugPrint('Voice analysis skipped: No valid student ID found in session context.');
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
          });
        }
        return;
      }
      
      final results = await VoiceAnalysisService().analyzeAudio(
        audioFile,
        _targetSentence,
        studentId: studentId,
        sessionId: sessionId,
        activityId: activityId,
        itemId: itemId,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisResults = results;
        });
      }

      // Log the WER to the Telemetry Wrapper
      final double wer = (results['word_error_rate'] ?? 1.0) as double;

      // Finish the round based on WER
      if (wer < 0.5) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            telemetry?.completeRound(
              100,
              selectedAnswers: [_targetSentence],
              errorType: 'none',
            );
          }
        });
      } else {
        // Did not read well enough, let them try again
        telemetry?.logAttempt(
          isCorrect: false,
          selectedAnswers: [_targetSentence],
          errorType: 'unknown_error', // STT errors should not create child behavioral errors for C1
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Please try reading that again clearly!'),
              backgroundColor: AppColors.warmAmber,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to record audio. Check permissions.'),
            backgroundColor: AppColors.softCoral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Reading Practice',
                style: AppTypography.heading(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Press and hold the microphone to read the sentence below.',
                style: AppTypography.body(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Target Sentence Card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.calmBlue.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  _targetSentence,
                  style: const TextStyle(
                    fontFamily: 'AbhayaLibre',
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppColors.calmBlueDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 48),

              if (_isAnalyzing)
                const Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.calmBlue),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing speech...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),

              if (_analysisResults != null && !_isAnalyzing)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.slateBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'You said: "${_analysisResults!['transcription']}"',
                        style: AppTypography.body(color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Word Error Rate: ${(_analysisResults!['word_error_rate'] * 100).toStringAsFixed(1)}%',
                        style: AppTypography.caption(
                          color: _analysisResults!['word_error_rate'] < 0.5
                              ? AppColors.gentleGreen
                              : AppColors.softCoral,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Microphone Button
              GestureDetector(
                onTapDown: (_) => _startRecording(),
                onTapUp: (_) => _stopRecording(),
                onTapCancel: () {
                  if (_isRecording) _stopRecording();
                },
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? AppColors.softCoral
                            : AppColors.calmBlue,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: AppColors.softCoral.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 20 * _pulseController.value,
                                  spreadRadius: 10 * _pulseController.value,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: AppColors.calmBlueDark.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 48,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isRecording ? 'Release to Send' : 'Hold to Speak',
                style: AppTypography.caption(
                  color: _isRecording
                      ? AppColors.softCoral
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
