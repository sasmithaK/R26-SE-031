import 'package:flutter/material.dart';
import '../utils/avatar_utils.dart';
import '../../theme/app_theme.dart';
import 'consent_screen.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../services/localization_service.dart';
import 'parent_account_screen.dart';

/// Add Student Screen
/// Dyslexia-accessible: crème bg, warm white form, calm blue border,
/// gentle green avatar selection, sentence case text.
class AddStudentScreen extends StatefulWidget {
  final Map<String, dynamic>? editStudentData;

  const AddStudentScreen({super.key, this.editStudentData});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedGrade = 'Grade 1';
  String? _selectedDailyLimit = 'No Limit';
  String _selectedAvatarUrl = 'assets/images/characters/mascots/solo_blue.png';
  bool _isHumanCategory = false;
  
  bool _hasNudgedFantasy = false;
  bool _hasNudgedKids = false;

  final List<String> _humanAvatars = [
    'assets/images/characters/human/human_student_1.png',
    'assets/images/characters/human/human_student_2.png',
    'assets/images/characters/human/human_student_3.png',
    'assets/images/characters/human/human_student_4.png',
    'assets/images/characters/human/human_student_5.png',
    'assets/images/characters/human/human_student_6.png',
  ];

  final List<String> _monsterAvatars = [
    'assets/images/characters/mascots/solo_blue.png',
    'assets/images/characters/mascots/solo_green.png',
    'assets/images/characters/mascots/solo_pink.png',
    'assets/images/characters/mascots/solo_teal.png',
    'assets/images/characters/mascots/solo_orange.png',
    'assets/images/characters/mascots/solo_pink_up.png',
  ];

  final List<String> _limits = [
    'No Limit',
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
    '1.5 hours',
    '2 hours',
  ];

  bool _isLoading = false;
  bool _isGoogleUser = false;
  final ScrollController _avatarScrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    if (widget.editStudentData != null) {
      _firstNameController.text = widget.editStudentData!['first_name'] ?? '';
      _lastNameController.text = widget.editStudentData!['last_name'] ?? '';
      _selectedGrade = widget.editStudentData!['grade'];
      _selectedDailyLimit =
          widget.editStudentData!['daily_limit'] ?? 'No Limit';
      _selectedAvatarUrl =
          AvatarUtils.getCorrectedAvatarPath(widget.editStudentData!['avatar_url'] as String?, 'assets/images/characters/mascots/solo_blue.png');
      _isHumanCategory = _humanAvatars.contains(_selectedAvatarUrl);
    }

