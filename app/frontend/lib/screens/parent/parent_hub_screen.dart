import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../utils/avatar_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import 'child_progress_screen.dart';
import 'therapist_management_screen.dart';
import 'notifications_screen.dart';
import 'parent_settings_screen.dart';
import '../../services/localization_service.dart';
import '../../config/api_config.dart';

/// Parent Hub Screen — The heart of the parent experience.
/// A beautifully designed central dashboard showing children overview,
/// quick stats, and navigation to all parent features.
class ParentHubScreen extends StatefulWidget {
  const ParentHubScreen({super.key});

  @override
  State<ParentHubScreen> createState() => _ParentHubScreenState();
}

class _ParentHubScreenState extends State<ParentHubScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  String _parentName = '';
  String? _profilePictureUrl;
  List<dynamic> _students = [];

  String get _initials {
    final parts = _parentName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'P';
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await AuthService().getUserProfile();
    final students = await StudentService().getStudents();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _parentName = profile?['name'] ?? 'parent';
        _profilePictureUrl = profile?['profile_picture_url'];
        _students = students;
      });
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.cream,
          body: _isLoading
              ? const Center(child: AppLoadingIndicator())
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildQuickStats(),
                          const SizedBox(height: 28),
                          _buildNavigationGrid(),
                          const SizedBox(height: 28),
                          _buildChildrenSection(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ─── Header ───
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.calmBlue.withValues(alpha: 0.08),
            AppColors.cream,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.calmBlueDark.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          // Welcome text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.instance.t('parent_hub'),
                  style: AppTypography.caption(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.calmBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${LocalizationService.instance.t('hello_parent')}, $_parentName!',
                  style: AppTypography.heading(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Parent avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ParentSettingsScreen(),
                ),
              ).then((_) {
                _loadData();
              });
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.blueButtonGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.calmBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                image: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(
                          ApiConfig.getProfileImageUrl(_profilePictureUrl!),
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                  ? Center(
                      child: Text(
                        _initials,
                        style: AppTypography.heading(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Stats Row ───
  Widget _buildQuickStats() {
    // Mock data for now
    final int totalChildren = _students.length;
    const int weeklyActivities = 24;
    const int connectedTherapists = 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            icon: FontAwesomeIcons.userGroup,
            value: '$totalChildren',
            label: LocalizationService.instance.t('children'),
            color: AppColors.calmBlue,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: FontAwesomeIcons.gamepad,
            value: '$weeklyActivities',
            label: LocalizationService.instance.t('this_week'),
            color: AppColors.gentleGreen,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: FontAwesomeIcons.link,
            value: '$connectedTherapists',
            label: LocalizationService.instance.t('connected'),
            color: AppColors.warmAmber,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required dynamic icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: FaIcon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTypography.heading(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Navigation Grid (4 tiles) ───
  Widget _buildNavigationGrid() {
    final navItems = [
      {
        'icon': FontAwesomeIcons.chartLine,
        'label': LocalizationService.instance.t('reports'),
        'color': AppColors.calmBlue,
        'bgColor': AppColors.slateBg,
        'onTap': () {
          if (_students.isNotEmpty) {
            if (_students.length == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildProgressScreen(
                    studentData: _students.first as Map<String, dynamic>,
                  ),
                ),
              );
            } else {
              _showChildSelectionModal(context);
            }
          } else {
            _showSnackBar(LocalizationService.instance.t('add_student_first_msg'));
          }
        },
      },
      {
        'icon': FontAwesomeIcons.userDoctor,
        'label': LocalizationService.instance.t('therapists'),
        'color': AppColors.gentleGreen,
        'bgColor': AppColors.mintBg,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TherapistManagementScreen(),
            ),
          );
        },
      },
      {
        'icon': FontAwesomeIcons.bell,
        'label': LocalizationService.instance.t('messages'),
        'color': AppColors.warmAmber,
        'bgColor': const Color(0xFFFFF3E0),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationsScreen(),
            ),
          );
        },
      },
      {
        'icon': FontAwesomeIcons.gear,
        'label': LocalizationService.instance.t('settings'),
        'color': AppColors.softCoral,
        'bgColor': const Color(0xFFFDE8E4),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParentSettingsScreen(),
            ),
          ).then((_) {
            _loadData();
          });
        },
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: navItems.map((item) {
          final color = item['color'] as Color;
          final bgColor = item['bgColor'] as Color;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: item['onTap'] as VoidCallback,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      FaIcon(item['icon'] as dynamic,
                          size: 24, color: color),
                      const SizedBox(height: 10),
                      Text(
                        item['label'] as String,
                        style: AppTypography.caption(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Children Overview Section ───
  Widget _buildChildrenSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationService.instance.t('your_children'),
            style: AppTypography.heading(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.calmBlue,
            ),
          ),
          const SizedBox(height: 16),
          if (_students.isEmpty)
            _buildEmptyChildrenState()
          else
            ..._students.map((student) =>
                _buildChildCard(student as Map<String, dynamic>)),
        ],
      ),
    );
  }


  Widget _buildEmptyChildrenState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          FaIcon(FontAwesomeIcons.childReaching,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            LocalizationService.instance.t('no_students_yet'),
            style: AppTypography.heading(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LocalizationService.instance.t('add_student_settings_hint'),
            style: AppTypography.caption(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  void _showChildSelectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.instance.t('select_a_child'),
              style: AppTypography.heading(
                fontSize: 20,
                color: AppColors.calmBlue,
              ),
            ),
            const SizedBox(height: 16),
            ..._students.map((student) {
              final s = student as Map<String, dynamic>;
              final avatar = AvatarUtils.getCorrectedAvatarPath(
                s['avatar_url'] as String?,
                'assets/images/characters/human/human_student_1.png'
              );
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.5), width: 2),
                    color: AppColors.cream,
                  ),
                  child: ClipOval(
                    child: Image.asset(avatar, fit: BoxFit.cover),
                  ),
                ),
                title: Text(
                  s['first_name'] ?? 'student',
                  style: AppTypography.body(fontWeight: FontWeight.w700),
                ),
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildProgressScreen(studentData: s),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> student) {
    final name = student['first_name'] ?? 'student';
    final grade = student['grade'] ?? 'n/a';
    final avatar = AvatarUtils.getCorrectedAvatarPath(
      student['avatar_url'] as String?, 
      'assets/images/characters/mascots/solo_blue.png'
    );
    final studentId = student['id'] ?? student['_id'];

    return FutureBuilder<List<dynamic>>(
      future: StudentService().getTelemetry(studentId.toString()),
      builder: (context, snapshot) {
        int streak = 0;
        double weeklyProgress = 0.0;
        String lastActive = LocalizationService.instance.t('never');

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final sessions = snapshot.data!;
          final now = DateTime.now();
          Set<String> activeDates = {};
          int actsThisWeek = 0;

          for (final session in sessions) {
            final submittedAtStr = session['submitted_at'] as String?;
            if (submittedAtStr != null) {
              final submittedAt = DateTime.tryParse(submittedAtStr);
              if (submittedAt != null) {
                final dStr = "${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')}";
                activeDates.add(dStr);
                
                if (now.difference(submittedAt).inDays < 7) {
                  actsThisWeek += (session['events'] as List?)?.length ?? 0;
                }
              }
            }
          }
          
          if (activeDates.isNotEmpty) {
             lastActive = LocalizationService.instance.t('recent'); 
          }
          
          String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          String yesterdayStr = "${now.subtract(const Duration(days: 1)).year}-${now.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}-${now.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}";
          
          DateTime checkDate = now;
          if (activeDates.contains(todayStr) || activeDates.contains(yesterdayStr)) {
            checkDate = activeDates.contains(todayStr) ? now : now.subtract(const Duration(days: 1));
            while (true) {
              String dStr = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
              if (activeDates.contains(dStr)) {
                streak++;
                checkDate = checkDate.subtract(const Duration(days: 1));
              } else {
                break;
              }
            }
          }

          weeklyProgress = (actsThisWeek / 20.0).clamp(0.0, 1.0);
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChildProgressScreen(studentData: student),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.calmBlue.withValues(alpha: 0.1),
                      backgroundImage: AssetImage(avatar),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTypography.heading(
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            grade.toLowerCase().replaceAll(' ', '_') == 'grade_1' 
                                ? LocalizationService.instance.t('grade_1') 
                                : grade,
                            style: AppTypography.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warmAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const FaIcon(FontAwesomeIcons.fire,
                              size: 12, color: AppColors.warmAmber),
                          const SizedBox(width: 6),
                          Text(
                            '$streak ${LocalizationService.instance.t("day_streak")}',
                            style: AppTypography.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warmAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LocalizationService.instance.t('skills_mastered'),
                      style: AppTypography.caption(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(weeklyProgress * 100).round()}%',
                      style: AppTypography.caption(
                        fontWeight: FontWeight.w700,
                        color: AppColors.gentleGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: weeklyProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.gentleGreen),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.clock,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 6),
                        Text(
                          '${LocalizationService.instance.t("last_active_prefix")}$lastActive',
                          style: AppTypography.caption(
                              fontSize: 11, color: AppColors.textHint),
                        ),
                      ],
                    ),
                    Text(
                      LocalizationService.instance.t('view_progress_btn'),
                      style: AppTypography.caption(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.calmBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
