import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../utils/avatar_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/student_service.dart';
import 'skill_detail_progress_screen.dart';
import '../therapist/therapist_student_detail_screen.dart';
import '../../services/localization_service.dart';
/// Child Progress Screen — Visual dashboard showing a specific child's
/// learning journey: weekly activity chart, overall stats, skill progress.
class ChildProgressScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const ChildProgressScreen({super.key, required this.studentData});

  @override
  State<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends State<ChildProgressScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  List<double> _weeklyMinutes = [0, 0, 0, 0, 0, 0, 0];
  List<Map<String, dynamic>> _skills = [];
  int _totalActivities = 0;
  int _overallAccuracy = 0;
  int _dayStreak = 0;
  int _totalStars = 0;

  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
    _loadTelemetryData();
  }
  
  Future<void> _loadTelemetryData() async {
    final studentId = widget.studentData['id'] ?? widget.studentData['_id'];
    if (studentId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final sessions = await StudentService().getTelemetry(studentId.toString());
    
    _processTelemetryData(sessions);
    setState(() {
      _isLoading = false;
    });
  }

  void _processTelemetryData(List<dynamic> sessions) {
    // 1. Calculate Weekly Minutes (Monday - Sunday)
    final now = DateTime.now();
    final List<double> weeklyMins = List.filled(7, 0.0);
    
    final Map<String, List<dynamic>> activityEvents = {};
    int totalActs = 0;
    int totalScoreSum = 0;
    int earnedStars = 0;
    Set<String> activeDates = {};

    for (final session in sessions) {
      final submittedAtStr = session['submitted_at'] as String?;
      if (submittedAtStr != null) {
        final submittedAt = DateTime.tryParse(submittedAtStr);
        if (submittedAt != null) {
          final diff = now.difference(submittedAt).inDays;
          if (diff < 7) {
            final dayIndex = submittedAt.weekday - 1; 
            final durationSecs = session['session_duration_seconds'] as int? ?? 0;
            weeklyMins[dayIndex] += (durationSecs / 60.0);
          }
          // Store date string for streak calculation (YYYY-MM-DD)
          activeDates.add("${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')}");
        }
      }

      final events = session['events'] as List<dynamic>? ?? [];
      for (final ev in events) {
        final activityName = ev['activity_name'] as String? ?? 'Unknown';
        final score = ev['score'] as int? ?? 0;
        
        if (!activityEvents.containsKey(activityName)) {
          activityEvents[activityName] = [];
        }
        activityEvents[activityName]!.add(ev);
        
        totalActs++;
        totalScoreSum += score;
        if (score >= 80) earnedStars += 3;
        else if (score >= 50) earnedStars += 2;
        else earnedStars += 1;
      }
    }

    // Calculate Streak
    int currentStreak = 0;
    DateTime checkDate = now;
    // Check if they played today or yesterday to start the streak
    String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String yesterdayStr = "${now.subtract(const Duration(days: 1)).year}-${now.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}-${now.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}";
    
    if (activeDates.contains(todayStr) || activeDates.contains(yesterdayStr)) {
      if (activeDates.contains(todayStr)) {
        checkDate = now;
      } else {
        checkDate = now.subtract(const Duration(days: 1));
      }
      
      while (true) {
        String dStr = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
        if (activeDates.contains(dStr)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    _weeklyMinutes = weeklyMins;
    _totalActivities = totalActs;
    _overallAccuracy = totalActs > 0 ? (totalScoreSum / totalActs).round() : 0;
    _dayStreak = currentStreak;
    _totalStars = earnedStars;

    _skills = activityEvents.entries.map((entry) {
      final name = entry.key;
      final evts = entry.value;
      final scores = evts.map((e) => e['score'] as int? ?? 0).toList();
      final avgScore = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
      
      // Determine an icon and color based on name (mocking styling for dynamic names)
      dynamic icon = FontAwesomeIcons.gamepad;
      Color color = AppColors.calmBlue;
      if (name.contains('visual') || name.contains('picture')) {
        icon = FontAwesomeIcons.eye;
        color = AppColors.softCoral;
      } else if (name.contains('sound') || name.contains('audio')) {
        icon = FontAwesomeIcons.volumeHigh;
        color = AppColors.gentleGreen;
      } else if (name.contains('word') || name.contains('letter')) {
        icon = FontAwesomeIcons.font;
        color = AppColors.warmAmber;
      }

      return {
        'name': name.replaceAll('_', ' ').toUpperCase(),
        'icon': icon,
        'color': color,
        'progress': (avgScore / 100.0).clamp(0.0, 1.0),
        'accuracy': avgScore.round(),
        'levels': evts.length,
        'lastPlayed': 'recent',
        'events': evts,
      };
    }).toList();

    // Fallback if no telemetry yet
    if (_skills.isEmpty) {
      _skills = [
         {
          'name': 'no_activities_played',
          'icon': FontAwesomeIcons.ghost,
          'color': AppColors.borderLight,
          'progress': 0.0,
          'accuracy': 0,
          'levels': 0,
          'lastPlayed': 'never',
        }
      ];
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.studentData['first_name'] ?? 'student';
    String rawGrade = widget.studentData['grade'] ?? 'n/a';
    if (rawGrade.toLowerCase().contains('grade 1')) {
      rawGrade = LocalizationService.instance.t('grade_1');
    }
    final grade = rawGrade;
    final avatar =
        AvatarUtils.getCorrectedAvatarPath(widget.studentData['avatar_url'] as String?, 'assets/images/characters/human/human_student_1.png');

    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.cream,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: AppLoadingIndicator())
            : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(name, grade, avatar),
                const SizedBox(height: 24),
                _buildOverallStats(),
                const SizedBox(height: 24),
                _buildWeeklyChart(),
                const SizedBox(height: 24),
                _buildSkillProgressSection(),
                const SizedBox(height: 32),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TherapistStudentDetailScreen(student: widget.studentData),
                          ),
                        );
                      },
                      icon: const Icon(Icons.analytics_rounded, color: Colors.white),
                      label: Text(
                        LocalizationService.instance.t('view_advanced_reports'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.calmBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  });
  }

  // ─── Header ───
  Widget _buildHeader(String name, String grade, String avatar) {
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
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          // Child avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.calmBlue, width: 2),
            ),
            child: ClipOval(
              child: Image.asset(avatar, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          // Name and grade
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.instance.t('progress_report'),
                  style: AppTypography.heading(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  grade,
                  style: AppTypography.caption(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Overall Stats ───
  Widget _buildOverallStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildMiniStat(FontAwesomeIcons.gamepad, '$_totalActivities', LocalizationService.instance.t('activities'),
              AppColors.calmBlue),
          const SizedBox(width: 10),
          _buildMiniStat(FontAwesomeIcons.bullseye, '$_overallAccuracy%', LocalizationService.instance.t('accuracy'),
              AppColors.gentleGreen),
          const SizedBox(width: 10),
          _buildMiniStat(FontAwesomeIcons.fire, '$_dayStreak', LocalizationService.instance.t('day_streak'),
              AppColors.warmAmber),
          const SizedBox(width: 10),
          _buildMiniStat(FontAwesomeIcons.star, '$_totalStars', LocalizationService.instance.t('stars_earned'),
              AppColors.softCoral),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      dynamic icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.heading(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Weekly Activity Chart ───
  Widget _buildWeeklyChart() {
    final maxMinutes =
        _weeklyMinutes.reduce((a, b) => a > b ? a : b).clamp(1, 999);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocalizationService.instance.t('weekly_activity'),
                  style: AppTypography.heading(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gentleGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_weeklyMinutes.reduce((a, b) => a + b).round()} ${LocalizationService.instance.t('minutes')}',
                    style: AppTypography.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gentleGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final height =
                      (_weeklyMinutes[index] / maxMinutes) * 110;
                  final isToday = index == DateTime.now().weekday - 1;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${_weeklyMinutes[index].round()}m',
                            style: AppTypography.caption(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? AppColors.calmBlue
                                  : AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            height: max(height, 4),
                            decoration: BoxDecoration(
                              gradient: isToday
                                  ? AppColors.blueButtonGradient
                                  : LinearGradient(
                                      colors: [
                                        AppColors.borderLight,
                                        AppColors.calmBlue
                                            .withValues(alpha: 0.3),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _dayLabels[index],
                            style: AppTypography.caption(
                              fontSize: 12,
                              fontWeight: isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isToday
                                  ? AppColors.calmBlue
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Skill Progress Section ───
  Widget _buildSkillProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationService.instance.t('recent_skills'),
            style: AppTypography.heading(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.calmBlue,
            ),
          ),
          const SizedBox(height: 16),
          ..._skills.map((skill) => _buildSkillRow(skill)),
        ],
      ),
    );
  }

  Widget _buildSkillRow(Map<String, dynamic> skill) {
    final color = skill['color'] as Color;
    final progress = skill['progress'] as double;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkillDetailProgressScreen(
              skillName: skill['name'] as String,
              skillColor: color,
              skillIcon: skill['icon'] as dynamic,
              studentData: widget.studentData,
              events: skill['events'] ?? [],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Skill icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: FaIcon(skill['icon'] as dynamic,
                    size: 20, color: color),
              ),
            ),
            const SizedBox(width: 14),
            // Skill info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        skill['name'] == 'no_activities_played'
                            ? LocalizationService.instance.t('no_activities_played')
                            : LocalizationService.instance.t((skill['name'] as String).toLowerCase().replaceAll(' ', '_')),
                        style: AppTypography.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${skill['accuracy']}%',
                        style: AppTypography.caption(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.borderLight,
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${LocalizationService.instance.t('levels')}: ${skill['levels']}',
                        style: AppTypography.caption(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                      Text(
                        '${LocalizationService.instance.t('last_active_prefix')}${LocalizationService.instance.t(skill['lastPlayed'] as String)}',
                        style: AppTypography.caption(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow
            FaIcon(FontAwesomeIcons.chevronRight,
                size: 12, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
