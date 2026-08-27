import 'package:flutter/material.dart';
import '../widgets/app_loading_indicator.dart';
import '../utils/avatar_utils.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../services/student_service.dart';
import '../services/localization_service.dart';
import 'assessment_prompt_screen.dart';

/// Parental Consent Screen
/// Displayed before the assessment when registering a new student.
/// The parent must agree to all terms and provide a digital signature.
class ConsentScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const ConsentScreen({super.key, required this.studentData});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _signatureController = TextEditingController();
  bool _isSubmitting = false;

  bool _consentGuardian = false;
  bool _consentData = false;
  bool _consentPurpose = false;
  bool _consentTerms = false;

  bool get _allConsentsGiven =>
      _consentGuardian &&
      _consentData &&
      _consentPurpose &&
      _consentTerms &&
      _signatureController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  void _onAgreeAndContinue() async {
    if (!_allConsentsGiven || _isSubmitting) return;

    setState(() { _isSubmitting = true; });

    final studentData = Map<String, dynamic>.from(widget.studentData);
    studentData['consent_given'] = true;
    studentData['consent_parent_name'] = _signatureController.text.trim();
    studentData['consent_date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Save student to DB immediately!
    final result = await StudentService().addStudent(studentData);

    if (!mounted) return;
    setState(() { _isSubmitting = false; });

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: AppColors.softCoral),
      );
    } else {
      // Student saved! Navigate to assessment prompt
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssessmentPromptScreen(
            studentId: result['id'],
            studentName: studentData['first_name'],
            avatarUrl: AvatarUtils.getCorrectedAvatarPath(studentData['avatar_url'] as String?),
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LocalizationService.instance.t('parental_consent'),
          style: AppTypography.heading(fontSize: 22, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Card ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.calmBlue.withValues(alpha: 0.08),
                      AppColors.calmBlue.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.calmBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: AppColors.calmBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.instance.t('student_protection_agreement'),
                            style: AppTypography.heading(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            LocalizationService.instance.t('consent_review_terms'),
                            style: AppTypography.body(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- Student Info Summary ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.cream,
                      backgroundImage: AssetImage(
                        AvatarUtils.getCorrectedAvatarPath(widget.studentData['avatar_url'] as String?, 'assets/images/characters/human/human_student_1.png'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.studentData['first_name']} ${widget.studentData['last_name']}',
                          style: AppTypography.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${LocalizationService.instance.t("grade_1")} • @${widget.studentData['first_name']}',
                          style: AppTypography.caption(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // --- Consent Checkboxes ---
              Text(
                LocalizationService.instance.t('consent_items'),
                style: AppTypography.heading(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.calmBlue,
                ),
              ),
              const SizedBox(height: 16),

              _buildConsentItem(
                value: _consentGuardian,
                onChanged: (val) => setState(() => _consentGuardian = val ?? false),
                icon: Icons.family_restroom_rounded,
                title: LocalizationService.instance.t('guardian_confirmation_title'),
                description: LocalizationService.instance.t('guardian_confirmation_desc'),
              ),

              _buildConsentItem(
                value: _consentData,
                onChanged: (val) => setState(() => _consentData = val ?? false),
                icon: Icons.analytics_outlined,
                title: LocalizationService.instance.t('data_collection_title'),
                description: LocalizationService.instance.t('data_collection_desc'),
              ),

              _buildConsentItem(
                value: _consentPurpose,
                onChanged: (val) => setState(() => _consentPurpose = val ?? false),
                icon: Icons.psychology_outlined,
                title: LocalizationService.instance.t('screening_purpose_title'),
                description: LocalizationService.instance.t('screening_purpose_desc'),
              ),

              _buildConsentItem(
                value: _consentTerms,
                onChanged: (val) => setState(() => _consentTerms = val ?? false),
                icon: Icons.description_outlined,
                title: LocalizationService.instance.t('terms_privacy_title'),
                description: LocalizationService.instance.t('terms_privacy_desc'),
              ),

              const SizedBox(height: 28),

              // --- Digital Signature ---
              Text(
                LocalizationService.instance.t('digital_signature'),
                style: AppTypography.heading(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.calmBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LocalizationService.instance.t('digital_signature_desc'),
                style: AppTypography.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.calmBlueDark.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _signatureController,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.body(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: LocalizationService.instance.t('signature_hint'),
                        prefixIcon: const Icon(Icons.draw_rounded),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                    Divider(color: AppColors.borderLight),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          '${LocalizationService.instance.t("date_prefix")}${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                          style: AppTypography.caption(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- Agree Button ---
              _isSubmitting
                  ? const Center(child: AppLoadingIndicator())
                  : GradientButton(
                      text: LocalizationService.instance.t('agree_continue'),
                      icon: Icons.check_circle_rounded,
                      gradient: _allConsentsGiven
                          ? AppColors.greenGradient
                          : LinearGradient(
                              colors: [Colors.grey.shade400, Colors.grey.shade500],
                            ),
                      onPressed: _allConsentsGiven ? _onAgreeAndContinue : () {},
                    ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  LocalizationService.instance.t('withdraw_consent_info'),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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

  Widget _buildConsentItem({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? AppColors.gentleGreen.withValues(alpha: 0.06)
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? AppColors.gentleGreen.withValues(alpha: 0.4)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.gentleGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: value ? AppColors.gentleGreen : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTypography.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
