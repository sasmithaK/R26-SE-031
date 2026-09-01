import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'therapist/therapist_dashboard_screen.dart';
import 'select_student_screen.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation for the text logo at the bottom
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Start text animation
    _animationController.forward();

    // Navigate based on auth status after minimal splash duration
    Future.delayed(const Duration(milliseconds: 3000), () async {
      try {
        if (!mounted) return;
        final token = await AuthService().getAccessToken();
        if (!mounted) return;

        if (token != null) {
          // Use cached role first so we don't wait 30s for Render server cold boot
          final cachedRole = await AuthService().getCachedRole();
          final isTherapist = cachedRole == 'therapist' || cachedRole == 'specialist';
          
          // We can let getUserProfile run in the background if we want, but no need to await it here
          void fetchProfile() async {
            try {
              await AuthService().getUserProfile();
            } catch (_) {}
          }
          fetchProfile();

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  isTherapist ? const TherapistDashboardScreen() : const SelectStudentScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const WelcomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      } catch (e) {
        debugPrint('Splash Screen Error: $e');
        // Fallback navigation if something completely fails
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/branding/splash_bg.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
