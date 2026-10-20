import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../utils/avatar_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../services/parent_dashboard_service.dart';
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
  int? _sessionsThisWeek;
  int? _connectedTherapists;
  final Map<String, Future<Map<String, dynamic>>> _childInsightFutures = {};

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
        _childInsightFutures.clear();
      });
      _fadeController.forward();
    }
    _loadQuickStats(students);
  }

  /// Real counts for the quick-stats row (previously hard-coded 24 and 1).
  Future<void> _loadQuickStats(List<dynamic> students) async {
    int? sessions = 0;
    for (final student in students) {
      final id = (student is Map ? (student['id'] ?? student['_id'] ?? student['student_id']) : null)?.toString();
      if (id == null) continue;
      try {
        final history = await ParentDashboardService().getActivityHistory(id, 'days=7&limit=50');
        sessions = (sessions ?? 0) + ((history['history'] as List<dynamic>?)?.length ?? 0);
      } catch (_) {
        sessions = null;
        break;
      }
    }
    int? therapists;
    try {
      final connections = await AuthService().getConnections();
      therapists = connections.length;
    } catch (_) {
      therapists = null;
    }
    if (!mounted) return;
    setState(() {
      _sessionsThisWeek = sessions;
      _connectedTherapists = therapists;
    });
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
          colors: [AppColors.calmBlue.withValues(alpha: 0.08), AppColors.cream],
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
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
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
                  style: DashText.caption(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.calmBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${LocalizationService.instance.t('hello_parent')}, $_parentName!',
                  style: DashText.heading(
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
                MaterialPageRoute(builder: (_) => const ParentSettingsScreen()),
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
                image:
                    _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
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
                        style: DashText.heading(
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
    final int totalChildren = _students.length;
    final String weeklyActivities = _sessionsThisWeek?.toString() ?? '—';
    final String connectedTherapists = _connectedTherapists?.toString() ?? '—';

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
            value: weeklyActivities,
            label: LocalizationService.instance.t('this_week'),
            color: AppColors.gentleGreen,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: FontAwesomeIcons.link,
            value: connectedTherapists,
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
              child: Center(child: FaIcon(icon, size: 18, color: color)),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: DashText.heading(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: DashText.caption(
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
            _showSnackBar(
              LocalizationService.instance.t('add_student_first_msg'),
            );
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
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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
            MaterialPageRoute(builder: (_) => const ParentSettingsScreen()),
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
                      color: color.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
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
                      FaIcon(item['icon'] as dynamic, size: 24, color: color),
                      const SizedBox(height: 10),
                      Text(
                        item['label'] as String,
                        style: DashText.caption(
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
            style: DashText.heading(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.calmBlue,
            ),
          ),
          const SizedBox(height: 16),
          if (_students.isEmpty)
            _buildEmptyChildrenState()
          else
            ..._students.map(
              (student) => _buildChildCard(student as Map<String, dynamic>),
            ),
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
          FaIcon(
            FontAwesomeIcons.childReaching,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            LocalizationService.instance.t('no_students_yet'),
            style: DashText.heading(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LocalizationService.instance.t('add_student_settings_hint'),
            style: DashText.caption(
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
              style: DashText.heading(
                fontSize: 20,
                color: AppColors.calmBlue,
              ),
            ),
            const SizedBox(height: 16),
            ..._students.map((student) {
              final s = student as Map<String, dynamic>;
              final avatar = AvatarUtils.getCorrectedAvatarPath(
                s['avatar_url'] as String?,
                'assets/images/characters/human/human_student_1.png',
              );
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.calmBlue.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    color: AppColors.cream,
                  ),
                  child: ClipOval(
                    child: Image.asset(avatar, fit: BoxFit.cover),
                  ),
                ),
                title: Text(
                  s['first_name'] ?? 'student',
                  style: DashText.body(fontWeight: FontWeight.w700),
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
    final name = (student['first_name'] ?? 'Student').toString();
    final grade = (student['grade'] ?? 'Grade 1').toString();
    final avatar = AvatarUtils.getCorrectedAvatarPath(
      student['avatar_url'] as String?,
      'assets/images/characters/mascots/solo_blue.png',
    );
    final studentId = (student['id'] ?? student['_id']).toString();
    final insightFuture = _childInsightFutures.putIfAbsent(
      studentId,
      () => ParentDashboardService().getAdaptiveInsights(studentId),
    );

    return FutureBuilder<Map<String, dynamic>>(
      future: insightFuture,
      builder: (context, snapshot) {
        final support = snapshot.data?['support_summary'];
        final summary = support is Map
            ? Map<String, dynamic>.from(support)
            : <String, dynamic>{};
        final coverageValue = summary['coverage'];
        final coverage = coverageValue is Map
            ? Map<String, dynamic>.from(coverageValue)
            : <String, dynamic>{};
        final completed = _cardInt(summary['completed_tasks']);
        final independent = _cardInt(summary['independent_successes']);
        final helped = _cardInt(summary['supported_successes']);
        final checked = _cardInt(summary['confirmation_checks']);
        final activitiesTried = _cardInt(coverage['activities_tried']);
        final needsPractice = _cardMaps(summary['needs_practice']);
        final goingWell = _cardMaps(summary['going_well']);
        final hasLearningData = snapshot.hasData && completed > 0;

        final Color statusColor;
        final dynamic statusIcon;
        final String statusText;
        if (snapshot.connectionState == ConnectionState.waiting) {
          statusColor = AppColors.calmBlue;
          statusIcon = FontAwesomeIcons.arrowsRotate;
          statusText = 'Loading learning';
        } else if (snapshot.hasError) {
          statusColor = AppColors.softCoral;
          statusIcon = FontAwesomeIcons.circleExclamation;
          statusText = 'Summary unavailable';
        } else if (!hasLearningData) {
          statusColor = AppColors.calmBlue;
          statusIcon = FontAwesomeIcons.seedling;
          statusText = 'Ready to begin';
        } else if (needsPractice.isNotEmpty) {
          statusColor = AppColors.warmAmber;
          statusIcon = FontAwesomeIcons.lightbulb;
          statusText = 'Practice suggested';
        } else {
          statusColor = AppColors.gentleGreen;
          statusIcon = FontAwesomeIcons.circleCheck;
          statusText = 'Learning on track';
        }

        Future<void> openProgress() async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChildProgressScreen(studentData: student),
            ),
          );
          if (!mounted) return;
          setState(() {
            _childInsightFutures[studentId] = ParentDashboardService()
                .getAdaptiveInsights(studentId);
          });
        }

        return GestureDetector(
          onTap: openProgress,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderBlue, width: 1.25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.slateBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderBlue,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(avatar, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DashText.heading(
                              fontSize: 19,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            grade.toLowerCase().replaceAll(' ', '_') ==
                                    'grade_1'
                                ? LocalizationService.instance.t('grade_1')
                                : grade,
                            style: DashText.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                statusText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: DashText.caption(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  _buildChildCardMessage(
                    icon: FontAwesomeIcons.arrowsRotate,
                    title: 'Loading learning summary',
                    message: 'Gathering the latest completed learning tasks.',
                    color: AppColors.calmBlue,
                  )
                else if (snapshot.hasError)
                  _buildChildCardMessage(
                    icon: FontAwesomeIcons.wifi,
                    title: 'Could not load this summary',
                    message: 'Open the learning summary to try again.',
                    color: AppColors.softCoral,
                  )
                else if (!hasLearningData)
                  _buildChildCardMessage(
                    icon: FontAwesomeIcons.seedling,
                    title: 'No completed learning tasks yet',
                    message:
                        'Useful learning details will appear after the first activity.',
                    color: AppColors.calmBlue,
                  )
                else ...[
                  Text(
                    '$completed completed learning tasks'
                    '${activitiesTried > 0 ? ' across $activitiesTried activities' : ''}.',
                    style: DashText.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChildMetric(
                          icon: FontAwesomeIcons.heart,
                          value: independent,
                          label: 'Correct first try',
                          color: AppColors.gentleGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChildMetric(
                          icon: FontAwesomeIcons.handHoldingHeart,
                          value: helped,
                          label: 'Needed help',
                          color: AppColors.warmAmber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChildMetric(
                          icon: FontAwesomeIcons.clipboardCheck,
                          value: checked,
                          label: 'Checked again',
                          color: AppColors.calmBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (needsPractice.isNotEmpty)
                    _buildChildInsight(
                      icon: FontAwesomeIcons.lightbulb,
                      eyebrow: 'NEXT PRACTICE',
                      title:
                          (needsPractice.first['title'] ??
                                  needsPractice.first['activity_name'] ??
                                  'Short practice')
                              .toString(),
                      detail:
                          (needsPractice.first['evidence_text'] ??
                                  'A short follow-up practice is available.')
                              .toString(),
                      color: AppColors.warmAmber,
                    )
                  else if (goingWell.isNotEmpty)
                    _buildChildInsight(
                      icon: FontAwesomeIcons.star,
                      eyebrow: 'GOING WELL',
                      title:
                          (goingWell.first['title'] ??
                                  goingWell.first['activity_name'] ??
                                  'Learning progress')
                              .toString(),
                      detail:
                          (goingWell.first['evidence_text'] ??
                                  'This area is progressing independently.')
                              .toString(),
                      color: AppColors.gentleGreen,
                    ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.calmBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.calmBlue.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.chartSimple,
                        size: 15,
                        color: AppColors.calmBlue,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'View learning summary',
                          style: DashText.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.calmBlueDark,
                          ),
                        ),
                      ),
                      const FaIcon(
                        FontAwesomeIcons.chevronRight,
                        size: 13,
                        color: AppColors.calmBlue,
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

  int _cardInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _cardMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Widget _buildChildMetric({
    required dynamic icon,
    required int value,
    required String label,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, size: 17, color: color),
          const SizedBox(height: 5),
          Text(
            '$value',
            style: DashText.heading(fontSize: 20, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: DashText.caption(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ).copyWith(height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildChildInsight({
    required dynamic icon,
    required String eyebrow,
    required String title,
    required String detail,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: FaIcon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: DashText.caption(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ).copyWith(letterSpacing: 0.8),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashText.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DashText.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCardMessage({
    required dynamic icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          FaIcon(icon, size: 18, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DashText.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: DashText.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
