import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../welcome_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/localization_service.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _loginAlertsEnabled = true;

  bool _inAppNotifications = true;
  String _clinicName = '';
  String _specialization = '';

  String _userName = 'specialist';
  String _userEmail = '';
  String? _profilePictureUrl;
  String _authProvider = 'local';

  // State for collapsible sections
  bool _isAccountSettingsExpanded = false;
  bool _isClinicInfoExpanded = true;
  bool _isHelpExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await AuthService().getUserProfile();
      final provider = await AuthService().getAuthProvider();
      if (mounted && data != null) {
        setState(() {
          _profile = data;
          _userName =
              data['name'] ??
              '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
          if (_userName.isEmpty) _userName = 'specialist';
          _userEmail = data['email'] ?? '';
          _profilePictureUrl = data['profile_picture_url'];
          _authProvider = provider;
          _loginAlertsEnabled = data['login_alerts_enabled'] ?? true;
          _clinicName = data['clinic_name'] ?? '';
          _specialization = data['specialization'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
              Text('Profile Photo', style: AppTypography.heading(fontSize: 18)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.calmBlue,
                ),
                title: const Text('Change Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _openPicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove image: $e')));
      }
    }
  }

  Future<void> _openPicker() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final url = await AuthService().uploadProfilePicture(
          File(pickedFile.path),
        );
        setState(() {
          _profilePictureUrl = url;
          _isUploading = false;
        });
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
        }
      }
    }
  }

  void _showChangePasswordDialog() {
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.calmBlue,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Change Password',
                      style: AppTypography.heading(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Protect your account with a strong new password.',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: AppTypography.caption(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
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
                        hintStyle: AppTypography.body(
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_open_rounded,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPwController,
                      obscureText: true,
                      style: AppTypography.body(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'New Password',
                        hintStyle: AppTypography.body(
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textHint,
                        ),
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

                                final error = await AuthService()
                                    .changePassword(
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Update Password',
                                style: AppTypography.button(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.calmBlue),
              )
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
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

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
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          if (Navigator.canPop(context)) const SizedBox(width: 14),
          Text(
            LocalizationService.instance.t('Therapist_Account'),
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
                    image:
                        _profilePictureUrl != null &&
                            _profilePictureUrl!.isNotEmpty
                        ? DecorationImage(
                            // Build the full URL if it's relative
                            image: NetworkImage(
                              _profilePictureUrl!.startsWith('http')
                                  ? _profilePictureUrl!
                                  : 'https://adaptedmind-auth-api.onrender.com$_profilePictureUrl',
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child:
                      _profilePictureUrl == null || _profilePictureUrl!.isEmpty
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
            _userName.isNotEmpty ? _userName : 'Therapist',
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
              icon: Icons.local_hospital_rounded,
              title: LocalizationService.instance.t('Clinic_Connection'),
              child: _buildClinicContent(),
            ),
            _divider(),
            _buildExpansionSection(
              icon: Icons.person_outline_rounded,
              title: LocalizationService.instance.t('Account_and_Security'),
              child: _buildAccountContent(),
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
              title: LocalizationService.instance.t('Help_and_Support'),
              child: _buildHelpContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicContent() {
    final String clinicCode = _profile?['clinic_code'] ?? '';
    if (clinicCode.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            LocalizationService.instance.t('Have_parents_scan_this_QR_code'),
            style: AppTypography.caption(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: QrImageView(
              data: clinicCode,
              version: QrVersions.auto,
              size: 140.0,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.mintBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGreen),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.vpn_key_rounded,
                  size: 18,
                  color: AppColors.gentleGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  LocalizationService.instance.t('Or_enter_Code'),
                  style: AppTypography.caption(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  clinicCode,
                  style: AppTypography.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gentleGreenDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Share.share(
                  'Hello! I am excited to work with you on Sipsara.\n\nPlease use my secure connection code [$clinicCode] to link our accounts. If you have the app installed, you can enter the code in the Parent Hub.',
                  subject: 'Sipsara Connection Code',
                );
              },
              icon: const Icon(
                Icons.share_rounded,
                size: 20,
                color: Colors.white,
              ),
              label: Text(
                LocalizationService.instance.t('Share_invite_code'),
                style: AppTypography.button(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.calmBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountContent() {
    return Column(
      children: [
        _buildEditableRow(
          label: 'full name',
          value: _userName,
          onEdit: () => _showEditNameDialog(),
        ),
        _buildEditableRow(
          label: 'specialization',
          value: _specialization.isEmpty ? 'not set' : _specialization,
          onEdit: () => _showEditSpecializationDialog(),
        ),
        _buildEditableRow(
          label: 'clinic name',
          value: _clinicName.isEmpty ? 'not set' : _clinicName,
          onEdit: () => _showEditClinicDialog(),
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
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
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

  Widget _buildHelpContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildEditableRow(
            label: 'contact support',
            value: 'support@sipsara.app',
            editLabel: 'email',
            onEdit: () {},
          ),
        ],
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
        childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text('logout', style: AppTypography.button(fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.calmBlue,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Update Name',
                      style: AppTypography.heading(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your full name to update your profile.',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: AppTypography.caption(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
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
                        hintStyle: AppTypography.body(
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.textHint,
                        ),
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
                                  setDialogState(
                                    () => errorMessage =
                                        'Name must be at least 2 characters.',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });

                                final error = await AuthService().updateProfile(
                                  name: newName,
                                );

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
                                      content: Text(
                                        'Name updated successfully!',
                                      ),
                                      backgroundColor: AppColors.gentleGreen,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.calmBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: AppTypography.button(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
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
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                          child: const Icon(
                            Icons.mail_outline_rounded,
                            color: AppColors.calmBlue,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Update Email',
                      style: AppTypography.heading(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a new email address. We will send a verification code to confirm.',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: AppTypography.caption(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
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
                        hintStyle: AppTypography.body(
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.textHint,
                        ),
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
                                if (newEmail.isEmpty ||
                                    !newEmail.contains('@')) {
                                  setDialogState(
                                    () => errorMessage = 'Enter a valid email.',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });

                                final error = await AuthService()
                                    .requestEmailUpdate(newEmail);

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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Send Verification Code',
                                style: AppTypography.button(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Delete Account',
                style: AppTypography.heading(
                  fontSize: 22,
                  color: Colors.redAccent,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action is irreversible. All your data and student profiles will be permanently deleted.',
                    style: AppTypography.body(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To confirm, type your full name:',
                    style: AppTypography.caption(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: AppTypography.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
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
                  child: Text(
                    'Cancel',
                    style: AppTypography.body(color: AppColors.textSecondary),
                  ),
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
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Delete Permanently',
                          style: AppTypography.body(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
          'in-app notifications',
          'receive important alerts within the app.',
          _inAppNotifications,
          (v) => setState(() => _inAppNotifications = v),
        ),
      ],
    );
  }

  Widget _buildNotifToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    bool showInfo = false;
    return StatefulBuilder(
      builder: (context, setLocalState) {
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setLocalState(() => showInfo = !showInfo),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: showInfo
                            ? AppColors.calmBlue
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    activeColor: AppColors.gentleGreen,
                    activeTrackColor: AppColors.gentleGreen.withValues(
                      alpha: 0.3,
                    ),
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
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ).copyWith(height: 1.3),
                  ),
                ),
            ],
          ),
        );
      },
    );
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

  void _showEmailOtpDialog(String newEmail) {
    final controller = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.gentleGreen,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verify Email',
                      style: AppTypography.heading(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit verification code to $newEmail.',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: AppTypography.caption(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: AppTypography.body(
                        fontSize: 20,
                      ).copyWith(letterSpacing: 4),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: AppTypography.body(
                          color: AppColors.textHint,
                        ).copyWith(letterSpacing: 4),
                        filled: true,
                        fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
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
                                  setDialogState(
                                    () => errorMessage =
                                        'Enter a valid 6-digit code.',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });

                                final error = await AuthService()
                                    .verifyEmailUpdate(newEmail, otp);

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
                                      content: Text(
                                        'Email updated successfully!',
                                      ),
                                      backgroundColor: AppColors.gentleGreen,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gentleGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Verify & Update',
                                style: AppTypography.button(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditClinicDialog() {
    final controller = TextEditingController(text: _clinicName);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            color: AppColors.calmBlue,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Update Clinic Name',
                      style: AppTypography.heading(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your clinic name to update your profile.',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: AppTypography.caption(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: controller,
                      style: AppTypography.body(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Clinic Name',
                        hintStyle: AppTypography.body(
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.local_hospital_rounded,
                          color: AppColors.textHint,
                        ),
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
                                  setDialogState(
                                    () => errorMessage =
                                        'Name must be at least 2 characters.',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });

                                final error = await AuthService().updateProfile(
                                  clinicName: newName,
                                );

                                if (error != null) {
                                  setDialogState(() {
                                    isLoading = false;
                                    errorMessage = error;
                                  });
                                } else {
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  setState(() => _clinicName = newName);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Name updated successfully!',
                                      ),
                                      backgroundColor: AppColors.gentleGreen,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.calmBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: AppTypography.button(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditSpecializationDialog() {
    final controller = TextEditingController(text: _specialization);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                          child: const Icon(
                            Icons.psychology_rounded,
                            color: AppColors.calmBlue,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Update Specialization',
                      style: AppTypography.heading(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your specialization to update your profile.',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: AppTypography.caption(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: controller,
                      style: AppTypography.body(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Specialization',
                        hintStyle: AppTypography.body(
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.slateBg.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.psychology_rounded,
                          color: AppColors.textHint,
                        ),
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
                                  setDialogState(
                                    () => errorMessage =
                                        'Name must be at least 2 characters.',
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });

                                final error = await AuthService().updateProfile(
                                  specialization: newName,
                                );

                                if (error != null) {
                                  setDialogState(() {
                                    isLoading = false;
                                    errorMessage = error;
                                  });
                                } else {
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  setState(() => _specialization = newName);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Name updated successfully!',
                                      ),
                                      backgroundColor: AppColors.gentleGreen,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.calmBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: AppTypography.button(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
