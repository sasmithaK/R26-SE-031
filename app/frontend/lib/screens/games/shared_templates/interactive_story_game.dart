import 'package:flutter/material.dart';
import '../../../models/curriculum_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/telemetry_wrapper.dart';
import '../../../services/voice_analysis_service.dart';

/// Interactive Story Game
/// Shows images with a vertical scroll.
/// Text is overlaid cleanly at the bottom for an immersive reading experience.
class InteractiveStoryGame extends StatefulWidget {
  final ActivityNode activityNode;

  const InteractiveStoryGame({
    super.key,
    required this.activityNode,
  });

  @override
  State<InteractiveStoryGame> createState() => _InteractiveStoryGameState();
}

class _InteractiveStoryGameState extends State<InteractiveStoryGame> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _pulseController;
  
  double _currentPage = 0.0;
  bool _readingStarted = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  
  Map<String, dynamic>? _analysisResults;

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
    
    // Add hardware diagnostic popup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDiagnostic();
    });
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _runDiagnostic() async {
    final report = await VoiceAnalysisService().runHardwareDiagnostic();
    if (mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Hardware Diagnostic'),
          content: SingleChildScrollView(child: Text(report)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            )
          ],
        )
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _completeActivity() {
    Navigator.of(context).pop();
  }
  
  int _tStimulus = 0;
  int _tRecordStart = 0;
  int _lastStimulusPageIndex = -1;

  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _analysisResults = null;
      _tRecordStart = DateTime.now().millisecondsSinceEpoch;
    });

    await VoiceAnalysisService().startRecording();
  }

  void _stopRecording(String targetSentence, int expectedSyllables) async {
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });

    final audioFile = await VoiceAnalysisService().stopRecording();

    if (audioFile != null) {
      final results = await VoiceAnalysisService().analyzeAudio(
        audioFile,
        targetSentence,
        expectedSyllables: expectedSyllables,
        tStimulus: _tStimulus,
        tRecordStart: _tRecordStart,
      );

      setState(() {
        _isAnalyzing = false;
        _analysisResults = results;
      });
      
      // Log the acoustic metrics to telemetry
      final telemetry = TelemetryWrapper.of(context);
      if (telemetry != null) {
        debugPrint('TELEMETRY (Acoustic): Latency=${results['Acoustic_Latency_ms']}, PeakDelta=${results['Peak_Count_Delta']}, Jitter=${results['Local_Jitter']}, Shimmer=${results['Local_Shimmer']}');
        // Currently, TelemetryWrapper doesn't have a specific method for these yet, but we log it to console as requested.
        // If there was a logCustomMetric method we could use it: telemetry.logCustomMetric(results);
      }

      // We are logging these metrics, so we can always pass them for now since it's zero-shot
      // We check word error rate as a fallback just in case STT ran, but primarily we proceed.
      final double wer = (results['word_error_rate'] ?? 0.0) as double;

      if (wer < 0.5) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('හොඳයි! (Great job!)'),
            backgroundColor: AppColors.gentleGreen,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _pageController.hasClients) {
            _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
          }
        });
      } else {
        // Still allow progression if the WER is high since we are transitioning to Acoustic, 
        // but let's prompt them to try again if it completely failed.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('තව පාරක් උත්සාහ කරන්න. (Try reading that again!)'),
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
          content: Text('Failed to record audio. Check permissions.\nError: $errorStr'),
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
            const Icon(Icons.menu_book_rounded, size: 80, color: AppColors.calmBlue),
            const SizedBox(height: 24),
            Text(
              widget.activityNode.title,
              style: AppTypography.heading(fontSize: 28),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.activityNode.description,
              style: AppTypography.body(fontSize: 18, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                setState(() => _readingStarted = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.calmBlue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
    final String originalPath = '$baseImgPath.png'; // Make sure this matches the copied pngs
    
    final targetSentence = round['prompt'] as String? ?? '';
    final overlays = round['overlays'] as List<dynamic>?;
    final expectedSyllables = round['expected_syllables'] as int? ?? 0;

    // Capture t_stimulus when the page is first rendered
    if (_lastStimulusPageIndex != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _lastStimulusPageIndex = index;
          _tStimulus = DateTime.now().millisecondsSinceEpoch;
        }
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image (Parallax)
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, offset * MediaQuery.of(context).size.height * 0.2),
            child: _buildImage(bgPath, originalPath, BoxFit.contain, fallbackParallax: true, offset: offset),
          ),
        ),

        // Foreground Image (Parallax)
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, offset * MediaQuery.of(context).size.height * -0.1),
            child: _buildImage(fgPath, null, BoxFit.contain), 
          ),
        ),

        // Dynamic Text Overlays
        if (overlays != null)
          ...overlays.map((o) {
            final double fontSize = (o['font_size'] as num?)?.toDouble() ?? 48.0;
            
            Color textColor = Colors.black87;
            if (o['color'] != null) {
              final hexCode = (o['color'] as String).replaceAll('#', '');
              if (hexCode.length == 6 || hexCode.length == 8) {
                textColor = Color(int.parse('0xFF$hexCode'));
              }
            }

            return Align(
              alignment: Alignment(o['align_x'] as double? ?? 0.0, o['align_y'] as double? ?? 0.0),
              child: Text(
                o['text'] as String,
                style: AppTypography.sinhala(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ).copyWith(
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        offset: const Offset(1, 1),
                        blurRadius: 4,
                      )
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
                        onTapDown: (_) => _startRecording(),
                        onTapUp: (_) => _stopRecording(targetSentence, expectedSyllables),
                        onTapCancel: () {
                          if (_isRecording) _stopRecording(targetSentence, expectedSyllables);
                        },
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRecording ? AppColors.softCoral : AppColors.calmBlue,
                                boxShadow: _isRecording
                                    ? [
                                        BoxShadow(
                                          color: AppColors.softCoral.withValues(alpha: 0.6),
                                          blurRadius: 15 * _pulseController.value,
                                          spreadRadius: 8 * _pulseController.value,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: AppColors.calmBlueDark.withValues(alpha: 0.3),
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
                    _isRecording ? 'Release to Check' : 'Hold & Read',
                    style: AppTypography.caption(
                      color: _isRecording ? AppColors.softCoral : AppColors.textSecondary,
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

  Widget _buildImage(String path, String? fallbackPath, BoxFit fit, {bool fallbackParallax = false, double offset = 0}) {
    return Image.asset(
      path,
      fit: fit,
      alignment: Alignment.topCenter, // Align images to top to preserve white space at bottom
      errorBuilder: (context, error, stackTrace) {
        if (fallbackPath != null) {
          Widget img = Image.asset(
            fallbackPath,
            fit: fit,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(color: Colors.white),
          );
          
          if (fallbackParallax) {
            return Transform.translate(
              // Gentle vertical scroll effect for the fallback
              offset: Offset(0, offset * MediaQuery.of(context).size.height * -0.2), 
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
            const Icon(Icons.check_circle_outline_rounded, size: 100, color: AppColors.gentleGreen),
            const SizedBox(height: 24),
            Text(
              'හොඳයි!', 
              style: AppTypography.sinhala(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.gentleGreenDark),
            ),
            const SizedBox(height: 16),
            Text(
              'ඔබ කතාව කියවා අවසන් කළා.',
              style: AppTypography.sinhala(fontSize: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _completeActivity,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gentleGreen,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Finish',
                style: AppTypography.button(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
