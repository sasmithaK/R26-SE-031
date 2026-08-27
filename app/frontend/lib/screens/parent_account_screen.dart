import 'package:flutter/material.dart';
import '../widgets/app_loading_indicator.dart';
import '../utils/avatar_utils.dart';
import '../../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'assessment_prompt_screen.dart';
import 'add_student_screen.dart';
import 'therapist/therapist_dashboard_screen.dart';
import '../../services/localization_service.dart';
import 'dashboard_screen.dart';
import 'comprehensive_assessment_screen.dart';
import 'comprehensive_results_screen.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../services/progress_service.dart';
import '../services/accessibility_service.dart';

/// Parent Account Screen — Frontend Redesign with World-Class UX
class ParentAccountScreen extends StatefulWidget {
  const ParentAccountScreen({super.key});

  @override
  State<ParentAccountScreen> createState() => _ParentAccountScreenState();
}

class _ParentAccountScreenState extends State<ParentAccountScreen>
    with TickerProviderStateMixin {
  // ── State ──
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  String _authProvider = 'local';
  List<dynamic> _students = [];
  final Set<String> _deletingStudentIds = {};
  bool _showAllStudents = false;
  String? _selectedAssessmentStudentId;

  // Email preference toggles
  bool _progressEmails = true;
  bool _promotions = false;
  bool _newsletters = false;
  bool _periodicUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await AccessibilityService().init();
    final profile = await AuthService().getUserProfile();
    final students = await StudentService().getStudents();
    final provider = await AuthService().getAuthProvider();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _students = students;
        if (_students.isNotEmpty && _selectedAssessmentStudentId == null) {
          _selectedAssessmentStudentId = _students.first['id'];
        }
        _authProvider = provider;
        if (profile != null) {
          _userName = profile['name'] ?? '';
          _userEmail = profile['email'] ?? '';
        }
      });
    }
  }

  // ── Helper: Get initials for avatar ──
  String get _initials {
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  bool get _isSocialLogin =>
      _authProvider == 'google' || _authProvider == 'microsoft';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildProfileCard(),
                    const SizedBox(height: 8),
                    _buildCollapsibleSections(),
                    const SizedBox(height: 16),
                    _buildLogoutButton(),
                    const SizedBox(height: 12),
                    _buildVersionText(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  HEADER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary, size: 20),
              ),
            ),
          if (Navigator.canPop(context)) const SizedBox(width: 14),
          Text(
            'parent account',
            style: AppTypography.heading(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  PROFILE CARD (Avatar + Name + Email)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.calmBlue.withValues(alpha: 0.08),
            AppColors.slateBg.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Avatar circle with initials
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF5A9DE0), Color(0xFF7DCE7D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.calmBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initials,
                style: AppTypography.heading(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _userName.isNotEmpty ? _userName : 'Parent',
            style: AppTypography.heading(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSocialLogin)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    _authProvider == 'google'
                        ? Icons.g_mobiledata_rounded
                        : Icons.window_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              Text(
                _userEmail,
                style: AppTypography.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  COLLAPSIBLE SECTIONS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildCollapsibleSections() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildExpansionSection(
              icon: Icons.person_outline_rounded,
              title: 'account & security',
              child: _buildAccountContent(),
            ),
            _divider(),
            _buildExpansionSection(
              icon: Icons.school_rounded,
              title: 'my students',
              trailing: _students.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.calmBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_students.length}',
                        style: AppTypography.caption(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.calmBlue,
                        ),
                      ),
                    )
                  : null,
              child: _buildStudentsContent(),
            ),
            _divider(),
            _buildExpansionSection(
              icon: Icons.assignment_rounded,
              title: 'comprehensive assessments',
              child: _buildComprehensiveAssessmentsContent(),
            ),
            _divider(),
            _buildExpansionSection(
              icon: Icons.accessibility_new_rounded,
              title: 'neuroinclusive settings',
              child: _buildAccessibilityContent(),
            ),
            _divider(),
            _buildExpansionSection(
              icon: Icons.diamond_outlined,
              title: 'subscription',
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warmAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'coming soon',
                  style: AppTypography.caption(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warmAmber,
                  ),
                ),
              ),
              child: _buildSubscriptionContent(),
            ),
            _divider(),
            _buildExpansionSection(
              icon: Icons.notifications_none_rounded,
              title: 'notifications',
              child: _buildNotificationsContent(),
            ),
            _divider(),
            _buildExpansionSection(
              icon: Icons.help_outline_rounded,
              title: 'help & support',
              child: _buildHelpContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionSection({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 20, right: 20, bottom: 16),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.calmBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.calmBlue, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textHint,
        children: [child],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.borderLight.withValues(alpha: 0.6),
      indent: 20,
      endIndent: 20,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  ACCOUNT & SECURITY CONTENT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildAccountContent() {
    return Column(
      children: [
        _buildEditableRow(
          label: 'full name',
          value: _userName,
          onEdit: () => _showEditNameDialog(),
        ),
        _buildEditableRow(
          label: 'email',
          value: _userEmail,
          onEdit: _isSocialLogin ? null : () => _showEditEmailDialog(),
          subtitle: _isSocialLogin ? 'managed by $_authProvider' : null,
        ),
        _buildEditableRow(
          label: 'password',
          value: '••••••••',
          editLabel: 'change',
          onEdit: _isSocialLogin ? null : () => _showChangePasswordDialog(),
          subtitle: _isSocialLogin ? 'managed by $_authProvider' : null,
        ),
        _buildEditableRow(
          label: LocalizationService.instance.t('language'),
          value: LocalizationService.instance.currentLocale == 'en' ? 'English' : 'සිංහල',
          editLabel: LocalizationService.instance.t('change'),
          onEdit: () => _showChangeLanguageDialog(),
        ),
        const SizedBox(height: 12),
        // Security toggles
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slateBg.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _buildSecurityToggle(
                icon: Icons.lock_outline_rounded,
                label: 'two-factor auth',
                value: false,
                onChanged: (_) => _showComingSoon('Two-factor authentication'),
                comingSoon: true,
              ),
              const SizedBox(height: 8),
              _buildSecurityToggle(
                icon: Icons.notifications_active_outlined,
                label: 'login alerts',
                value: true,
                onChanged: (_) => _showComingSoon('Login alerts'),
                comingSoon: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Delete Account
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _showComingSoon('Delete Account'),
            icon: const Icon(Icons.delete_forever_rounded,
                color: Colors.redAccent, size: 18),
            label: Text(
              'delete account',
              style: AppTypography.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableRow({
    required String label,
    required String value,
    String? editLabel,
    VoidCallback? onEdit,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: AppTypography.caption(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.calmBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  editLabel ?? 'edit',
                  style: AppTypography.caption(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.calmBlue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool comingSoon = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.calmBlue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (comingSoon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warmAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'soon',
              style: AppTypography.caption(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.warmAmber,
              ),
            ),
          ),
        const SizedBox(width: 6),
        SizedBox(
          height: 28,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.gentleGreen,
            activeTrackColor: AppColors.gentleGreen.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.borderLight,
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  COMPREHENSIVE ASSESSMENTS CONTENT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildComprehensiveAssessmentsContent() {
    if (_students.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'add a student to take assessments.',
            style: AppTypography.body(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dropdown to select child
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.slateBg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedAssessmentStudentId ?? _students.first['id'],
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.calmBlue),
              style: AppTypography.body(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedAssessmentStudentId = newValue;
                  });
                }
              },
              items: _students.map<DropdownMenuItem<String>>((student) {
                return DropdownMenuItem<String>(
                  value: student['id'],
                  child: Text(student['first_name'] ?? 'Unknown'),
                );
              }).toList(),
            ),
          ),
        ),

        // Categories
        _buildAssessmentCategoryCard('basic', 'මූලික ඩිස්ලෙක්සියා පරීක්ෂණය', Icons.psychology_rounded),
        _buildAssessmentCategoryCard('reading', 'කියවීම හා දෘශ්‍ය සංජානන සම්බන්ධ අපහසුතා', Icons.menu_book_rounded),
        _buildAssessmentCategoryCard('writing', 'ලිවීම සම්බන්ධ අපහසුතා', Icons.edit_rounded),
        _buildAssessmentCategoryCard('other', 'වෙනත් සම්බන්ධ අපහසුතා', Icons.more_horiz_rounded),

        const SizedBox(height: 12),
        // View Results
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              if (_selectedAssessmentStudentId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ComprehensiveResultsScreen(
                      studentId: _selectedAssessmentStudentId!,
                      studentName: _students.firstWhere((s) => s['id'] == _selectedAssessmentStudentId)['first_name'] ?? 'Student',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.analytics_rounded, size: 18),
            label: Text('view results', style: AppTypography.body(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.calmBlue,
              side: const BorderSide(color: AppColors.calmBlue),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssessmentCategoryCard(String category, String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (_selectedAssessmentStudentId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ComprehensiveAssessmentScreen(
                    studentId: _selectedAssessmentStudentId!,
                    category: category,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.calmBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  MY STUDENTS CONTENT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildStudentsContent() {
    if (_students.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.slateBg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.child_care_rounded,
                    color: AppColors.textHint, size: 36),
                const SizedBox(height: 8),
                Text(
                  'no students yet',
                  style: AppTypography.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildAddStudentButton(),
        ],
      );
    }

    final displayStudents =
        _showAllStudents ? _students : _students.take(3).toList();

    return Column(
      children: [
        ...displayStudents.map((student) {
          final bool isDeleting =
              _deletingStudentIds.contains(student['id']);
          final bool needsScreening =
              student['assessment_completed'] != true;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: isDeleting ? 0.0 : 1.0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 400),
              scale: isDeleting ? 0.01 : 1.0,
              curve: Curves.easeInBack,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.warmWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DashboardScreen(
                            studentData: student as Map<String, dynamic>,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.cream,
                            backgroundImage: AssetImage(
                                AvatarUtils.getCorrectedAvatarPath(student['avatar_url'] as String?, 'assets/images/characters/human/human_student_1.png')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['first_name'] ?? 'unknown',
                                  style: AppTypography.body(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (needsScreening)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AssessmentPromptScreen(
                                            studentId: student['id'],
                                            studentName:
                                                student['first_name'] ??
                                                    'Student',
                                            avatarUrl:
                                                AvatarUtils.getCorrectedAvatarPath(student['avatar_url'] as String?),
                                          ),
                                        ),
                                      ).then((_) => _loadData());
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                            Icons
                                                .warning_amber_rounded,
                                            color: AppColors.warmAmber,
                                            size: 13),
                                        const SizedBox(width: 4),
                                        Text(
                                          'complete screening →',
                                          style: AppTypography.caption(
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: AppColors.calmBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.gentleGreen,
                                          size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        'screening completed',
                                        style: AppTypography.caption(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w500,
                                          color: AppColors.gentleGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // Daily limit pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student['daily_limit'] ?? 'No Limit',
                              style: AppTypography.caption(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Edit
                          _iconBtn(
                            Icons.edit_rounded,
                            AppColors.calmBlue,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddStudentScreen(
                                      editStudentData: student
                                          as Map<String, dynamic>),
                                ),
                              ).then((_) => _loadData());
                            },
                          ),
                          const SizedBox(width: 4),
                          // Reset Skills
                          _iconBtn(
                            Icons.restart_alt_rounded,
                            AppColors.warmAmber,
                            () => _showResetSkillsDialog(
                                student as Map<String, dynamic>),
                          ),
                          const SizedBox(width: 4),
                          // Delete
                          _iconBtn(
                            Icons.delete_rounded,
                            Colors.redAccent,
                            () => _showDeleteStudentDialog(
                                student as Map<String, dynamic>),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        if (_students.length > 3 && !_showAllStudents)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => setState(() => _showAllStudents = true),
              child: Text(
                'view all ${_students.length} students →',
                style: AppTypography.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.calmBlue,
                ),
              ),
            ),
          ),
        if (_students.length > 3 && _showAllStudents)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => setState(() => _showAllStudents = false),
              child: Text(
                'show less',
                style: AppTypography.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        _buildAddStudentButton(),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  Widget _buildAddStudentButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddStudentScreen(),
            ),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('add student',
            style: AppTypography.body(
                fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gentleGreen,
          side: BorderSide(
              color: AppColors.gentleGreen.withValues(alpha: 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  SUBSCRIPTION CONTENT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildSubscriptionContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warmAmber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.warmAmber.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.diamond_outlined,
              color: AppColors.warmAmber, size: 32),
          const SizedBox(height: 10),
          Text(
            'premium plans coming soon!',
            style: AppTypography.body(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'we\'re crafting amazing premium features to supercharge your child\'s learning journey.',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  NOTIFICATIONS CONTENT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildNotificationsContent() {
    return Column(
      children: [
        _buildNotifToggle('progress reports', _progressEmails,
            (v) => setState(() => _progressEmails = v)),
        _buildNotifToggle('promotions & offers', _promotions,
            (v) => setState(() => _promotions = v)),
        _buildNotifToggle('newsletters', _newsletters,
            (v) => setState(() => _newsletters = v)),
        _buildNotifToggle('periodic updates', _periodicUpdates,
            (v) => setState(() => _periodicUpdates = v)),
      ],
    );
  }

  Widget _buildNotifToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                  fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          SizedBox(
            height: 28,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.gentleGreen,
              activeTrackColor:
                  AppColors.gentleGreen.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.borderLight,
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  HELP & SUPPORT CONTENT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHelpContent() {
    return Column(
      children: [
        _buildHelpRow(Icons.email_outlined, 'email support',
            'support@sipsara.com'),
        const SizedBox(height: 8),
        _buildHelpRow(Icons.phone_outlined, 'phone support',
            '1-800-123-4567'),
        const SizedBox(height: 8),
        _buildHelpRow(
            Icons.article_outlined, 'FAQ', 'help.sipsara.com'),
      ],
    );
  }

  Widget _buildHelpRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.calmBlue, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.body(
              fontSize: 14, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.body(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  LOGOUT + VERSION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await AuthService().logout();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text('logout',
              style: AppTypography.button(fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.softCoral.withValues(alpha: 0.12),
            foregroundColor: AppColors.softCoral,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionText() {
    return Text(
      'sipsara v1.0.0',
      style: AppTypography.caption(
        fontSize: 12,
        color: AppColors.textHint,
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  DIALOGS (Frontend only logic for Name / Email updates)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showChangeLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(LocalizationService.instance.t('select_language'),
              style: AppTypography.heading(fontSize: 20, color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                trailing: LocalizationService.instance.currentLocale == 'en'
                    ? const Icon(Icons.check, color: AppColors.gentleGreen)
                    : null,
                onTap: () {
                  LocalizationService.instance.setLocale('en');
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
              ListTile(
                title: const Text('සිංහල'),
                trailing: LocalizationService.instance.currentLocale == 'si'
                    ? const Icon(Icons.check, color: AppColors.gentleGreen)
                    : null,
                onTap: () {
                  LocalizationService.instance.setLocale('si');
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel',
                  style: AppTypography.body(fontSize: 14, color: AppColors.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.cardSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text('edit name',
                style: AppTypography.heading(
                    fontSize: 20, color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(errorMessage!,
                        style: AppTypography.body(
                            fontSize: 14, color: AppColors.softCoral)),
                  ),
                TextField(
                  controller: controller,
                  style: AppTypography.body(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'full name',
                    labelStyle: AppTypography.caption(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text('cancel',
                    style: AppTypography.body(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty || newName.length < 2) {
                          setDialogState(() => errorMessage =
                              'Name must be at least 2 characters.');
                          return;
                        }
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                        
                        // Mock API call to satisfy "no backend needed"
                        await Future.delayed(const Duration(milliseconds: 800));

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        setState(() => _userName = newName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name updated locally!'),
                            backgroundColor: AppColors.gentleGreen,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calmBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('save',
                        style: AppTypography.button(fontSize: 14)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditEmailDialog() {
    final controller = TextEditingController(text: _userEmail);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.cardSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text('edit email',
                style: AppTypography.heading(
                    fontSize: 20, color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(errorMessage!,
                        style: AppTypography.body(
                            fontSize: 14, color: AppColors.softCoral)),
                  ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTypography.body(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'email address',
                    labelStyle: AppTypography.caption(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text('cancel',
                    style: AppTypography.body(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final newEmail = controller.text.trim();
                        if (newEmail.isEmpty || !newEmail.contains('@')) {
                          setDialogState(
                              () => errorMessage = 'Enter a valid email.');
                          return;
                        }
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        // Mock API call
                        await Future.delayed(const Duration(milliseconds: 800));

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        setState(() => _userEmail = newEmail);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email updated locally!'),
                            backgroundColor: AppColors.gentleGreen,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calmBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('save',
                        style: AppTypography.button(fontSize: 14)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showChangePasswordDialog() {
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.cardSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text('change password',
                style: AppTypography.heading(
                    fontSize: 20, color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(errorMessage!,
                        style: AppTypography.body(
                            fontSize: 14, color: AppColors.softCoral)),
                  ),
                TextField(
                  controller: oldPwController,
                  obscureText: true,
                  style: AppTypography.body(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'current password',
                    labelStyle: AppTypography.caption(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPwController,
                  obscureText: true,
                  style: AppTypography.body(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'new password',
                    labelStyle: AppTypography.caption(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text('cancel',
                    style: AppTypography.body(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                        // Use existing backend API for this!
                        final error = await AuthService().changePassword(
                          oldPwController.text,
                          newPwController.text,
                        );
                        if (error != null) {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = error;
                          });
                        } else {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed!'),
                              backgroundColor: AppColors.gentleGreen,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calmBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('save',
                        style: AppTypography.button(fontSize: 14)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showResetSkillsDialog(Map<String, dynamic> student) {
    final studentName = student['first_name'] ?? 'this student';
    final studentId = student['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        bool isResetting = false;

        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.warmWhite,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.restart_alt_rounded,
                    color: AppColors.warmAmber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'reset skills?',
                    style: AppTypography.heading(
                        fontSize: 20, color: AppColors.warmAmber),
                  ),
                ),
              ],
            ),
            content: Text(
              'are you sure you want to reset all skill progress for $studentName? completed activities, scores, and unlock status will be reset back to the start.',
              style: AppTypography.body(
                  fontSize: 15, color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: isResetting ? null : () => Navigator.pop(ctx),
                child: Text('cancel',
                    style: AppTypography.body(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        setDialogState(() {
                          isResetting = true;
                        });

                        await ProgressService().resetStudentProgress(studentId);

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'skills progress reset for $studentName!',
                              style: AppTypography.body(color: Colors.white),
                            ),
                            backgroundColor: AppColors.gentleGreen,
                          ),
                        );

                        _loadData();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmAmber,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isResetting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('reset skills',
                        style: AppTypography.button(fontSize: 14)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showDeleteStudentDialog(
      Map<String, dynamic> student) async {
    final studentName = student['first_name'] ?? 'this student';
    final studentId = student['id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        String? deleteError;

        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.warmWhite,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 28),
                const SizedBox(width: 12),
                Text('delete student?',
                    style: AppTypography.heading(
                        fontSize: 20, color: Colors.redAccent)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'are you absolutely sure you want to delete $studentName? this action cannot be undone and all learning progress will be lost permanently.',
                  style: AppTypography.body(
                      fontSize: 15, color: AppColors.textPrimary),
                ),
                if (deleteError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(deleteError!,
                        style: AppTypography.body(
                            fontSize: 13, color: Colors.redAccent)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    isDeleting ? null : () => Navigator.pop(ctx),
                child: Text('cancel',
                    style: AppTypography.body(
                        fontSize: 14,
                        color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() {
                          isDeleting = true;
                          deleteError = null;
                        });

                        final error = await StudentService()
                            .deleteStudent(studentId);

                        if (error != null) {
                          setDialogState(() {
                            isDeleting = false;
                            deleteError = error;
                          });
                        } else {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx); // Close dialog first

                          // Trigger the magic disappear effect!
                          this.setState(() {
                            _deletingStudentIds.add(studentId);
                          });

                          // Wait for the poof animation to finish before removing from list
                          await Future.delayed(
                              const Duration(milliseconds: 500));

                          if (!mounted) return;
                          this.setState(() {
                            _students.removeWhere(
                                (s) => s['id'] == studentId);
                            _deletingStudentIds.remove(studentId);
                          });

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '$studentName deleted successfully.'),
                              backgroundColor:
                                  AppColors.gentleGreen,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isDeleting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('delete forever',
                        style: AppTypography.button(fontSize: 14)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon!'),
        backgroundColor: AppColors.calmBlue,
      ),
    );
  }

  Widget _buildAccessibilityContent() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AccessibilityService().useDyslexicFont,
        AccessibilityService().highContrastMode,
        AccessibilityService().relaxedTimeLimits,
      ]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize the app to match your child\'s cognitive profile.',
              style: AppTypography.caption(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildAccessibilityToggle(
              icon: Icons.font_download_outlined,
              title: 'OpenDyslexic Font',
              subtitle: 'Enhances readability by bottom-weighting letters to prevent rotation.',
              value: AccessibilityService().useDyslexicFont.value,
              onChanged: (val) => AccessibilityService().setDyslexicFont(val),
            ),
            const SizedBox(height: 12),
            _buildAccessibilityToggle(
              icon: Icons.contrast_rounded,
              title: 'High Contrast UI',
              subtitle: 'Increases visual distinction for children with visual processing difficulties.',
              value: AccessibilityService().highContrastMode.value,
              onChanged: (val) => AccessibilityService().setHighContrastMode(val),
            ),
            const SizedBox(height: 12),
            _buildAccessibilityToggle(
              icon: Icons.timer_off_outlined,
              title: 'Relaxed Time Limits',
              subtitle: 'Disables or extends countdown timers to reduce cognitive load and anxiety.',
              value: AccessibilityService().relaxedTimeLimits.value,
              onChanged: (val) => AccessibilityService().setRelaxedTimeLimits(val),
            ),
          ],
        );
      }
    );
  }

  Widget _buildAccessibilityToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slateBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.calmBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.calmBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTypography.caption(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.calmBlue,
            activeTrackColor: AppColors.calmBlue.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
