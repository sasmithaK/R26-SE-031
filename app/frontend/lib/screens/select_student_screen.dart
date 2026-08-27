import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/app_loading_indicator.dart';
import '../utils/avatar_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/monster_character.dart';
import '../widgets/gradient_button.dart';
import '../services/student_service.dart';
import '../services/progress_service.dart';
import 'dashboard_screen.dart';
import 'add_student_screen.dart';
import 'parent/parent_hub_screen.dart';
import 'assessment_prompt_screen.dart';
import '../services/localization_service.dart';

/// Select Student Screen
/// Dyslexia-accessible: calm blue header, warm white student cards,
/// crème bg, dark grey text, sentence case.
class SelectStudentScreen extends StatefulWidget {
  const SelectStudentScreen({super.key});

  @override
  State<SelectStudentScreen> createState() => _SelectStudentScreenState();
}

class _SelectStudentScreenState extends State<SelectStudentScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  List<dynamic> _students = [];
  int? _selectedIndex;

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

    _loadStudents();
  }

  Future<void> _loadStudents() async {
    // 1. Instantly load from cache to eliminate the loading spinner
    final cachedStudents = await StudentService().getCachedStudents();
    if (mounted && cachedStudents.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _students = cachedStudents;
      });
    }

    // 2. Fetch fresh data in the background (will update cache automatically)
    final freshStudents = await StudentService().getStudents();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _students = freshStudents;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
        children: [
          // Background
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

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  const SizedBox(height: 8),

                  // "who's learning today?" title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocalizationService.instance.t('whos_learning_today'),
                        style: AppTypography.heading(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Student cards grid
                  Expanded(
                    child: _isLoading
                        ? const Center(child: AppLoadingIndicator())
                        : _students.isEmpty
                            ? _buildEmptyState()
                            : _buildStudentGrid(screenWidth),
                  ),

                  // Bottom actions
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Removed back button to prevent returning to login
          const Spacer(),
          // Settings / Parent account
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ParentHubScreen()),
              );
              _loadStudents();
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.gentleGreen.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gentleGreen.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.userGroup,
                  color: AppColors.gentleGreen,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MonsterCharacter(
            size: 150,
            animation: MonsterAnimation.curious,
            imagePath: 'assets/images/characters/mascots/solo_green.png',
          ),
          const SizedBox(height: 20),
          Text(
            LocalizationService.instance.t('no_students_yet'),
            style: AppTypography.heading(
              fontSize: 22,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LocalizationService.instance.t('add_student_subtitle'),
            style: AppTypography.body(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGrid(double screenWidth) {
    final crossAxisCount = screenWidth > 500 ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index] as Map<String, dynamic>;
        final isSelected = _selectedIndex == index;
        final avatarUrl = AvatarUtils.getCorrectedAvatarPath(student['avatar_url'] as String?, 'assets/images/characters/human/human_student_1.png');
        
        final Map<String, dynamic> compResults = (student['comprehensive_assessment_results'] as Map?)?.cast<String, dynamic>() ?? {};
        final bool needsScreening = compResults.length < 4;

        return GestureDetector(
          onTap: () async {
            setState(() => _selectedIndex = index);
            
            // Sync progress globally for the selected student
            if (student['id'] != null) {
              await ProgressService().setCurrentStudentId(student['id']);
              await ProgressService().loadFromCloud(student);
            }
            
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardScreen(studentData: student),
                  ),
                );
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.calmBlue.withValues(alpha: 0.1) : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? AppColors.calmBlue : AppColors.borderLight,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.calmBlue.withValues(alpha: 0.15)
                      : AppColors.shadow,
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.calmBlue : AppColors.borderLight,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to default avatar if the asset is not found
                        return Image.asset(
                          'assets/images/characters/human/human_student_1.png',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  student['first_name'] ?? 'student',
                  style: AppTypography.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Button
                if (needsScreening)
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AssessmentPromptScreen(
                            studentId: student['id'],
                            studentName: student['first_name'] ?? 'student',
                            avatarUrl: avatarUrl,
                          ),
                        ),
                      );
                      _loadStudents(); // Reload data after returning
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.assignment_late_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            LocalizationService.instance.t('pending'),
                            style: AppTypography.caption(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.greenGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gentleGreen.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          LocalizationService.instance.t('ready'),
                          style: AppTypography.caption(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GradientButton(
        text: LocalizationService.instance.t('add_student'),
        icon: Icons.person_add_rounded,
        gradient: AppColors.greenGradient,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStudentScreen()),
          );
          _loadStudents();
        },
      ),
    );
  }
}
