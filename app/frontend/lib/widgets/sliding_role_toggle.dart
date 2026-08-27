import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';

class SlidingRoleToggle extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onChanged;

  const SlidingRoleToggle({
    super.key,
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTherapist = selectedRole == "Therapist";
          // Calculate the width for the sliding thumb (half the total width minus margins)
          final width = (constraints.maxWidth - 8) / 2;
          
          return Stack(
            children: [
              // The sliding thumb
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                left: isTherapist ? 4 + width : 4,
                top: 4,
                bottom: 4,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.calmBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.calmBlueDark.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
              // The clickable items
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged("Parent"),
                      child: _buildItem(LocalizationService.instance.t('role_parent'), Icons.family_restroom_rounded, !isTherapist),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged("Therapist"),
                      child: _buildItem(LocalizationService.instance.t('role_therapist'), Icons.psychology_rounded, isTherapist),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem(String label, IconData icon, bool isSelected) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeIn,
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeIn,
            style: AppTypography.body(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
