import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/monster_character.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/gradient_button.dart';
import 'select_student_screen.dart';
import '../services/localization_service.dart';

/// Screen 3: Character Introduction & App Onboarding
/// Dyslexia-accessible: crème bg, calm blue accents.
class CharacterIntroScreen extends StatefulWidget {
  const CharacterIntroScreen({super.key});

  @override
  State<CharacterIntroScreen> createState() => _CharacterIntroScreenState();
}

class _CharacterIntroScreenState extends State<CharacterIntroScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPageIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SelectStudentScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.cream,
          body: Stack(
            children: [
              // Subtle gradient accent — warm amber glow
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.warmAmber.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Top bar with back button and progress indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _buildBackButton(context),
                          const Spacer(),
                          // Progress indicator dots
                          Row(
                            children: List.generate(3, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _currentPageIndex == i ? 24 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: _currentPageIndex == i
                                      ? AppColors.calmBlue
                                      : AppColors.borderLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    // PageView Content
                    Expanded(
                      child: SlideTransition(
                        position: _contentSlide,
                        child: FadeTransition(
                          opacity: _contentFade,
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPageIndex = index;
                              });
                            },
                            children: [
                              _buildPage1(),
                              _buildPage2(),
                              _buildPage3(),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Action Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SlideTransition(
                        position: _contentSlide,
                        child: FadeTransition(
                          opacity: _contentFade,
                          child: GradientButton(
                            text: _currentPageIndex == 2
                                ? LocalizationService.instance.t('get_started_btn')
                                : LocalizationService.instance.t('continue_btn'),
                            onPressed: _nextPage,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPage1() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        SpeechBubble(
          text: LocalizationService.instance.t('intro_page1_title'),
          delay: const Duration(milliseconds: 600),
        ),
        const SizedBox(height: 16),
        const MonsterCharacter(
          size: 220,
          animation: MonsterAnimation.excited,
          showBody: true,
          imagePath: 'assets/images/characters/mascots/solo_yellow_straight.png',
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildPage2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        SpeechBubble(
          text: LocalizationService.instance.t('intro_page2_title'),
          delay: const Duration(milliseconds: 600),
        ),
        const SizedBox(height: 16),
        const MonsterCharacter(
          size: 220,
          animation: MonsterAnimation.wave,
          showBody: true,
          imagePath: 'assets/images/characters/mascots/solo_blue.png',
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildPage3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        SpeechBubble(
          text: LocalizationService.instance.t('intro_page3_title'),
          delay: const Duration(milliseconds: 600),
        ),
        const SizedBox(height: 16),
        const MonsterCharacter(
          size: 220,
          animation: MonsterAnimation.idle,
          showBody: true,
          imagePath: 'assets/images/characters/mascots/solo_pink.png',
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    if (_currentPageIndex == 0) {
      // Hide the back button on the first slide
      return const SizedBox(width: 48, height: 48);
    }

    return GestureDetector(
      onTap: () {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimary,
          size: 22,
        ),
      ),
    );
  }
}
