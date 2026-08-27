import 'package:flutter/material.dart';
import '../utils/avatar_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../models/curriculum_models.dart';
import '../services/progress_service.dart';
import '../services/tts_service.dart';
import 'level_map_screen.dart';

class SkillIntroScreen extends StatefulWidget {
  final SkillDetail skillMap;
  final Map<String, dynamic>? studentData;

  const SkillIntroScreen({
    super.key,
    required this.skillMap,
    this.studentData,
  });

  @override
  State<SkillIntroScreen> createState() => _SkillIntroScreenState();
}

class _SkillIntroScreenState extends State<SkillIntroScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playIntroAudio();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playIntroAudio() async {
    final url = widget.skillMap.audioUrl;
    final text = widget.skillMap.introText.isNotEmpty
        ? widget.skillMap.introText
        : widget.skillMap.title;

    setState(() {
      _isPlayingAudio = true;
    });

    if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlayingAudio = false);
        });
      } catch (e) {
        debugPrint('Remote audio play error, falling back to TTS: $e');
        await TtsService().speak(text);
        if (mounted) setState(() => _isPlayingAudio = false);
      }
    } else {
      await TtsService().speak(text);
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  void _onStartPressed() async {
    await ProgressService().markSkillIntroSeen(widget.skillMap.id);
    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    String introText = widget.skillMap.introText;
    

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(widget.skillMap.title, style: AppTypography.sinhala(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const Spacer(),

              // Hero Illustration & Badge
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.calmBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Image.asset(
                    AvatarUtils.getCorrectedAvatarPath(widget.studentData?['avatar_url'] as String?, 'assets/images/characters/mascots/solo_blue.png'),
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                widget.skillMap.title,
                textAlign: TextAlign.center,
                style: AppTypography.sinhala(
                  fontSize: 26,
                  fontWeight: FontWeight.w700, // Cleaner rendering than w900
                  color: AppColors.textPrimary,
                  height: 1.3,
                  letterSpacing: 0.5,
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sinhala Intro Description Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      introText,
                      textAlign: TextAlign.center,
                      style: AppTypography.sinhala(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Speaker Button inside Intro Card
                    GestureDetector(
                      onTap: _playIntroAudio,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isPlayingAudio
                              ? AppColors.warmAmber
                              : AppColors.warmAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.warmAmber, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volume_up_rounded,
                              color: _isPlayingAudio ? Colors.white : AppColors.warmAmber,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isPlayingAudio ? 'අසා සිටින්න...' : 'සවන් දෙන්න',
                              style: AppTypography.sinhala(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _isPlayingAudio ? Colors.white : AppColors.warmAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Start Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onStartPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gentleGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                  ),
                  child: Text('ආරම්භ කරමු', style: AppTypography.button(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
