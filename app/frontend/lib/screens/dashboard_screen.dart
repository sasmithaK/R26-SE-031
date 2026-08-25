import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/app_loading_indicator.dart';
import '../utils/avatar_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../models/dashboard_config.dart';
import 'level_map_screen.dart';
import 'skill_intro_screen.dart';
import 'select_student_screen.dart';
import 'parent/parent_hub_screen.dart';
import 'character_shop_screen.dart';
import 'progress_analytics_screen.dart';
import '../models/curriculum_models.dart';
import '../services/progress_service.dart';
import '../services/localization_service.dart';
import 'loading_skill_screen.dart';

/// Dashboard Screen
/// Dyslexia-accessible: crème bg, warm white skill cards, gentle green progress,
/// calm blue accents, 16pt+ text.
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;

  const DashboardScreen({super.key, this.studentData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  CurriculumIndex? _curriculum;
  int _activeNavIndex = 0; // 0: home, 1: shop, 2: progress, 3: parents
  int _streak = 0;
  DashboardConfig? _dashConfig;

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
    _fadeController.forward();

    _loadCurriculum();
    _loadStreak();
    _loadDashboardConfig();
  }

  Future<void> _loadDashboardConfig() async {
    final cfg = await DashboardConfig.load();
    if (mounted) setState(() => _dashConfig = cfg);
  }

  Future<void> _loadStreak() async {
    final streak = ProgressService().currentStreak;
    if (mounted) setState(() => _streak = streak);
  }

  Future<void> _loadCurriculum() async {
    final curr = await CurriculumIndex.load();
    if (mounted) {
      setState(() {
        _curriculum = curr;
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
    final studentName = widget.studentData?['name'] ?? 'Student';
    final avatarUrl = AvatarUtils.getCorrectedAvatarPath(widget.studentData?['avatar_url'] as String?, 'assets/images/characters/human/human_student_1.png');

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (Avatar Profile + Welcome Message)
              _buildHeader(studentName, avatarUrl),

              const SizedBox(height: 20),

              // Custom Top Navigation Bar
              _buildTopNavBar(),

              const SizedBox(height: 20),

              // Section Header: "learning path"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      '''🚀 ${LocalizationService.instance.t('learning_path')}''',
                      style: AppTypography.heading(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Skill cards list
              Expanded(
                child: _curriculum == null 
                  ? const Center(child: AppLoadingIndicator())
                  : _buildSkillsGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String avatarUrl) {
    final config = _dashConfig;
    final hour = DateTime.now().hour;
    final greeting = config != null
        ? config.greetingFor(hour, name)
        : (hour < 12 ? '''${LocalizationService.instance.t('good_morning')}, $name! ☀️''' : hour < 17 ? '''${LocalizationService.instance.t('good_afternoon')}, $name! 🌤️''' : '''${LocalizationService.instance.t('good_evening')}, $name! 🌙''');
    final subtitle = _streak > 1 ? (config?.subtitleFor(_streak) ?? '🔥 $_streak day streak! Keep going!') : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Dynamic greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTypography.heading(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.body(
                      fontSize: 14,
                      color: AppColors.softCoral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right Side: Streak badge + Avatar
          Row(
            children: [
              if (_streak > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warmAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.warmAmber.withValues(alpha: 0.4),
                        width: 1.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(
                        '$_streak',
                        style: AppTypography.heading(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.warmAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SelectStudentScreen()),
                  );
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.calmBlue, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.calmBlue.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/characters/human/human_student_1.png',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final isSelected = _activeNavIndex == index;
          final color = item['color'] as Color;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _activeNavIndex = index);
                final route = item['route'] as Widget?;
                if (route != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => route),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : AppColors.borderLight,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? color.withValues(alpha: 0.35)
                          : AppColors.shadow.withValues(alpha: 0.08),
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      item['icon'] as FaIconData,
                      size: 24,
                      color: isSelected ? Colors.white : color.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['label'] as String,
                      style: AppTypography.caption(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSkillsGrid() {
    final config = _dashConfig;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _curriculum!.skills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final skill = _curriculum!.skills[index];

        final String? prevSkillId = index > 0 ? _curriculum!.skills[index - 1].id : null;
        final int prevTotal = index > 0 ? _curriculum!.skills[index - 1].totalActivities : 0;

        final bool isUnlocked = ProgressService().isSkillUnlocked(
          index,
          skill.id,
          prevSkillId,
          prevTotal,
        );

        return _AnimatedSkillCard(
          skill: skill,
          color: skill.color,
          imagePath: skill.imagePath,
          studentData: widget.studentData,
          isLocked: !isUnlocked,
          dashConfig: config,
          onReturn: () {
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  static List<Map<String, dynamic>> get _navItems => [
    {
      'label': LocalizationService.instance.t('home'),
      'icon': FontAwesomeIcons.house,
      'color': AppColors.calmBlue,
      'route': null,
    },
    {
      'label': LocalizationService.instance.t('shop'),
      'icon': FontAwesomeIcons.store,
      'color': AppColors.softCoral,
      'route': CharacterShopScreen(),
    },
    {
      'label': LocalizationService.instance.t('progress_tab'),
      'icon': FontAwesomeIcons.trophy,
      'color': AppColors.warmAmber,
      'route': ProgressAnalyticsScreen(),
    },
    {
      'label': LocalizationService.instance.t('parents'),
      'icon': FontAwesomeIcons.userGroup,
      'color': AppColors.gentleGreen,
      'route': ParentHubScreen(),
    },
  ];
}

class _AnimatedSkillCard extends StatefulWidget {
  final SkillSummary skill;
  final Color color;
  final String imagePath;
  final Map<String, dynamic>? studentData;
  final bool isLocked;
  final DashboardConfig? dashConfig;
  final VoidCallback onReturn;

  const _AnimatedSkillCard({
    required this.skill,
    required this.color,
    required this.imagePath,
    this.studentData,
    this.isLocked = false,
    this.dashConfig,
    required this.onReturn,
  });

  @override
  State<_AnimatedSkillCard> createState() => _AnimatedSkillCardState();
}

class _AnimatedSkillCardState extends State<_AnimatedSkillCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isNavigating = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.dashConfig;
    final maxStars = cfg?.progress.maxStars ?? 5;
    final progress = ProgressService().getSkillProgress(widget.skill.id, widget.skill.totalActivities);
    final filledStars = (progress * maxStars).round();

    final cardContent = Container(
      height: 145,
      decoration: BoxDecoration(
        color: widget.isLocked
            ? AppColors.cardSurface.withValues(alpha: 0.85)
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isLocked
              ? AppColors.borderLight
              : widget.color.withValues(alpha: 0.9),
          width: widget.isLocked ? 2 : 3.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isLocked
                ? AppColors.shadow.withValues(alpha: 0.08)
                : widget.color.withValues(alpha: 0.22),
            blurRadius: widget.isLocked ? 8 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Hero image (120px wide) with greyscale lock filter when locked
          SizedBox(
            width: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(20)),
                  child: ColorFiltered(
                    colorFilter: widget.isLocked
                        ? const ColorFilter.matrix([
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0, 0, 0, 1, 0,
                          ])
                        : const ColorFilter.mode(
                            Colors.transparent, BlendMode.multiply),
                    child: Image.asset(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: widget.color.withValues(alpha: 0.1),
                        child: Icon(Icons.auto_awesome_rounded,
                            color: widget.color, size: 48),
                      ),
                    ),
                  ),
                ),

                // Lock Overlay when locked
                if (widget.isLocked)
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20)),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.28),
                      child: const Center(
                        child: Icon(Icons.lock_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Right Content Area: Title, audio button, big stars & Play/Try button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title + Audio speaker button row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.skill.title,
                          style: AppTypography.heading(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: widget.isLocked
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          final url = widget.skill.audioUrl;
                          if (url.isNotEmpty) {
                            try {
                              await _audioPlayer.stop();
                              if (url.startsWith('http://') || url.startsWith('https://')) {
                                await _audioPlayer.play(UrlSource(url));
                              } else {
                                final cleanPath = url.replaceFirst('assets/', '');
                                await _audioPlayer.play(AssetSource(cleanPath));
                              }
                            } catch (e) {
                              debugPrint('Error playing custom skill audio: $e');
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.volume_up_rounded,
                            color: widget.color,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom Action Row: FittedBox with mainAxisSize: MainAxisSize.min prevents right overflow on narrow screens
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Stars Row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            maxStars,
                            (i) => Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                i < filledStars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: i < filledStars
                                    ? AppColors.warmAmber
                                    : AppColors.borderLight,
                                size: 20,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Chunky 3D Play / Try Button
                        if (!widget.isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.color,
                                  widget.color.withValues(alpha: 0.85),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 3),
                                Text(
                                  'Play',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warmAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.warmAmber, width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_open_rounded,
                                    color: AppColors.warmAmber, size: 15),
                                const SizedBox(width: 3),
                                Text(
                                  'Try',
                                  style: AppTypography.heading(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.warmAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
        onTap: () async {
          if (_isNavigating) return;
          if (mounted) setState(() => _isNavigating = true);
          try {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LoadingSkillScreen(
                  skill: widget.skill,
                  studentData: widget.studentData,
                  onReturn: widget.onReturn,
                ),
              ),
            );
            if (!mounted) return;
            widget.onReturn();
          } catch (e) {
            debugPrint('Error navigating to loading skill screen: $e');
          } finally {
            if (mounted) setState(() => _isNavigating = false);
          }
        },
        child: cardContent,
    );
  }
}
