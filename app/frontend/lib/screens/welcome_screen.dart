import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

import 'signin_screen.dart';
import 'signup_screen.dart';
import '../services/localization_service.dart';

/// Screen 2: Welcome / Get Started
/// Dyslexia-accessible: warm crème top, pale slate blue bottom,
/// dark grey text, calm blue buttons.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _topController;
  late AnimationController _characterController;
  late AnimationController _buttonController;
  late AnimationController _bounceController;

  late Animation<double> _topFadeAnimation;
  late Animation<double> _topSlideAnimation;
  late Animation<double> _characterScaleAnimation;
  late Animation<double> _characterFadeAnimation;
  late Animation<double> _buttonFadeAnimation;
  late Animation<Offset> _buttonSlideAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _topController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _topFadeAnimation = CurvedAnimation(
      parent: _topController,
      curve: Curves.easeOut,
    );
    _topSlideAnimation = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(parent: _topController, curve: Curves.easeOutCubic),
    );

    _characterController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _characterScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _characterController,
        curve: Curves.elasticOut,
      ),
    );
    _characterFadeAnimation = CurvedAnimation(
      parent: _characterController,
      curve: Curves.easeOut,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _buttonFadeAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    );
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOutCubic),
    );

    _topController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _characterController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        _bounceController.repeat(reverse: true);
        _buttonController.forward();
      }
    });
  }

  @override
  void dispose() {
    _topController.dispose();
    _characterController.dispose();
    _buttonController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Widget _buildPremiumTitle() {
    final String? sinhalaFontFamily = AppTypography.sinhala().fontFamily;

    // Style 2: Minimal Friendly
    // "සිප්" in green, "සර" in blue, with a soft shadow.
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: sinhalaFontFamily,
          fontSize: 72,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: const Offset(0, 6),
              blurRadius: 10,
            ),
          ],
        ),
        children: [
          TextSpan(
            text: 'සිප්', // Sip
            style: const TextStyle(
              color: AppColors.gentleGreen,
            ),
          ),
          const TextSpan(
            text: 'සර', // Sara
            style: TextStyle(
              color: AppColors.calmBlue,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // Background decorations (soft bubbles)
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.calmBlue.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gentleGreen.withValues(alpha: 0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  if (!LocalizationService.instance.hasSetLanguage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildLangBtn('EN', 'en'),
                          const SizedBox(width: 8),
                          _buildLangBtn('සිංහල', 'si'),
                        ],
                      ),
                    )
                  else
                    SizedBox(height: screenHeight * 0.02),

                  // App name
                  AnimatedBuilder(
                    animation: _topController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _topSlideAnimation.value),
                        child: Opacity(
                          opacity: _topFadeAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildPremiumTitle(),
                  ),

                  // === MONSTER CHARACTERS GROUP ===
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _characterController,
                          _bounceController,
                        ]),
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              _bounceController.isAnimating
                                  ? _bounceAnimation.value
                                  : 0,
                            ),
                            child: Transform.scale(
                              scale: _characterScaleAnimation.value,
                              child: Opacity(
                                opacity: _characterFadeAnimation.value,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _buildCharacterGroup(screenWidth),
                      ),
                    ),
                  ),

                  // === BOTTOM SECTION — text + buttons ===
                  SlideTransition(
                    position: _buttonSlideAnimation,
                    child: FadeTransition(
                      opacity: _buttonFadeAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LocalizationService.instance.t('welcome_subtitle'),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // GET STARTED button
                          GradientButton(
                            text: LocalizationService.instance.t('welcome_btn_signup'),
                            icon: Icons.rocket_launch_rounded,
                            gradient: AppColors.greenGradient,
                            onPressed: () {
                              LocalizationService.instance.markLanguageAsSet();
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      const SignUpScreen(),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
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
                                  transitionDuration:
                                      const Duration(milliseconds: 400),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // I ALREADY HAVE AN ACCOUNT button
                          OutlinedGradientButton(
                            text: LocalizationService.instance.t('welcome_btn_signin'),
                            onPressed: () {
                              LocalizationService.instance.markLanguageAsSet();
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      const SignInScreen(),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(-1, 0),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      )),
                                      child: child,
                                    );
                                  },
                                  transitionDuration:
                                      const Duration(milliseconds: 400),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildCharacterGroup(double screenWidth) {
    final groupWidth = screenWidth * 0.85;

    return SizedBox(
      width: groupWidth,
      child: Image.asset(
        'assets/images/characters/mascots/furry_monsters_group_transparent.png',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildLangBtn(String label, String code) {
    final bool isSelected = LocalizationService.instance.currentLocale == code;
    return GestureDetector(
      onTap: () {
        LocalizationService.instance.setLocale(code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.calmBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.calmBlue : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
