import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/monster_character.dart';
import '../services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'signin_screen.dart';
import 'character_intro_screen.dart';
import 'therapist/therapist_dashboard_screen.dart';
import 'otp_screen.dart';
import '../widgets/sliding_role_toggle.dart';
import '../services/localization_service.dart';
import '../widgets/language_selector_button.dart';

/// Sign-Up Screen
/// Dyslexia-accessible: crème background, warm white inputs, 18pt+ text,
/// calm blue accents, left-aligned, sentence case.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _selectedRole = "Parent";
  final _specializationController = TextEditingController();
  final _clinicNameController = TextEditingController();



  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    _clinicNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService().signup(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      role: _selectedRole == "Therapist" ? "specialist" : "parent",
      specialization: _selectedRole == "Therapist" ? _specializationController.text.trim() : null,
      clinicName: _selectedRole == "Therapist" ? _clinicNameController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.softCoral),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            email: _emailController.text.trim(),
            isSignup: true,
          ),
        ),
      );
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isLoading = true);

    final error = await AuthService().loginWithGoogle(
      role: _selectedRole == "Therapist" ? "specialist" : "parent",
      specialization: _selectedRole == "Therapist" ? _specializationController.text.trim() : null,
      clinicName: _selectedRole == "Therapist" ? _clinicNameController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == 'CANCELED') {
      return;
    } else if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.softCoral),
      );
    } else {
      final profile = await AuthService().getUserProfile();
      if (!mounted) return;
      final isTherapist = profile != null && profile['role'] == 'specialist';
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => isTherapist ? const TherapistDashboardScreen() : const CharacterIntroScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _onMicrosoftSignIn() async {
    setState(() => _isLoading = true);
    
    final error = await AuthService().loginWithMicrosoft(
      role: _selectedRole == "Therapist" ? "specialist" : "parent",
      specialization: _selectedRole == "Therapist" ? _specializationController.text.trim() : null,
      clinicName: _selectedRole == "Therapist" ? _clinicNameController.text.trim() : null,
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (error == 'CANCELED') {
      return;
    } else if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.softCoral),
      );
    } else {
      final profile = await AuthService().getUserProfile();
      if (!mounted) return;
      final isTherapist = profile != null && profile['role'] == 'specialist';
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => isTherapist ? const TherapistDashboardScreen() : const CharacterIntroScreen()),
        (Route<dynamic> route) => false,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Mascot Centered (same position but higher up)
                      MonsterCharacter(
                        size: 100,
                        animation: MonsterAnimation.excited,
                        imagePath: 'assets/images/characters/mascots/solo_green.png',
                      ),
                      // Back Button on the left
                      Align(
                        alignment: Alignment.topLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.calmBlueDark.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.calmBlueDark,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      // Language Selector on the right
                      const Align(
                        alignment: Alignment.topRight,
                        child: LanguageSelectorButton(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Heading
                  Text(
                    LocalizationService.instance.t('signup_title'),
                    style: AppTypography.heading(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LocalizationService.instance.t('signup_subtitle'),
                    style: AppTypography.body(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Form container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.calmBlueDark.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Sliding Premium Role Toggle
                        SlidingRoleToggle(
                          selectedRole: _selectedRole,
                          onChanged: (role) {
                            setState(() {
                              _selectedRole = role;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Name
                        TextFormField(
                          controller: _nameController,
                          style: AppTypography.body(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: LocalizationService.instance.t('parent_name_hint'),
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: AppTypography.body(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: LocalizationService.instance.t('email_hint'),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),

                        const SizedBox(height: 16),

                        
                        // Dynamic Therapist Fields
                        AnimatedCrossFade(
                          firstChild: const SizedBox(height: 0, width: double.infinity),
                          secondChild: Column(
                            children: [
                              TextFormField(
                                controller: _specializationController,
                                style: AppTypography.body(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: LocalizationService.instance.t('specialization_hint'),
                                  prefixIcon: const Icon(Icons.psychology_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _clinicNameController,
                                style: AppTypography.body(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: LocalizationService.instance.t('clinic_hint'),
                                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                          crossFadeState: _selectedRole == "Therapist" ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),


                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: AppTypography.body(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: LocalizationService.instance.t('password_hint_create'),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Sign up button
                  GradientButton(
                    text: _isLoading ? LocalizationService.instance.t('signing_up') : LocalizationService.instance.t('btn_signup'),
                    icon: Icons.person_add_rounded,
                    onPressed: _isLoading ? () {} : _onSignUp,
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.borderLight)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          LocalizationService.instance.t('or'),
                          style: AppTypography.caption(fontSize: 14),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.borderLight)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Social login
                  Row(
                    children: [
                      Expanded(
                        child: _buildSocialButton(
                          const Icon(Icons.g_mobiledata_rounded, size: 28, color: AppColors.textPrimary), 
                          'google',
                          onTap: _isLoading ? null : _onGoogleSignIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSocialButton(
                          const FaIcon(FontAwesomeIcons.microsoft, size: 24, color: AppColors.textPrimary), 
                          'microsoft',
                          onTap: _isLoading ? null : _onMicrosoftSignIn,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Sign in link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          LocalizationService.instance.t('already_have_account'),
                          style: AppTypography.body(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const SignInScreen(),
                              ),
                            );
                          },
                          child: Text(
                            LocalizationService.instance.t('btn_signin'),
                            style: AppTypography.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.calmBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
      ),
    );
      },
    );
  }

  Widget _buildSocialButton(Widget iconWidget, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlueDark.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.body(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
    );
  }
}
