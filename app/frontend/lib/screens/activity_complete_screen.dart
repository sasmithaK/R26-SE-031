import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/curriculum_models.dart';
import '../utils/avatar_utils.dart';
import 'telemetry_debug_screen.dart';

class ActivityCompleteScreen extends StatefulWidget {
  final ActivityNode activityNode;
  final String skillId;
  final int score;
  final bool isRevisiting;
  final VoidCallback? onRetake;
  final VoidCallback? onContinue;

  const ActivityCompleteScreen({
    super.key,
    required this.activityNode,
    required this.skillId,
    required this.score,
    this.isRevisiting = false,
    this.onRetake,
    this.onContinue,
  });

  @override
  State<ActivityCompleteScreen> createState() => _ActivityCompleteScreenState();
}

class _ActivityCompleteScreenState extends State<ActivityCompleteScreen> {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString('current_student_id');
      final cachedStr = prefs.getString('cached_students_list');
      if (studentId != null && cachedStr != null && cachedStr.isNotEmpty) {
        final List<dynamic> cachedStudents = jsonDecode(cachedStr);
        final student = cachedStudents.firstWhere(
          (s) => s['id'] == studentId,
          orElse: () => null,
        );
        if (student != null && mounted) {
          setState(() {
            _avatarUrl = student['avatar_url'] as String?;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  @override
  Widget build(BuildContext context) {
    const stars = 5;
    const titleText = 'සුබ පැතුම්!';
    const subtitleText = 'ඔබ ක්‍රියාකාරකම සාර්ථකව අවසන් කළා!';
    const displayScore = 100;
    
    final avatarPath = AvatarUtils.getCorrectedAvatarPath(
      _avatarUrl,
      'assets/images/characters/mascots/solo_blue.png',
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TelemetryDebugScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        mini: true,
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Celebration Hero Avatar Badge
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.warmAmber.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Image.asset(
                    avatarPath,
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ],
              ),

              // Activity Name Badge
              if (widget.activityNode.title.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.calmBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Text(
                    widget.activityNode.title,
                    style: AppTypography.heading(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.calmBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Title Banner
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: AppTypography.heading(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // Score Card (Score % + 5 Stars)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.warmAmber, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmAmber.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '$displayScore%',
                      style: AppTypography.heading(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warmAmber,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(
                            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i < stars ? AppColors.warmAmber : AppColors.borderLight,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons Row: Retake (Play Again) & Continue
              Row(
                children: [
                  // Retake / Play Again Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (widget.onRetake != null) {
                          widget.onRetake!();
                        } else {
                          Navigator.pop(context, 'retake');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.softCoral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 22),
                      label: Text(
                        'නැවත ක්‍රීඩා කරමු',
                        style: AppTypography.button(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Continue / Next Level Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (widget.onContinue != null) {
                          widget.onContinue!();
                        } else {
                          Navigator.pop(context, 'continue');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gentleGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                      label: Text(
                        widget.isRevisiting ? 'සිතියමට යමු' : 'ඉදිරියට යමු',
                        style: AppTypography.button(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
