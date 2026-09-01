import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_loading_indicator.dart';
import '../utils/avatar_utils.dart';
import '../services/localization_service.dart';
import 'comprehensive_assessment_screen.dart';
import '../services/student_service.dart';

class ComprehensiveAssessmentSelectionScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? avatarUrl;

  const ComprehensiveAssessmentSelectionScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
  });

  @override
  State<ComprehensiveAssessmentSelectionScreen> createState() =>
      _ComprehensiveAssessmentSelectionScreenState();
}

class _ComprehensiveAssessmentSelectionScreenState
    extends State<ComprehensiveAssessmentSelectionScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _completedCategories = {};
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    setState(() {
      _isLoading = true;
    });

    final students = await StudentService().getStudents();

    if (mounted) {
      final student = students.firstWhere(
        (s) => s['id'] == widget.studentId || s['_id'] == widget.studentId,
        orElse: () => null,
      );
      if (student != null) {
        final compResults =
            (student['comprehensive_assessment_results'] as Map?)
                ?.cast<String, dynamic>() ??
            {};
        setState(() {
          _completedCategories = compResults;
          _avatarUrl = student['avatar_url'] as String?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Map Background
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/backgrounds/map_bg.png'),
                    fit: BoxFit.cover,
                    opacity: 0.9,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: AppColors.cream.withValues(alpha: 0.7),
                  ),
                ),
              ),

              _isLoading
                  ? const Center(child: AppLoadingIndicator())
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 220.0,
                          floating: false,
                          pinned: true,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          systemOverlayStyle: SystemUiOverlayStyle.dark,
                          leading: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                          flexibleSpace: FlexibleSpaceBar(
                            background: Container(
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.calmBlue.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: AppColors.calmBlue
                                                .withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.calmBlue
                                                  .withValues(alpha: 0.4),
                                              width: 2,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              AvatarUtils.getCorrectedAvatarPath(
                                                widget.avatarUrl ?? _avatarUrl,
                                                'assets/images/characters/human/human_student_1.png',
                                              ),
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.child_care_rounded,
                                                      size: 30,
                                                      color: AppColors.calmBlue,
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          widget.studentName,
                                          style: AppTypography.heading(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    LocalizationService.instance.t(
                                      'assessment_profile',
                                    ),
                                    style: AppTypography.heading(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    LocalizationService.instance.t(
                                      'select_area_evaluate',
                                    ),
                                    style: AppTypography.body(
                                      fontSize: 15,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildPremiumCategoryCard(
                                context: context,
                                category: 'basic',
                                title: LocalizationService.instance.t(
                                  'cat_basic',
                                ),
                                subtitle: '',
                                icon: Icons.psychology_rounded,
                                gradient: AppColors.blueButtonGradient,
                                isCompleted: _completedCategories.containsKey(
                                  'basic',
                                ),
                              ),
                              _buildPremiumCategoryCard(
                                context: context,
                                category: 'reading',
                                title: LocalizationService.instance.t(
                                  'cat_reading',
                                ),
                                subtitle: '',
                                icon: Icons.menu_book_rounded,
                                gradient: AppColors.greenGradient,
                                isCompleted: _completedCategories.containsKey(
                                  'reading',
                                ),
                              ),
                              _buildPremiumCategoryCard(
                                context: context,
                                category: 'writing',
                                title: LocalizationService.instance.t(
                                  'cat_writing',
                                ),
                                subtitle: '',
                                icon: Icons.edit_rounded,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFD97706),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                isCompleted: _completedCategories.containsKey(
                                  'writing',
                                ),
                              ),
                              _buildPremiumCategoryCard(
                                context: context,
                                category: 'other',
                                title: LocalizationService.instance.t(
                                  'cat_other',
                                ),
                                subtitle: '',
                                icon: Icons.more_horiz_rounded,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF6D28D9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                isCompleted: _completedCategories.containsKey(
                                  'other',
                                ),
                              ),
                              const SizedBox(height: 40),
                            ]),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumCategoryCard({
    required BuildContext context,
    required String category,
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required bool isCompleted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          highlightColor: Colors.black.withValues(alpha: 0.02),
          splashColor: Colors.black.withValues(alpha: 0.04),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ComprehensiveAssessmentScreen(
                  studentId: widget.studentId,
                  category: category,
                ),
              ),
            ).then((_) => _fetchStudentData());
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 20),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTypography.caption(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Show completed badge or chevron
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gentleGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.gentleGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Done',
                          style: AppTypography.caption(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gentleGreen,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.textSecondary,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
