import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';

class LanguageSelectorButton extends StatelessWidget {
  final bool isDarkTheme;
  const LanguageSelectorButton({super.key, this.isDarkTheme = false});

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                LocalizationService.instance.t('select_language'),
                style: AppTypography.heading(fontSize: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              _buildLanguageOptionSheet(
                ctx,
                title: 'English',
                localeCode: 'en',
                icon: Icons.language_rounded,
              ),
              const SizedBox(height: 12),
              _buildLanguageOptionSheet(
                ctx,
                title: 'සිංහල',
                localeCode: 'si',
                icon: Icons.translate_rounded,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOptionSheet(BuildContext ctx, {required String title, required String localeCode, required IconData icon}) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        final bool isSelected = LocalizationService.instance.currentLocale == localeCode;
        return GestureDetector(
          onTap: () {
            LocalizationService.instance.setLocale(localeCode);
            Navigator.pop(ctx);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.calmBlue.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.calmBlue : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? AppColors.calmBlue : AppColors.textSecondary, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.body(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? AppColors.calmBlue : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.calmBlue, size: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        final currentLang = LocalizationService.instance.currentLocale == 'en' ? 'EN' : 'සිං';
        return GestureDetector(
          onTap: () => _showLanguageBottomSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.black.withValues(alpha: 0.15) : AppColors.calmBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkTheme ? Colors.white.withValues(alpha: 0.2) : AppColors.calmBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 16,
                  color: isDarkTheme ? Colors.white : AppColors.calmBlueDark,
                ),
                const SizedBox(width: 6),
                Text(
                  currentLang,
                  style: AppTypography.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkTheme ? Colors.white : AppColors.calmBlueDark,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDarkTheme ? Colors.white : AppColors.calmBlueDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
