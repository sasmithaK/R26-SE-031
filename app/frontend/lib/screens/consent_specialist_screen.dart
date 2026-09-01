import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class ConsentSpecialistScreen extends StatefulWidget {
  final String clinicCode;
  final String studentId;

  const ConsentSpecialistScreen({super.key, required this.clinicCode, required this.studentId});

  @override
  State<ConsentSpecialistScreen> createState() => _ConsentSpecialistScreenState();
}

class _ConsentSpecialistScreenState extends State<ConsentSpecialistScreen> {
  bool _agreed = false;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.instance.t('please_tap_checkbox'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService().connectSpecialist(widget.clinicCode, widget.studentId);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.softCoral),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.instance.t('successfully_connected')), backgroundColor: AppColors.calmBlue),
      );
      // Pop ConsentSpecialistScreen AND ConnectSpecialistScreen
      int count = 0;
      Navigator.popUntil(context, (route) => count++ == 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LocalizationService.instance.t('privacy_consent'),
          style: AppTypography.heading(fontSize: 22, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(LocalizationService.instance.t('what_you_are_sharing'), style: AppTypography.heading(fontSize: 18, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  _buildBulletPoint(LocalizationService.instance.t('consent_bullet_1')),
                  _buildBulletPoint(LocalizationService.instance.t('consent_bullet_2')),
                  _buildBulletPoint(LocalizationService.instance.t('consent_bullet_3')),
                  const SizedBox(height: 24),
                  Text(LocalizationService.instance.t('why_we_share_this'), style: AppTypography.heading(fontSize: 18, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Text(
                    LocalizationService.instance.t('why_we_share_desc'),
                    style: AppTypography.body(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  activeColor: AppColors.calmBlue,
                  onChanged: (val) => setState(() => _agreed = val ?? false),
                ),
                Expanded(
                  child: Text(
                    LocalizationService.instance.t('consent_agree_text').replaceAll('{clinicCode}', widget.clinicCode),
                    style: AppTypography.body(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: _isLoading ? LocalizationService.instance.t('connecting') : LocalizationService.instance.t('agree_connect'),
              icon: Icons.check_circle_outline,
              onPressed: _isLoading ? () {} : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle, size: 8, color: AppColors.calmBlue),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTypography.body(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
