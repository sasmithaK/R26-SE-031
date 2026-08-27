import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'comprehensive_assessment_selection_screen.dart';
import 'parent_account_screen.dart';
import '../services/localization_service.dart';

/// Friendly prompt screen shown after a student is successfully saved.
/// Gently encourages the parent to take the assessment without forcing it.
class AssessmentPromptScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? avatarUrl;

  const AssessmentPromptScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
  });

  @override
  State<AssessmentPromptScreen> createState() => _AssessmentPromptScreenState();
}

class _AssessmentPromptScreenState extends State<AssessmentPromptScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAssessment() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ComprehensiveAssessmentSelectionScreen(
          studentId: widget.studentId,
          studentName: widget.studentName,
          avatarUrl: widget.avatarUrl,
        ),
      ),
    );
  }

  void _skipForNow() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.cream,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Success checkmark
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: AppColors.greenGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gentleGreen.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Congrats title
                  Text(
                    LocalizationService.instance.t('student_added'),
                    style: AppTypography.heading(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${widget.studentName}${LocalizationService.instance.t('student_setup_ready_1')}',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Assessment suggestion card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.calmBlue.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.calmBlueDark.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Icon header
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.calmBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            color: AppColors.calmBlue,
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          LocalizationService.instance.t('personalize_learning'),
                          style: AppTypography.heading(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          '${LocalizationService.instance.t('evaluation_desc_1')}${widget.studentName}${LocalizationService.instance.t('evaluation_desc_2')}',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Benefits row
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildBenefitChip(Icons.auto_awesome_rounded, LocalizationService.instance.t('personalized')),
                            _buildBenefitChip(Icons.timer_rounded, LocalizationService.instance.t('2_min')),
                            _buildBenefitChip(Icons.lock_rounded, LocalizationService.instance.t('private')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // CTA Buttons
                  GradientButton(
                    text: LocalizationService.instance.t('start_assessment'),
                    icon: Icons.play_arrow_rounded,
                    gradient: AppColors.blueButtonGradient,
                    onPressed: _startAssessment,
                  ),

                  const SizedBox(height: 14),

                  // Skip button — better UX design (long button)
                  ElevatedButton(
                    onPressed: _skipForNow,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textSecondary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: AppColors.textHint.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Text(
                      LocalizationService.instance.t('maybe_later'),
                      style: AppTypography.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    LocalizationService.instance.t('assessment_later_desc'),
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);
  }

  Widget _buildBenefitChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mintBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gentleGreenDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.gentleGreenDark,
            ),
          ),
        ],
      ),
    );
  }
}
