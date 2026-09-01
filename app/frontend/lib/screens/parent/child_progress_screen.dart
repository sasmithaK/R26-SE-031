import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/parent_dashboard_service.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/research_evidence_panel.dart';

class ChildProgressScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const ChildProgressScreen({super.key, required this.studentData});

  @override
  State<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends State<ChildProgressScreen> {
  final ParentDashboardService _dashboardService = ParentDashboardService();
  bool _isLoading = true;
  Map<String, dynamic>? _evidence;
  Map<String, dynamic>? _progress;
  
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _skills;
  Map<String, dynamic>? _learningPattern;
  Map<String, dynamic>? _activityHistory;
  String _currentFilter = "limit=10";

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    final studentId = widget.studentData['student_id']?.toString() ?? widget.studentData['id']?.toString() ?? widget.studentData['_id']?.toString();
    Future<Map<String, dynamic>> capture(Future<Map<String, dynamic>> request) async {
      try { return await request; } catch (e) { return {'_error': e.toString()}; }
    }
    final responses = studentId == null || studentId.isEmpty
        ? List.generate(6, (_) => <String, dynamic>{'_error': 'Invalid student ID'})
        : await Future.wait([
            capture(_dashboardService.getOverview(studentId)),
            capture(_dashboardService.getSkills(studentId)),
            capture(_dashboardService.getLearningPattern(studentId)),
            capture(_dashboardService.getActivityHistory(studentId, _currentFilter)),
            capture(_dashboardService.getProgress(studentId)),
            capture(_dashboardService.getResearchEvidence(studentId)),
          ]);
    if (!mounted) return;
    setState(() {
      _overview = responses[0];
      _skills = responses[1];
      _learningPattern = responses[2];
      _activityHistory = responses[3];
      _progress = responses[4];
      _evidence = responses[5];
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
      length: 5,
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
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.calmBlue),
              tooltip: 'Reload latest data',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing dashboard data...'), duration: Duration(seconds: 1)),
                );
                _loadAllData();
              },
            ),
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
              Tab(text: "Reports"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                color: AppColors.calmBlue,
                child: TabBarView(
                  children: [
                  DashboardSection(data: _overview, onRetry: _loadAllData, child: _buildOverviewTab()),
                  DashboardSection(data: _progress, onRetry: _loadAllData, child: _buildReadingProgressTab()),
                  DashboardSection(data: _learningPattern, onRetry: _loadAllData, child: _buildReadingPatternTab()),
                  DashboardSection(data: _activityHistory, onRetry: _loadAllData, child: _buildActivityHistoryTab()),
                  _buildReportsTab(),
                ],
              ),
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
    
    final accuracy = _overview?['accuracy'];
    final practice = _overview?['practice_time_minutes'];
    final sessions = _overview?['sessions_completed'] ?? 0;
    final progress = _overview?['reading_progress'] ?? "Developing";
    final assessment = Map<String, dynamic>.from(_overview?['assessment_summary'] ?? {});

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
              _buildStatCard("First-attempt accuracy", metricText(accuracy, suffix: '%', decimals: 0), Icons.track_changes_rounded, AppColors.gentleGreen),
              _buildStatCard("Reading Practice", metricText(practice, suffix: ' min', decimals: 0), Icons.schedule_rounded, AppColors.calmBlue),
              _buildStatCard("Reading Sessions", "$sessions", Icons.videogame_asset_rounded, AppColors.softCoral),
              _buildStatCard("Reading Progress", progress, Icons.trending_up_rounded, AppColors.warmAmber),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.calmBlue.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Parent Assessment Summary', style: AppTypography.heading(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Completed categories: ${assessment['completed_categories'] ?? 0}/${assessment['total_categories'] ?? 4}'),
              Text('Reported observations: ${assessment['reported_observations'] ?? 0}'),
              const SizedBox(height: 6),
              const Text('This is a parent observation summary for discussion with the therapist; it is not a diagnosis.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 24),
          
          Text("Interpretation Limits", style: AppTypography.heading(fontSize: 20)),
          const SizedBox(height: 16),
          _buildFluencyCard(),
        ],
      ),
    );
  }

  Widget _buildFluencyCard() => const Padding(padding: EdgeInsets.all(16),
    child: Text('Oral-reading fluency has not been validated. Accuracy and BKT mastery are different measures and are not used as a fluency score.'));

  Widget _buildReadingProgressTab() {
    List<dynamic> trendRaw = _progress?['accuracy_trend'] ?? [];
    List<double?> trendData = trendRaw.map((e) => (e['accuracy'] as num?)?.toDouble()).toList();
    
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
            labels: trendRaw.map((e) => e['session'].toString()).toList(),
            lineColor: AppColors.calmBlue,
            minY: 0,
            maxY: 100,
          ),
          Text('Estimated skill mastery', style: AppTypography.heading(fontSize: 18)),
          if (_skills?['_error'] != null) Text(_skills!['_error'].toString()),
          ...((_skills?['skills'] as List?) ?? []).map((r) => ListTile(
            title: Text(r['skill_name'].toString()), subtitle: Text(r['status'].toString()),
            trailing: Text(metricText(r['mastery_percentage'], suffix: '%', decimals: 0)),
          )),
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
                    _learningPattern?['observation'] ?? "No learning-pattern evidence is available.",
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
              rows: ((_activityHistory?['history'] as List?) ?? []).map((r) => DataRow(cells: [
                DataCell(Text('${r['session_date']}')),
                DataCell(Text('${r['activity_name']}')),
                DataCell(Text(metricText(r['accuracy'], suffix: '%', decimals: 0))),
                DataCell(Text(metricText(r['duration_minutes'], suffix: ' min', decimals: 0))),
              ])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() => const Center(child: Padding(padding: EdgeInsets.all(24),
    child: Text('Parent PDF export is not available yet. Use the PP2 Evidence tab to inspect objectives, baseline results and limitations.')));

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
}
