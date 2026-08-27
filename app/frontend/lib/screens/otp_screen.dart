import 'package:flutter/material.dart';
import '../widgets/app_loading_indicator.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../services/auth_service.dart';
import 'reset_password_screen.dart';
import 'select_student_screen.dart';
import 'onboarding_screen.dart';
import 'therapist/therapist_dashboard_screen.dart';
import '../services/localization_service.dart';


class OtpScreen extends StatefulWidget {
  final String email;
  final bool isSignup;
  
  const OtpScreen({super.key, required this.email, this.isSignup = false});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Request focus automatically
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();

    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }



  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    
    final error = await AuthService().resendOtp(widget.email);
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.softCoral),
      );
    } else {
      setState(() {
        _otpController.clear();
        _secondsRemaining = 60;
        _startTimer();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new OTP has been sent to your email.'), backgroundColor: AppColors.gentleGreen),
      );
    }
  }

  Future<void> _verifyOtp() async {

    if (_secondsRemaining == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP expired. Please tap Resend to get a new code.'), backgroundColor: AppColors.softCoral),
      );
      return;
    }

    String otp = _otpController.text;

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits.'), backgroundColor: AppColors.softCoral),
      );
      return;
    }

    if (widget.isSignup) {
      setState(() => _isLoading = true);
      final error = await AuthService().verifyEmail(widget.email, otp);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.softCoral),
        );
      } else {
        if (widget.isSignup) {
          final profile = await AuthService().getUserProfile();
          if (!mounted) return;
          final isTherapist = profile != null && profile['role'] == 'specialist';
          
          if (isTherapist) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TherapistDashboardScreen()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
              (route) => false,
            );
          }
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SelectStudentScreen()),
            (route) => false,
          );
        }
      }
    } else {
      // Forgot Password flow: pass OTP to ResetPasswordScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(email: widget.email, otp: otp),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (widget.isSignup) {
          AuthService().cancelSignup(widget.email);
        }
      },
      child: ListenableBuilder(
        listenable: LocalizationService.instance,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: AppColors.cream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Premium Icon Container
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.calmBlue.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mark_email_unread_rounded,
                        size: 40,
                        color: AppColors.calmBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    LocalizationService.instance.t('check_email'),
                    textAlign: TextAlign.center,
                    style: AppTypography.heading(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTypography.body(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: LocalizationService.instance.t('otp_sent_to')),
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        TextSpan(text: LocalizationService.instance.t('otp_enter_below')),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Form Container for OTP Boxes
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
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).requestFocus(_focusNode);
                    },
                    child: Stack(
                      children: [
                        // Hidden TextField
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller: _otpController,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (value) {
                              setState(() {}); 
                              if (value.length == 6) {
                                _focusNode.unfocus();
                                _verifyOtp();
                              }
                            },
                          ),
                        ),
                        
                        // Visual Boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            String currentDigit = '';
                            if (index < _otpController.text.length) {
                              currentDigit = _otpController.text[index];
                            }
                            
                            bool isFocused = index == _otpController.text.length || 
                                           (index == 5 && _otpController.text.length == 6);
                            
                            return Container(
                              width: 40,
                              height: 50,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFocused ? AppColors.calmBlue : AppColors.borderLight,
                                  width: 2,
                                ),
                                boxShadow: isFocused ? [
                                  BoxShadow(
                                    color: AppColors.calmBlue.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ] : [],
                              ),
                              child: Text(
                                currentDigit,
                                style: AppTypography.heading(
                                  fontSize: 22, 
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),

                // Resend Timer/Button
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_secondsRemaining == 0 && !_isLoading) {
                        _resendOtp();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _secondsRemaining > 0 ? AppColors.cream : AppColors.calmBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _secondsRemaining > 0 ? AppColors.borderLight : AppColors.calmBlue,
                          width: _secondsRemaining > 0 ? 1 : 2,
                        ),
                      ),
                      child: Text(
                        _secondsRemaining > 0
                            ? LocalizationService.instance.t('resend_code_in').replaceAll('{time}', '0:${_secondsRemaining.toString().padLeft(2, '0')}')
                            : LocalizationService.instance.t('resend_otp_now'),
                        style: AppTypography.body(
                          fontSize: 15,
                          color: _secondsRemaining > 0 ? AppColors.textSecondary : AppColors.calmBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(child: AppLoadingIndicator())
                      : GradientButton(
                          text: LocalizationService.instance.t('verify_code'),
                          onPressed: _verifyOtp,
                          icon: Icons.check_circle_outline,
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
  }
}
