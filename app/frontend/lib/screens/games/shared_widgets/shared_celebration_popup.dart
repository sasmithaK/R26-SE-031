import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../utils/avatar_utils.dart';

class SharedCelebrationPopup extends StatelessWidget {
  final Map<String, dynamic>? studentData;
  final String activityTitle;
  final Animation<double> scaleAnimation;
  final VoidCallback onFinish;

  const SharedCelebrationPopup({
    Key? key,
    required this.studentData,
    required this.activityTitle,
    required this.scaleAnimation,
    required this.onFinish,
  }) : super(key: key);

  Widget _buildGlowingStar(double size, {bool delay = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: delay ? const Interval(0.2, 1.0, curve: Curves.elasticOut) : Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: const Color(0xFFFFD700),
            shadows: [
              Shadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                blurRadius: 15 * value,
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the student's avatar
    final avatarUrl = AvatarUtils.getCorrectedAvatarPath(
      studentData?['avatar_url'] as String?,
      'assets/images/characters/human/human_student_1.png',
    );

    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.4 * scaleAnimation.value),
          child: Center(
            child: Transform.scale(
              scale: scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90D9).withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3 Stars row with glow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildGlowingStar(42, delay: true),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildGlowingStar(56),
                ),
                const SizedBox(width: 8),
                _buildGlowingStar(42, delay: true),
              ],
            ),
            const SizedBox(height: 24),
            
            // Student Avatar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9E8D3).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                avatarUrl,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.person, size: 80, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title Text
            Text(
              'හොඳයි!',
              style: AppTypography.sinhala(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Activity Title Highlight
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4A90D9).withValues(alpha: 0.3), width: 1.5),
              ),
              child: Text(
                activityTitle,
                style: AppTypography.sinhala(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A90D9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            
            // Subtitle Text
            Text(
              'ඔබ සියල්ල සාර්ථකව නිම කළා!',
              style: AppTypography.sinhala(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Redesigned Button
            GestureDetector(
              onTap: onFinish,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC074), Color(0xFF4A9E50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6EC074).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'ඉදිරියට යමු',
                          style: AppTypography.sinhala(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
