import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/parent_dashboard_service.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/trend_chart.dart';
import '../../models/curriculum_models.dart';
import '../games/game_factory.dart';

class ChildProgressScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const ChildProgressScreen({super.key, required this.studentData});

  @override
  State<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends State<ChildProgressScreen> {
  final ParentDashboardService _dashboardService = ParentDashboardService();
  bool _isLoading = true;
  
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _skills;
  Map<String, dynamic>? _learningPattern;
  Map<String, dynamic>? _activityHistory;
  Map<String, dynamic>? _adaptiveInsights;
  String _currentFilter = "limit=10";

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final studentId = widget.studentData['id']?.toString() ?? widget.studentData['_id']?.toString();
    if (studentId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final responses = await Future.wait([
      _dashboardService.getOverview(studentId),
      _dashboardService.getSkills(studentId),
      _dashboardService.getLearningPattern(studentId),
      _dashboardService.getActivityHistory(studentId, _currentFilter),
      _dashboardService.getAdaptiveInsights(studentId),
    ]);

    setState(() {
      _overview = responses[0];
      _skills = responses[1];
      _learningPattern = responses[2];
      _activityHistory = responses[3];
      _adaptiveInsights = responses[4];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.studentData['first_name'] ?? 'student';
    final grade = widget.studentData['grade'] ?? 'Grade 1';
    final avatar = AvatarUtils.getCorrectedAvatarPath(
        widget.studentData['avatar_url'] as String?, 
        'assets/images/characters/human/human_student_1.png');

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: DropdownButton<String>(
                value: _currentFilter,
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_list, color: AppColors.calmBlue),
                style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _currentFilter) {
                    setState(() {
                      _currentFilter = newValue;
                      _isLoading = true;
                    });
                    _loadAllData();
                  }
                },
                items: const [
                  DropdownMenuItem(value: "limit=5", child: Text("Last 5 Interactions")),
                  DropdownMenuItem(value: "limit=10", child: Text("Last 10 Interactions")),
                  DropdownMenuItem(value: "limit=20", child: Text("Last 20 Interactions")),
                  DropdownMenuItem(value: "days=7", child: Text("Last 7 Days")),
                  DropdownMenuItem(value: "days=30", child: Text("Last 30 Days")),
                ],
              ),
            ),
          ],
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: AssetImage(avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$name - $grade',
                  style: AppTypography.heading(fontSize: 18, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.calmBlue,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.calmBlue,
            tabs: [
              Tab(text: "Overview"),
              Tab(text: "Reading Progress"),
              Tab(text: "Reading Pattern"),
              Tab(text: "Activity History"),
              Tab(text: "Adaptive Insights"),
              Tab(text: "Reports"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : TabBarView(
                children: [
                  _buildOverviewTab(),
                  _buildReadingProgressTab(),
                  _buildReadingPatternTab(),
                  _buildActivityHistoryTab(),
                  _buildAdaptiveInsightsTab(),
                  _buildReportsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    // 4 KPI Cards
    // Reading Accuracy: 78%
    // Reading Practice: 18 min
    // Reading Sessions: 6
    // Reading Progress: Developing
    
    final accuracy = _overview?['accuracy'] ?? 0;
    final practice = _overview?['practice_time_minutes'] ?? 0;
    final sessions = _overview?['sessions_completed'] ?? 0;
    final progress = _overview?['reading_progress'] ?? "Developing";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Summary", style: AppTypography.heading(fontSize: 20)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard("Reading Accuracy", "$accuracy%", Icons.track_changes_rounded, AppColors.gentleGreen),
              _buildStatCard("Reading Practice", "$practice min", Icons.schedule_rounded, AppColors.calmBlue),
              _buildStatCard("Reading Sessions", "$sessions", Icons.videogame_asset_rounded, AppColors.softCoral),
              _buildStatCard("Reading Progress", progress, Icons.trending_up_rounded, AppColors.warmAmber),
            ],
          ),
          const SizedBox(height: 24),
          
          Text("Fluency Status", style: AppTypography.heading(fontSize: 20)),
          const SizedBox(height: 16),
          _buildFluencyCard(),
        ],
      ),
    );
  }

  Widget _buildFluencyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Reading Fluency", style: AppTypography.heading(fontSize: 18, color: AppColors.textPrimary)),
              Text(_overview?['reading_progress'] ?? "Developing", style: AppTypography.heading(fontSize: 16, color: AppColors.calmBlue)),
            ],
          ),
          const SizedBox(height: 12),
          // Simple visual progress bar approximation (70% full)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 0.7,
              minHeight: 12,
              backgroundColor: AppColors.borderLight,
              color: AppColors.calmBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "* System-derived reading performance indicator (not a clinically validated score).",
            style: AppTypography.caption(fontSize: 11, color: AppColors.textSecondary),
          )
        ],
      ),
    );
  }

  Widget _buildReadingProgressTab() {
    List<dynamic> trendRaw = _overview?['accuracy_trend'] ?? [];
    List<double> trendData = trendRaw.isNotEmpty ? trendRaw.map((e) => (e['accuracy'] as num).toDouble()).toList() : [0.0];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Accuracy Over Time", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 16),
          TrendChart(
            title: "Reading Accuracy (%)",
            dataPoints: trendData,
            lineColor: AppColors.calmBlue,
            minY: 0,
            maxY: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildReadingPatternTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Observation", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gentleGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights_rounded, color: AppColors.gentleGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _learningPattern?['observation'] ?? "Your child is showing steady reading development.",
                    style: AppTypography.body(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("Recommended Practice", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          ...(_learningPattern?['recommended_practices'] as List<dynamic>? ?? []).map((p) => _buildRecommendationTile(p.toString())),
        ],
      ),
    );
  }

  Widget _buildRecommendationTile(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.warmAmber),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTypography.body())),
        ],
      ),
    );
  }

  Widget _buildActivityHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Recent Reading Activity", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.calmBlue.withValues(alpha: 0.05)),
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Text('Aug 30')),
                  DataCell(Text('පෙළපොතෙන් කියවමු - 1')),
                  DataCell(Text('80%')),
                  DataCell(Text('5 min')),
                ]),
                DataRow(cells: [
                  DataCell(Text('Aug 29')),
                  DataCell(Text('කවුද?')),
                  DataCell(Text('75%')),
                  DataCell(Text('4 min')),
                ]),
                DataRow(cells: [
                  DataCell(Text('Aug 28')),
                  DataCell(Text('මොනවාද?')),
                  DataCell(Text('85%')),
                  DataCell(Text('4 min')),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 64, color: AppColors.softCoral),
          const SizedBox(height: 24),
          Text("Download Official Report", style: AppTypography.heading(fontSize: 20)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "Report includes reading progress, accuracy trend, practice time, fluency status, and simple observations.",
              textAlign: TextAlign.center,
              style: AppTypography.caption(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Implementation to download report from /api/v1/parent/students/{id}/report
            },
            icon: const Icon(Icons.download),
            label: const Text("Download PDF"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.calmBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.heading(fontSize: 18, color: AppColors.textPrimary)),
          Text(label, style: AppTypography.caption(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── Adaptive Insights Tab (Skill 2) ───
  Widget _buildAdaptiveInsightsTab() {
    final activities = (_adaptiveInsights?['activities'] as List<dynamic>?) ?? [];

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 64, color: AppColors.calmBlue.withValues(alpha: 0.4)),
              const SizedBox(height: 20),
              Text(
                "No adaptive learning data yet",
                style: AppTypography.heading(fontSize: 18, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                "Once your child completes Skill 2 activities, personalised insights will appear here.",
                textAlign: TextAlign.center,
                style: AppTypography.caption(fontSize: 14, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppColors.calmBlue, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Adaptive Learning Insights",
                    style: AppTypography.heading(fontSize: 20, color: AppColors.calmBlue)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "How the app personalised learning for your child.",
            style: AppTypography.caption(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Activity Cards
          ...activities.map((act) => _buildInsightCard(act as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> act) {
    final activityName = act['activity_name'] ?? 'Activity';
    final roundsCompleted = (act['rounds_completed'] ?? 0) as int;
    final roundsTotal = (act['rounds_total'] ?? 5) as int;
    final isComplete = act['is_activity_complete'] == true;
    final completionText = act['completion_text'] ?? '';
    final accuracyText = act['accuracy_text'] ?? '';
    final adaptationText = act['adaptation_text'] ?? '';
    final independenceText = act['independence_text'] ?? '';
    final independenceBadge = act['independence_badge'] ?? '';
    final roundJourney = (act['round_journey'] as List<dynamic>?) ?? [];
    final starRating = (act['star_rating'] ?? 1) as int;
    final ratingText = act['rating_text'] ?? '';
    final timesPlayed = (act['times_played'] ?? 0) as int;
    final lastPlayed = act['last_played'] ?? '';
    final recommendations = (act['recommendations'] as List<dynamic>?) ?? [];

    // Card accent color based on completion
    Color accentColor = isComplete
        ? AppColors.gentleGreen
        : (roundsCompleted > 0 ? AppColors.warmAmber : AppColors.softCoral);

    // Format last played date
    String formattedDate = '';
    if (lastPlayed.isNotEmpty) {
      try {
        final dt = DateTime.parse(lastPlayed);
        formattedDate = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {
        formattedDate = lastPlayed;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Activity Name + Star Rating + Plays ───
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activityName,
                          style: AppTypography.heading(fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(ratingText,
                          style: AppTypography.caption(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor)),
                    ],
                  ),
                ),
                // Plays badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.calmBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$timesPlayed rounds',
                    style: AppTypography.caption(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.calmBlue),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. Completion Progress (Step Bar) ───
                Row(
                  children: [
                    Icon(
                      isComplete ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(completionText,
                          style: AppTypography.caption(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Step dots
                Row(
                  children: List.generate(roundsTotal, (i) {
                    final completed = i < roundsCompleted;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 8,
                        decoration: BoxDecoration(
                          color: completed ? accentColor : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // ─── 2 & 3. Accuracy + Adaptation (2 info rows) ───
                _buildInfoRow(Icons.star_rounded, accuracyText, AppColors.warmAmber),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.tune_rounded, adaptationText, AppColors.calmBlue),
                const SizedBox(height: 8),

                // ─── 4. Independence Badge ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.calmBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, size: 18, color: AppColors.calmBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(independenceBadge,
                                style: AppTypography.caption(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.calmBlue)),
                            Text(independenceText,
                                style: AppTypography.caption(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── 5. Round Journey Timeline ───
                if (roundJourney.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text("Round-by-Round Journey",
                      style: AppTypography.caption(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...roundJourney.map((r) {
                    final round = r as Map<String, dynamic>;
                    final rn = round['round_number'] ?? 0;
                    final icon = round['result_icon'] ?? '👍';
                    final text = round['result_text'] ?? '';
                    final neededRem = round['needed_remediation'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          // Round circle
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: neededRem
                                  ? AppColors.warmAmber.withValues(alpha: 0.15)
                                  : AppColors.gentleGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('$rn',
                                  style: AppTypography.caption(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: neededRem ? AppColors.warmAmber : AppColors.gentleGreen)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(text,
                                style: AppTypography.caption(fontSize: 12, color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // ─── 7. Recommended Practice ───
                if (recommendations.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: AppColors.warmAmber),
                      const SizedBox(width: 6),
                      Text("Recommended Practice",
                          style: AppTypography.caption(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warmAmber)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...recommendations.map((rec) {
                    final r = rec as Map<String, dynamic>;
                    return _buildRecommendationCard(r);
                  }),
                ] else if (roundJourney.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gentleGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text("🎉", style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text("Great work! No extra practice needed.",
                              style: AppTypography.caption(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gentleGreen)),
                        ),
                      ],
                    ),
                  ),
                ],

                // ─── Footer: Last Played ───
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text('Last played: $formattedDate',
                          style: AppTypography.caption(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: AppTypography.caption(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    final activityName = rec['activity_name'] ?? 'Activity';
    final description = rec['description'] ?? '';
    final roundsCount = rec['rounds_count'] ?? 5;

    return GestureDetector(
      onTap: () => _navigateToRecommendedActivity(rec),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.calmBlue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.calmBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.extension_rounded, size: 20, color: AppColors.calmBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activityName,
                      style: AppTypography.caption(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: AppTypography.caption(fontSize: 11, color: AppColors.textSecondary)),
                  Text('Same difficulty · $roundsCount puzzles',
                      style: AppTypography.caption(fontSize: 10, color: AppColors.textHint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.calmBlue),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToRecommendedActivity(Map<String, dynamic> rec) async {
    final activityId = rec['activity_id'] ?? '';
    final templateType = rec['template_type'] ?? '';

    if (activityId.isEmpty || templateType.isEmpty) return;

    try {
      // Load the skill_2 curriculum JSON
      final String jsonStr = await rootBundle.loadString('assets/data/curriculum/skill_2.json');
      final decoded = json.decode(jsonStr);

      // Parse the skill detail
      final skillDetail = SkillDetail.fromJson(decoded, 'skill_2', 'Skill 2');

      // Find the matching activity by template_type
      ActivityNode? targetActivity;
      for (final act in skillDetail.activities) {
        if (act.templateType == templateType) {
          targetActivity = act;
          break;
        }
      }

      if (targetActivity == null) return;

      // Set skill metadata
      targetActivity.skillId = 'skill_2';
      targetActivity.skillTitle = skillDetail.title;

      if (!mounted) return;

      // Navigate to the game screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameFactory.buildGame(
            targetActivity!,
            studentData: widget.studentData,
          ),
        ),
      ).then((_) {
        // Refresh insights after returning from the activity
        _loadAllData();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open activity: $e')),
        );
      }
    }
  }
}