    _checkGoogleUser();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_avatarScrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          if (_isHumanCategory) {
            _hasNudgedKids = true;
          } else {
            _hasNudgedFantasy = true;
          }
          _performNudge();
        });
      }
    });
  }

  void _performNudge() {
    if (!_avatarScrollController.hasClients) return;
    _avatarScrollController.animateTo(
      120.0, 
      duration: const Duration(milliseconds: 600), 
      curve: Curves.easeOutSine,
    ).then((_) {
      if (!mounted) return;
      _avatarScrollController.animateTo(
        0.0, 
        duration: const Duration(milliseconds: 600), 
        curve: Curves.easeInSine,
      );
    });
  }

  Future<void> _checkGoogleUser() async {
    final provider = await AuthService().getAuthProvider();
    if (mounted) {
      setState(() {
        _isGoogleUser = provider == 'google';
      });
    }
  }

  void _switchCategory(bool isHuman) {
    if (_isHumanCategory == isHuman) return;
    setState(() => _isHumanCategory = isHuman);
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (isHuman && !_hasNudgedKids) {
        _hasNudgedKids = true;
        _performNudge();
      } else if (!isHuman && !_hasNudgedFantasy) {
        _hasNudgedFantasy = true;
        _performNudge();
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getDisplayLimit(String limit) {
    if (limit == 'No Limit') return LocalizationService.instance.t('no_limit');
    final parts = limit.split(' ');
    if (parts.length == 2) {
      if (parts[1] == 'minutes') return '${parts[0]} ${LocalizationService.instance.t('minutes')}';
      if (parts[1] == 'hour' || parts[1] == 'hours') return '${parts[0]} ${LocalizationService.instance.t(parts[1])}';
    }
    return limit;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.editStudentData == null) ...[
                        Text(
                          LocalizationService.instance.t('add_student_desc'),
                          style: AppTypography.body(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Text(
                        LocalizationService.instance.t('choose_avatar'),
                        style: AppTypography.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.mintBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.gentleGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchCategory(false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: !_isHumanCategory ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: !_isHumanCategory ? [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                                    ] : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(LocalizationService.instance.t('fantasy'), style: AppTypography.button(fontSize: 14, color: !_isHumanCategory ? AppColors.textPrimary : AppColors.textHint)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchCategory(true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: _isHumanCategory ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: _isHumanCategory ? [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                                    ] : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(LocalizationService.instance.t('kids'), style: AppTypography.button(fontSize: 14, color: _isHumanCategory ? AppColors.textPrimary : AppColors.textHint)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.3, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: SingleChildScrollView(
                          key: ValueKey<bool>(_isHumanCategory),
                          controller: _avatarScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: (_isHumanCategory ? _humanAvatars : _monsterAvatars).map((url) {
                              final isSelected = _selectedAvatarUrl == url;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedAvatarUrl = url),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 16),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.gentleGreen
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 36,
                                    backgroundColor: AppColors.cardSurface,
                                    backgroundImage: AssetImage(url),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Fields Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.borderBlue,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _firstNameController,
                              decoration: InputDecoration(
                                hintText: LocalizationService.instance.t('student_first_name_hint'),
                              ),
                              style: AppTypography.body(fontSize: 16),
                              validator: (val) => val == null || val.isEmpty
                                  ? LocalizationService.instance.t('required_field')
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _lastNameController,
                              decoration: InputDecoration(
                                hintText: LocalizationService.instance.t('student_last_name_hint'),
                              ),
                              style: AppTypography.body(fontSize: 16),
                              validator: (val) => val == null || val.isEmpty
                                  ? LocalizationService.instance.t('required_field')
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Grade — locked to Grade 1
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mintBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.gentleGreen.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    color: AppColors.gentleGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    LocalizationService.instance.t('grade_1'),
                                    style: AppTypography.body(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gentleGreen.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      LocalizationService.instance.t('auto_set'),
                                      style: AppTypography.caption(
                                        fontSize: 12,
                                        color: AppColors.gentleGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: _selectedDailyLimit,
                              decoration: const InputDecoration(),
                              dropdownColor: AppColors.cardSurface,
                              style: AppTypography.body(fontSize: 16),
                              items: _limits.map((limit) {
                                return DropdownMenuItem(
                                  value: limit,
                                  child: Text('${LocalizationService.instance.t("daily_limit_prefix")}${_getDisplayLimit(limit)}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedDailyLimit = val);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Save Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate() &&
                                      _selectedGrade != null) {
                                    final studentData = {
                                      'first_name': _firstNameController.text
                                          .trim(),
                                      'last_name': _lastNameController.text
                                          .trim(),
                                      'grade': _selectedGrade,
                                      'daily_limit': _selectedDailyLimit,
                                      'avatar_url': _selectedAvatarUrl,
                                    };

                                      if (widget.editStudentData == null) {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ConsentScreen(
                                              studentData: studentData,
                                            ),
                                          ),
                                        );
                                        if (result == true && mounted) {
                                          Navigator.pop(context);
                                        }
                                      } else {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      final error = await StudentService()
                                          .updateStudent(
                                            widget.editStudentData!['id'],
                                            studentData,
                                          );
                                      if (!mounted) return;
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      if (error != null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(error),
                                            backgroundColor:
                                                AppColors.softCoral,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              LocalizationService.instance.t('student_updated_success'),
                                            ),
                                            backgroundColor:
                                                AppColors.gentleGreen,
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
                                    }
                                  } else if (_selectedGrade == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LocalizationService.instance.t('grade_set_info'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.calmBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.editStudentData == null
                                      ? LocalizationService.instance.t('save_changes')
                                      : LocalizationService.instance.t('update_changes'),
                                  style: AppTypography.button(fontSize: 18),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
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
          const SizedBox(width: 16),
          Text(
            widget.editStudentData == null ? LocalizationService.instance.t('add_student') : LocalizationService.instance.t('edit_student'),
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
}
