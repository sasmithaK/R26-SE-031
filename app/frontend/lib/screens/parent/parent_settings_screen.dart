import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../utils/avatar_utils.dart';
import '../../theme/app_theme.dart';
import '../welcome_screen.dart';
import '../assessment_prompt_screen.dart';
import '../comprehensive_assessment_selection_screen.dart';
import '../add_student_screen.dart';
import '../dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../services/progress_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Parent Account Screen — Frontend Redesign with World-Class UX
class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key});

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen>
    with TickerProviderStateMixin {
  // ── State ──
  bool _isLoading = true;
  bool _isUploading = false;
  String _userName = '';
  String _userEmail = '';
  String? _profilePictureUrl;
  String _authProvider = 'local';
  List<dynamic> _students = [];
  final Set<String> _deletingStudentIds = {};
  bool _showAllStudents = false;

  // Email preference toggles
  bool _progressEmails = true;
  bool _periodicUpdates = true;
  bool _loginAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await AuthService().getUserProfile();
    final students = await StudentService().getStudents();
    final provider = await AuthService().getAuthProvider();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _students = students;
        _authProvider = provider;
        if (profile != null) {
          _userName = profile['name'] ?? '';
          _userEmail = profile['email'] ?? '';
          _loginAlertsEnabled = profile['login_alerts_enabled'] ?? true;
          _profilePictureUrl = profile['profile_picture_url'];
        }
      });
    }
  }


  Future<void> _pickAndUploadImage() async {
    if (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty) {
      // Show bottom sheet to Change or Remove
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Profile Photo',
                style: AppTypography.heading(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.calmBlue),
                title: const Text('Change Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _openPicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    } else {
      _openPicker();
    }
  }
  
  Future<void> _removePhoto() async {
    setState(() => _isUploading = true);
    try {
      await AuthService().deleteProfilePicture();
      setState(() {
        _profilePictureUrl = null;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove image: $e')),
        );
      }
    }
  }

  Future<void> _openPicker() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final url = await AuthService().uploadProfilePicture(File(pickedFile.path));
        setState(() {
          _profilePictureUrl = url;
          _isUploading = false;
        });
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e')),
          );
        }
      }
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

  Future<void> _toggleLoginAlerts(bool value) async {
    final previousValue = _loginAlertsEnabled;
    setState(() => _loginAlertsEnabled = value);
    try {
      await AuthService().toggleLoginAlerts(value);
    } catch (e) {
      setState(() => _loginAlertsEnabled = previousValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update login alerts: $e')),
        );
      }
    }
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
          // Avatar circle with profile picture or initials
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
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
                    image: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                        ? DecorationImage(
                            // Build the full URL if it's relative
                            image: NetworkImage(
                              _profilePictureUrl!.startsWith('http') 
                                  ? _profilePictureUrl! 
                                  : 'https://adaptedmind-auth-api.onrender.com$_profilePictureUrl'
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
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.calmBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
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
                  child: FaIcon(
                    _authProvider == 'google'
                        ? FontAwesomeIcons.google
                        : FontAwesomeIcons.microsoft,
                    size: 14,
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
        const SizedBox(height: 24),
        // Delete Account
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _showDeleteAccountDialog,
            icon: const Icon(Icons.delete_forever_rounded,
                color: Colors.redAccent, size: 20),
            label: Text(
              'delete account',
              style: AppTypography.body(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.calmBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.calmBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: AppTypography.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (comingSoon) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warmAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'soon',
                      style: AppTypography.caption(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warmAmber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 32,
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
          final Map<String, dynamic> compResults = (student['comprehensive_assessment_results'] as Map?)?.cast<String, dynamic>() ?? {};
          final bool needsScreening = compResults.length < 4;

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
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.cream,
                            backgroundImage: AssetImage(
                                AvatarUtils.getCorrectedAvatarPath(student['avatar_url'] as String?, 'assets/images/characters/human/human_student_1.png')),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              student['first_name'] ?? 'unknown',
                              style: AppTypography.body(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Screening Status Pill (replaces limit)
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
                                          student['first_name'] ?? 'Student',
                                      avatarUrl: AvatarUtils.getCorrectedAvatarPath(student['avatar_url'] as String?),
                                    ),
                                  ),
                                ).then((_) => _loadData());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.warmAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        size: 13, color: AppColors.warmAmber),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pending',
                                      style: AppTypography.caption(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warmAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ComprehensiveAssessmentSelectionScreen(
                                      studentId: student['id'],
                                      studentName:
                                          student['first_name'] ?? 'Student',
                                    ),
                                  ),
                                ).then((_) => _loadData());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.gentleGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 13, color: AppColors.gentleGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Completed',
                                      style: AppTypography.caption(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.gentleGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Action 2: Edit
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
                          // Action 3: Reset Skills
                          _iconBtn(
                            Icons.restart_alt_rounded,
                            AppColors.warmAmber,
                            () => _showResetSkillsDialog(
                                student as Map<String, dynamic>),
                          ),
                          // Action 4: Delete
                          _iconBtn(
                            Icons.delete_outline_rounded,
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

  Widget _iconBtn(IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: onTap == null
              ? color.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: onTap == null ? color.withValues(alpha: 0.4) : color,
            size: 16),
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
        _buildNotifToggle(
          'login alerts',
          'get notified when your account is accessed from a new device.',
          _loginAlertsEnabled,
          (v) => _toggleLoginAlerts(v),
        ),
        _buildNotifToggle(
          'learning progress',
          'get notified when your child completes a screening or milestone.',
          _progressEmails,
          (v) => setState(() => _progressEmails = v),
        ),
        _buildNotifToggle(
          'app updates & features',
          'receive important announcements about new educational tools.',
          _periodicUpdates,
          (v) => setState(() => _periodicUpdates = v),
        ),
      ],
    );
  }

  Widget _buildNotifToggle(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    bool showInfo = false;
    return StatefulBuilder(builder: (context, setLocalState) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setLocalState(() => showInfo = !showInfo),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.info_outline_rounded,
                        size: 18,
                        color: showInfo
                            ? AppColors.calmBlue
                            : AppColors.textHint),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.gentleGreen,
                  activeTrackColor: AppColors.gentleGreen.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.borderLight,
                ),
              ],
            ),
            if (showInfo)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 40),
                child: Text(
                  subtitle,
                  style: AppTypography.caption(
                          fontSize: 12, color: AppColors.textSecondary)
                      .copyWith(height: 1.3),
                ),
              ),
          ],
        ),
      );
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  HELP & SUPPORT CONTENT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHelpContent() {
    return Column(
      children: [
        _buildHelpRow(Icons.email_outlined, 'email support',
            'sipsara.app.support@gmail.com'),
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
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
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

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.calmBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: AppColors.calmBlue, size: 28),
                      ),
                      IconButton(
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(LocalizationService.instance.t('update_name'), style: AppTypography.heading(fontSize: 22, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(LocalizationService.instance.t('update_name_desc'), style: AppTypography.body(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: AppTypography.caption(color: Colors.redAccent))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: controller,
                    style: AppTypography.body(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      hintStyle: AppTypography.body(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final newName = controller.text.trim();
                              if (newName.isEmpty || newName.length < 2) {
                                setDialogState(() => errorMessage = 'Name must be at least 2 characters.');
                                return;
                              }
                              setDialogState(() {
                                isLoading = true;
                                errorMessage = null;
                              });
                              
                              final error = await AuthService().updateProfile(name: newName);

                              if (error != null) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = error;
                                });
                              } else {
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                setState(() => _userName = newName);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                  content: Text(LocalizationService.instance.t('name_updated_success')),
                                  backgroundColor: AppColors.gentleGreen,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.calmBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(LocalizationService.instance.t('save_changes'), style: AppTypography.button(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
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
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.calmBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mail_outline_rounded, color: AppColors.calmBlue, size: 28),
                      ),
                      IconButton(
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(LocalizationService.instance.t('update_email_title'), style: AppTypography.heading(fontSize: 22, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(LocalizationService.instance.t('update_email_desc'), style: AppTypography.body(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: AppTypography.caption(color: Colors.redAccent))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTypography.body(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Email Address',
                      hintStyle: AppTypography.body(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final newEmail = controller.text.trim();
                              if (newEmail.isEmpty || !newEmail.contains('@')) {
                                setDialogState(() => errorMessage = 'Enter a valid email.');
                                return;
                              }
                              setDialogState(() {
                                isLoading = true;
                                errorMessage = null;
                              });

                              final error = await AuthService().requestEmailUpdate(newEmail);

                              if (error != null) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = error;
                                });
                              } else {
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                _showEmailOtpDialog(newEmail);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.calmBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(LocalizationService.instance.t('send_verification_code'), style: AppTypography.button(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showEmailOtpDialog(String newEmail) {
    final controller = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gentleGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_outlined, color: AppColors.gentleGreen, size: 28),
                      ),
                      IconButton(
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(LocalizationService.instance.t('verify_email'), style: AppTypography.heading(fontSize: 22, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('${LocalizationService.instance.t('verify_email_desc')}$newEmail.', style: AppTypography.body(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: AppTypography.caption(color: Colors.redAccent))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: AppTypography.body(fontSize: 20).copyWith(letterSpacing: 4),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: AppTypography.body(color: AppColors.textHint).copyWith(letterSpacing: 4),
                      filled: true,
                      fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final otp = controller.text.trim();
                              if (otp.length != 6) {
                                setDialogState(() => errorMessage = 'Enter a valid 6-digit code.');
                                return;
                              }
                              setDialogState(() {
                                isLoading = true;
                                errorMessage = null;
                              });

                              final error = await AuthService().verifyEmailUpdate(newEmail, otp);

                              if (error != null) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = error;
                                });
                              } else {
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                setState(() => _userEmail = newEmail);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                  content: Text(LocalizationService.instance.t('email_updated_success')),
                                  backgroundColor: AppColors.gentleGreen,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gentleGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(LocalizationService.instance.t('verify_and_update'), style: AppTypography.button(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
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
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.calmBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: AppColors.calmBlue, size: 28),
                      ),
                      IconButton(
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(LocalizationService.instance.t('change_password_title'), style: AppTypography.heading(fontSize: 22, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(LocalizationService.instance.t('change_password_desc'), style: AppTypography.body(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: AppTypography.caption(color: Colors.redAccent))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: oldPwController,
                    obscureText: true,
                    style: AppTypography.body(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Current Password',
                      hintStyle: AppTypography.body(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: const Icon(Icons.lock_open_rounded, color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPwController,
                    obscureText: true,
                    style: AppTypography.body(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      hintStyle: AppTypography.body(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              setDialogState(() {
                                isLoading = true;
                                errorMessage = null;
                              });
                              
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
                                    content: Text(LocalizationService.instance.t('password_changed')),
                                    backgroundColor: AppColors.gentleGreen,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.calmBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(LocalizationService.instance.t('update_password'), style: AppTypography.button(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
  void _showDeleteAccountDialog() {
    final controller = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    bool isMatch = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                LocalizationService.instance.t('delete_account'),
                style: AppTypography.heading(fontSize: 22, color: Colors.redAccent),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationService.instance.t('delete_account_desc'),
                    style: AppTypography.body(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To confirm, type your full name:',
                    style: AppTypography.caption(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: _userName,
                      errorText: errorMessage,
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        isMatch = val.trim() == _userName;
                        errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: AppTypography.body(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: (!isMatch || isLoading)
                      ? null
                      : () async {
                          setDialogState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          final error = await AuthService().deleteAccount();

                          if (error != null) {
                            setDialogState(() {
                              isLoading = false;
                              errorMessage = error;
                            });
                          } else {
                            await AuthService().logout();
                            if (!ctx.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              ctx,
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (route) => false,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Delete Permanently', style: AppTypography.body(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteStudentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeleteStudentDialog(
        student: student,
        onDeleted: () {
          // Trigger the magic disappear effect!
          setState(() {
            _deletingStudentIds.add(student['id']);
          });

          // Wait for the poof animation to finish before removing from list
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            setState(() {
              _students.removeWhere((s) => s['id'] == student['id']);
              _deletingStudentIds.remove(student['id']);
            });
          });
        },
      ),
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
}

class _DeleteStudentDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onDeleted;

  const _DeleteStudentDialog({
    required this.student,
    required this.onDeleted,
  });

  @override
  State<_DeleteStudentDialog> createState() => _DeleteStudentDialogState();
}

class _DeleteStudentDialogState extends State<_DeleteStudentDialog> {
  bool _isDeleting = false;
  String? _deleteError;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _checkConnections();
  }

  Future<void> _checkConnections() async {
    try {
      final connections = await AuthService().getConnections();
      if (!mounted) return;
      setState(() {
        _isConnected = connections.any((c) {
          final cId = c['student_id']?.toString() ?? '';
          final sId = widget.student['id']?.toString() ?? 'unknown';
          
          // Fallback to name matching if the hosted backend doesn't return student_id
          final cName = c['student_name']?.toString() ?? '';
          final sName = widget.student['first_name']?.toString() ?? 'unknown';
          
          return (cId.isNotEmpty && cId == sId) || (cName.isNotEmpty && cName == sName);
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.student['first_name'] ?? 'this student';
    final studentId = widget.student['id'];

    return AlertDialog(
      backgroundColor: AppColors.warmWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Text('delete student?', style: AppTypography.heading(fontSize: 20, color: Colors.redAccent)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'are you absolutely sure you want to delete $studentName? this action cannot be undone and all learning progress will be lost permanently.',
            style: AppTypography.body(fontSize: 15, color: AppColors.textPrimary),
          ),
          if (_isConnected == null)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmAmber),
              ),
            ),
          if (_isConnected == true)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warmAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warmAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'this student is connected to a therapist. deleting them will permanently break that connection.',
                      style: AppTypography.body(fontSize: 14, color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (_deleteError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_deleteError!, style: AppTypography.body(fontSize: 13, color: Colors.redAccent)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text('cancel', style: AppTypography.body(fontSize: 14, color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isDeleting
              ? null
              : () async {
                  setState(() {
                    _isDeleting = true;
                    _deleteError = null;
                  });

                  final error = await StudentService().deleteStudent(studentId);

                  if (!mounted) return;
                  if (error != null) {
                    setState(() {
                      _isDeleting = false;
                      _deleteError = error;
                    });
                  } else {
                    Navigator.pop(context); // Close dialog
                    widget.onDeleted();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$studentName deleted successfully.'),
                        backgroundColor: AppColors.gentleGreen,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text('delete', style: AppTypography.button(fontSize: 14)),
        ),
      ],
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
}
