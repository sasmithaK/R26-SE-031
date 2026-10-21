import 'package:flutter/material.dart';
import '../../../models/curriculum_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/telemetry_wrapper.dart';
import '../../../services/voice_analysis_service.dart';
import '../../../services/telemetry_service.dart';

/// Interactive Story Game
/// Shows images with a vertical scroll.
/// Text is overlaid cleanly at the bottom for an immersive reading experience.
class InteractiveStoryGame extends StatefulWidget {
  final ActivityNode activityNode;

  const InteractiveStoryGame({super.key, required this.activityNode});

  @override
  State<InteractiveStoryGame> createState() => _InteractiveStoryGameState();
}

class _InteractiveStoryGameState extends State<InteractiveStoryGame>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _pulseController;

  double _currentPage = 0.0;
  bool _readingStarted = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0.0;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    if (_isRecording) {
      // Leaving mid-recording: stop the microphone and discard the audio.
      VoiceAnalysisService().stopRecording();
    }
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _completeActivity() {
    Navigator.of(context).pop();
  }

  int _tStimulus = 0;
  int _tRecordStart = 0;
  int _stimulusPageIndex = -1;
  // The page (item) being read is fixed when recording starts, so a swipe
  // during recording cannot attach the audio to another item.
  int _recordingPageIndex = 0;

  /// Called when a page settles: the sentence is now on screen.
  void _onPageSettled(int index) {
    if (_stimulusPageIndex == index) return;
    _stimulusPageIndex = index;
    _tStimulus = DateTime.now().millisecondsSinceEpoch;
  }

  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _tRecordStart = DateTime.now().millisecondsSinceEpoch;
      _recordingPageIndex = _currentPage.round().clamp(
        0,
        widget.activityNode.rounds.length - 1,
      );
    });

    await VoiceAnalysisService().startRecording();
    if (!mounted) return;
    if (VoiceAnalysisService().lastError != null) {
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('මයික්‍රෆෝනය ආරම්භ කළ නොහැක. නැවත උත්සාහ කරන්න.'),
          backgroundColor: AppColors.warmAmber,
        ),
      );
    }
  }

  void _stopRecording(String targetSentence, int expectedSyllables) async {
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });

    final audioFile = await VoiceAnalysisService().stopRecording();
    if (!mounted) return;

    if (audioFile != null) {
      String? studentId;
      String sessionId = TelemetryService().sessionId;
      String activityId = widget.activityNode.id;
      final index = _recordingPageIndex;
      final round = widget.activityNode.rounds[index];
      String itemId = CanonicalItemResolver.resolve(
        widget.activityNode,
        round,
        index,
      ).itemId;

      final telemetry = TelemetryWrapper.of(context);
      if (telemetry != null) {
        studentId =
            (telemetry.widget.studentData?['id'] ??
                    telemetry.widget.studentData?['_id'] ??
                    telemetry.widget.studentData?['student_id'])
                ?.toString();
      }

      final results = await VoiceAnalysisService().analyzeAudio(
        audioFile,
        targetSentence,
        studentId: studentId,
        sessionId: sessionId,
        eventId: '$sessionId:$itemId:speech',
        attemptId: '$sessionId:$itemId:${_tRecordStart.toString()}',
        skillId: widget.activityNode.skillId,
        activityId: activityId,
        itemId: itemId,
        roundId: index.toString(),
        allowedVariants:
            (round['allowed_spoken_variants'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
        expectedSyllables: expectedSyllables,
        tStimulus: _tStimulus,
        tRecordStart: _tRecordStart,
      );

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });

      final status = results['measurement_status']?.toString();
      if (status == 'valid' || status == 'uncertain') {
        // C2 remains observation-only for C4. Recognition uncertainty is not
        // converted into a correct/incorrect adaptive-learning event.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'valid'
                  ? 'හොඳයි! (Great job!)'
                  : 'ඔබගේ කියවීම සටහන් කළා. (Reading saved.)',
            ),
            backgroundColor: AppColors.gentleGreen,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _pageController.hasClients) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      } else if (status == 'retry_required') {
        final issues =
            (results['recording_quality_issues'] as List?)
                ?.map((value) => value.toString())
                .join(', ') ??
            '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              issues.isEmpty
                  ? 'හඬ පැහැදිලි නැහැ. නැවත කියවමු.'
                  : 'හඬ පටිගත කිරීම පැහැදිලි නැහැ ($issues). නැවත කියවමු.',
            ),
            backgroundColor: AppColors.warmAmber,
          ),
        );
      } else {
        final message = results['user_message']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'දැනට හඬ විශ්ලේෂණයට සම්බන්ධ විය නොහැක. නැවත උත්සාහ කරන්න.'),
            backgroundColor: AppColors.warmAmber,
          ),
        );
      }
    } else {
      setState(() {
        _isAnalyzing = false;
      });
      final errorStr = VoiceAnalysisService().lastError ?? "Unknown error";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to record audio. Check permissions.\nError: $errorStr',
          ),
          backgroundColor: AppColors.softCoral,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_readingStarted) {
      return _buildStartScreen();
    }

    final rounds = widget.activityNode.rounds;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            // No swiping while a sentence is being recorded.
            physics: _isRecording || _isAnalyzing
                ? const NeverScrollableScrollPhysics()
                : null,
            onPageChanged: _onPageSettled,
            itemCount: rounds.length + 1, // +1 for the final completion page
            itemBuilder: (context, index) {
              if (index == rounds.length) {
                return _buildCompletionPage();
              }

              final round = rounds[index];
              return _buildStoryPage(index, round);
            },
          ),

          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 80,
              color: AppColors.calmBlue,
            ),
            const SizedBox(height: 24),
            Text(
              widget.activityNode.title,
              style: AppTypography.heading(fontSize: 28),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.activityNode.description,
              style: AppTypography.body(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                setState(() => _readingStarted = true);
                // The first sentence appears now (not when the start
                // screen appeared).
                _stimulusPageIndex = -1;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _onPageSettled(0);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.calmBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Start Reading',
                style: AppTypography.button(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryPage(int index, Map<String, dynamic> round) {
    final double offset = _currentPage - index;

    final String baseImgPath = 'assets/images/story/page ${index + 1}';
    final String fgPath = '${baseImgPath}_fg.png';
    final String bgPath = '${baseImgPath}_bg.jpg';
    final String originalPath =
        '$baseImgPath.png'; // Make sure this matches the copied pngs

    final targetSentence = round['prompt'] as String? ?? '';
    final overlays = round['overlays'] as List<dynamic>?;
    final expectedSyllables = round['expected_syllables'] as int? ?? 0;

    // t_stimulus is set when a page settles (_onPageSettled), not during
    // build: PageView builds neighbouring pages on every scroll frame.

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image (Parallax)
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(
              0,
              offset * MediaQuery.of(context).size.height * 0.2,
            ),
            child: _buildImage(
              bgPath,
              originalPath,
              BoxFit.contain,
              fallbackParallax: true,
              offset: offset,
            ),
          ),
        ),

        // Foreground Image (Parallax)
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(
              0,
              offset * MediaQuery.of(context).size.height * -0.1,
            ),
            child: _buildImage(fgPath, null, BoxFit.contain),
          ),
        ),

        // Dynamic Text Overlays
        if (overlays != null)
          ...overlays.map((o) {
            final double fontSize =
                (o['font_size'] as num?)?.toDouble() ?? 48.0;

            Color textColor = Colors.black87;
            if (o['color'] != null) {
              final hexCode = (o['color'] as String).replaceAll('#', '');
              if (hexCode.length == 6 || hexCode.length == 8) {
                textColor = Color(int.parse('0xFF$hexCode'));
              }
            }

            return Align(
              alignment: Alignment(
                o['align_x'] as double? ?? 0.0,
                o['align_y'] as double? ?? 0.0,
              ),
              child: Text(
                o['text'] as String,
                style:
                    AppTypography.sinhala(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          offset: const Offset(1, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                textAlign: TextAlign.center,
              ),
            );
          }),

        // Mic Overlay (Fixed at bottom)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // If no specific overlays, fallback to standard centered text
                  if (overlays == null)
                    Text(
                      targetSentence,
                      style: AppTypography.sinhala(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                  if (overlays == null) const SizedBox(height: 32),

                  // Analysis Loading
                  if (_isAnalyzing)
                    const Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.calmBlue),
                        SizedBox(height: 8),
                      ],
                    ),

                  // Mic Button
                  if (!_isAnalyzing)
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          if (_isRecording) {
                            _stopRecording(targetSentence, expectedSyllables);
                          } else {
                            _startRecording();
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 80,
                              height: 80,
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
                                          blurRadius:
                                              15 * _pulseController.value,
                                          spreadRadius:
                                              8 * _pulseController.value,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: AppColors.calmBlueDark
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Icon(
                                _isRecording ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 36,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Instruction / Hint
                  Text(
                    _isRecording
                        ? 'කියවා අවසන් වූ පසු නැවත ඔබන්න'
                        : 'කියවීම ආරම්භ කිරීමට ඔබන්න',
                    style: AppTypography.caption(
                      color: _isRecording
                          ? AppColors.softCoral
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black.withValues(alpha: 0.2),
                    size: 32,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(
    String path,
    String? fallbackPath,
    BoxFit fit, {
    bool fallbackParallax = false,
    double offset = 0,
  }) {
    return Image.asset(
      path,
      fit: fit,
      alignment: Alignment
          .topCenter, // Align images to top to preserve white space at bottom
      errorBuilder: (context, error, stackTrace) {
        if (fallbackPath != null) {
          Widget img = Image.asset(
            fallbackPath,
            fit: fit,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => Container(color: Colors.white),
          );

          if (fallbackParallax) {
            return Transform.translate(
              // Gentle vertical scroll effect for the fallback
              offset: Offset(
                0,
                offset * MediaQuery.of(context).size.height * -0.2,
              ),
              child: img,
            );
          }
          return img;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCompletionPage() {
    return Container(
      color: AppColors.mintBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 100,
              color: AppColors.gentleGreen,
            ),
            const SizedBox(height: 24),
            Text(
              'හොඳයි!',
              style: AppTypography.sinhala(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.gentleGreenDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ඔබ කතාව කියවා අවසන් කළා.',
              style: AppTypography.sinhala(
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _completeActivity,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gentleGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text('Finish', style: AppTypography.button(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
