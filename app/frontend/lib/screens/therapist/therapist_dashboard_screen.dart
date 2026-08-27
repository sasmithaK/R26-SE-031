import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'therapist_students_screen.dart';
import 'therapist_messages_screen.dart';
import 'therapist_profile_screen.dart';
import '../../config/api_config.dart';
import 'therapist_student_detail_screen.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService().getUserProfile();
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _DashboardHome(
            profile: _profile,
            onProfileTap: () => setState(() => _currentIndex = 3),
          ),
          const TherapistStudentsScreen(),
          const TherapistMessagesScreen(),
          const TherapistProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: AppColors.calmBlueDark.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'home'),
                _buildNavItem(1, Icons.people_outline_rounded, 'students'),
                _buildNavItem(
                  2,
                  Icons.chat_bubble_outline_rounded,
                  'messages',
                  badgeCount: 3,
                ),
                _buildNavItem(3, Icons.person_outline_rounded, 'profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 0) _loadProfile(); // Refresh when switching to home tab
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.calmBlue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isSelected ? AppColors.calmBlue : AppColors.textHint,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 2,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softCoral,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.calmBlue : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Home (Tab 0) ───
class _DashboardHome extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback? onProfileTap;
  const _DashboardHome({super.key, this.profile, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Welcome Header
              Builder(
                builder: (context) {
                  final name = profile?['name'] ?? 'Doctor';
                  final profilePicUrl =
                      profile?['profile_picture_url'] as String?;

                  // Extract initials safely
                  final parts = name.trim().split(' ');
                  String initials = '?';
                  if (parts.length >= 2) {
                    initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                  } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
                    initials = parts[0][0].toUpperCase();
                  }

                  final hour = DateTime.now().hour;
                  String greetingText;
                  if (hour < 12) {
                    greetingText = 'Good morning,';
                  } else if (hour < 17) {
                    greetingText = 'Good afternoon,';
                  } else if (hour < 20) {
                    greetingText = 'Good evening,';
                  } else {
                    greetingText = 'Good night,';
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greetingText,
                              style: AppTypography.body(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Dr. $name 👋',
                              style: AppTypography.heading(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onProfileTap,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.blueButtonGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.calmBlue.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            image:
                                profilePicUrl != null &&
                                    profilePicUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                      ApiConfig.getProfileImageUrl(profilePicUrl),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: profilePicUrl == null || profilePicUrl.isEmpty
                              ? Center(
                                  child: Text(
                                    initials,
                                    style: AppTypography.heading(
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Quick Stats Row
              Row(
                children: [
                  _buildQuickStat(
                    '12',
                    'students',
                    Icons.people_outline_rounded,
                    AppColors.calmBlue,
                  ),
                  const SizedBox(width: 10),
                  _buildQuickStat(
                    '3',
                    'today',
                    Icons.event_available_rounded,
                    AppColors.gentleGreen,
                  ),
                  const SizedBox(width: 10),
                  _buildQuickStat(
                    '76%',
                    'avg score',
                    Icons.insights_rounded,
                    AppColors.warmAmber,
                  ),
                  const SizedBox(width: 10),
                  _buildQuickStat(
                    '3',
                    'messages',
                    Icons.mail_outline_rounded,
                    AppColors.softCoral,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Needs Attention
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'needs attention',
                    style: AppTypography.heading(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softCoral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '2 flagged',
                      style: AppTypography.caption(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.softCoral,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildAlertCard(
                context,
                name: 'Dinuka Bandara',
                avatar: '👦',
                issue: 'comprehension score dropped 18% this week',
                risk: 'At Risk',
                progress: 42,
              ),
              const SizedBox(height: 10),
              _buildAlertCard(
                context,
                name: 'Ishara Gamage',
                avatar: '👧',
                issue: 'no sessions completed in 6 days',
                risk: 'At Risk',
                progress: 50,
              ),

              const SizedBox(height: 28),

              // Recent Activity
              Text(
                'recent activity',
                style: AppTypography.heading(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _buildActivityItem(
                icon: Icons.emoji_events_rounded,
                color: AppColors.warmAmber,
                title: 'Nethmi Silva reached Level 5!',
                subtitle: '2 hours ago',
              ),
              _buildActivityItem(
                icon: Icons.chat_rounded,
                color: AppColors.calmBlue,
                title: 'New message from Kumari Perera',
                subtitle: '3 hours ago',
              ),
              _buildActivityItem(
                icon: Icons.check_circle_rounded,
                color: AppColors.gentleGreen,
                title: 'Kavitha completed phonics session',
                subtitle: 'Yesterday at 4:30 PM',
              ),
              _buildActivityItem(
                icon: Icons.trending_up_rounded,
                color: AppColors.gentleGreen,
                title: 'Tharindu\'s fluency improved 12%',
                subtitle: 'Yesterday at 2:15 PM',
              ),
              _buildActivityItem(
                icon: Icons.person_add_rounded,
                color: AppColors.calmBlue,
                title: 'New student connected: Ishara G.',
                subtitle: '2 days ago',
              ),

              const SizedBox(height: 28),

              // Today's Schedule
              Text(
                'today\'s schedule',
                style: AppTypography.heading(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _buildScheduleItem(
                '9:00 AM',
                'Kavitha Perera',
                'Phonological Awareness',
                AppColors.calmBlue,
              ),
              _buildScheduleItem(
                '10:30 AM',
                'Ashan Fernando',
                'Reading Fluency',
                AppColors.gentleGreen,
              ),
              _buildScheduleItem(
                '2:00 PM',
                'Nethmi Silva',
                'Comprehension',
                AppColors.warmAmber,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildQuickStat(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.heading(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAlertCard(
    BuildContext context, {
    required String name,
    required String avatar,
    required String issue,
    required String risk,
    required int progress,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TherapistStudentDetailScreen(
              student: {
                'name': name,
                'avatar': avatar,
                'age': 9,
                'parent': 'Parent',
                'progress': progress,
                'risk': risk,
                'connected': 'May 2026',
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.softCoral.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.softCoral.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.slateBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(avatar, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    issue,
                    style: AppTypography.caption(
                      fontSize: 12,
                      color: AppColors.softCoral,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.softCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${progress}%',
                style: AppTypography.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.softCoral,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildScheduleItem(
    String time,
    String student,
    String type,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlueDark.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            time,
            style: AppTypography.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student,
                  style: AppTypography.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  type,
                  style: AppTypography.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.play_arrow_rounded, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}
