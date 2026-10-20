import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../services/therapist_dashboard_service.dart';
import '../../utils/avatar_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/research_evidence_panel.dart';
import '../../widgets/trend_chart.dart';
import '../../models/comprehensive_assessment_questions.dart';
import 'therapist_adaptive_evidence_view.dart';
import 'therapist_component_tabs.dart';
import '../../widgets/dashboard/dashboard_kit.dart';

class TherapistStudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const TherapistStudentDetailScreen({super.key, required this.student});

  @override
  State<TherapistStudentDetailScreen> createState() =>
      _TherapistStudentDetailScreenState();
}

class _TherapistStudentDetailScreenState
    extends State<TherapistStudentDetailScreen> {
  final TherapistDashboardService _dashboardService =
      TherapistDashboardService();
  bool _isLoading = true;

  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _c1Behavioral;
  Map<String, dynamic>? _c2Speech;
  Map<String, dynamic>? _c3Profile;
  Map<String, dynamic>? _c4Adaptive;
  Map<String, dynamic>? _activityPerformance;
  String? _errorMessage;
  String _selectedAssessmentCategory = 'all';
  int _activityDays = 30;

  String? get _studentId =>
      widget.student['student_id']?.toString() ??
      widget.student['id']?.toString() ??
      widget.student['_id']?.toString();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    final studentId =
        widget.student['student_id']?.toString() ??
        widget.student['id']?.toString() ??
        widget.student['_id']?.toString();
    Future<Map<String, dynamic>> capture(
      Future<Map<String, dynamic>> request,
    ) async {
      try {
        return await request;
      } catch (e) {
        return {'_error': e.toString()};
      }
    }

    final responses = studentId == null || studentId.isEmpty
        ? List.generate(
            6,
            (_) => <String, dynamic>{'_error': 'Invalid student ID'},
          )
        : await Future.wait([
            capture(_dashboardService.getOverview(studentId)),
            capture(_dashboardService.getC1Behavioral(studentId, days: _activityDays)),
            capture(
              _dashboardService.getActivityPerformance(
                studentId,
                days: _activityDays,
              ),
            ),
            capture(_dashboardService.getC2Speech(studentId, days: _activityDays)),
            capture(_dashboardService.getC3Profile(studentId)),
            capture(_dashboardService.getC4Adaptive(studentId)),
          ]);
    if (!mounted) return;
    setState(() {
      _overview = responses[0];
      _c1Behavioral = responses[1];
      _activityPerformance = responses[2];
      _c2Speech = responses[3];
      _c3Profile = responses[4];
      _c4Adaptive = responses[5];
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _downloadPdf() async {
    final studentId =
        widget.student['student_id']?.toString() ??
        widget.student['id']?.toString() ??
        widget.student['_id']?.toString();
    if (studentId == null) return;
    try {
      // Show loading snackbar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating PDF Report...')));
      // Fetch pdf
      final bytes = await _dashboardService.downloadReport(studentId);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: 'Sipsara_Report.pdf',
            ),
          ],
          fileNameOverrides: ['Sipsara_Report.pdf'],
        ),
      );
      // Let's assume standard flutter 'dart:html' downloading for web, but since this is mobile/multi we just show success for now.
      // In a real app we'd use path_provider and open_file, or printing package.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report ready in the share dialog.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name =
        _overview?['first_name'] ??
        _overview?['student_name'] ??
        widget.student['first_name'] ??
        widget.student['student_name'] ??
        widget.student['name'] ??
        'Student';
    final avatar = AvatarUtils.getCorrectedAvatarPath(
      (_overview?['avatar_url'] ?? widget.student['avatar_url']) as String?,
      'assets/images/characters/human/human_student_1.png',
    );

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            PopupMenuButton<int>(
              tooltip: 'Filter activity details',
              onSelected: (days) {
                if (days == _activityDays) return;
                setState(() => _activityDays = days);
                _loadAllData();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 7, child: Text('Last 7 days')),
                PopupMenuItem(value: 30, child: Text('Last 30 days')),
                PopupMenuItem(value: 90, child: Text('Last 90 days')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    'Last ${_activityDays}d',
                    style: DashText.body(fontSize: 14, color: AppColors.calmBlueDark),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.calmBlue,
              ),
              tooltip: 'Reload latest data',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing student data...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                _loadAllData();
              },
            ),
          ],
          title: Row(
            children: [
              CircleAvatar(radius: 16, backgroundImage: AssetImage(avatar)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: DashText.heading(
                    fontSize: 19,
                    color: AppColors.textPrimary,
                  ),
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
            labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: "Summary"),
              Tab(text: "Activities"),
              Tab(text: "Reading"),
              Tab(text: "Combined profile"),
              Tab(text: "Adaptive support"),
              Tab(text: "Parent questionnaire"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAllData,
                color: AppColors.calmBlue,
                child: TabBarView(
                  children: [
                    DashboardSection(
                      data: _overview,
                      onRetry: _loadAllData,
                      child: _buildOverviewTab(),
                    ),
                    DashboardSection(
                      data: _c1Behavioral,
                      onRetry: _loadAllData,
                      child: TherapistActivityTab(
                        data: _c1Behavioral ?? const {},
                        activityPerformance: _activityPerformance,
                        studentId: _studentId ?? '',
                        onChanged: _loadAllData,
                      ),
                    ),
                    DashboardSection(
                      data: _c2Speech,
                      onRetry: _loadAllData,
                      child: TherapistReadingTab(data: _c2Speech ?? const {}),
                    ),
                    DashboardSection(
                      data: _c3Profile,
                      onRetry: _loadAllData,
                      child: TherapistCombinedProfileTab(
                        data: _c3Profile ?? const {},
                        studentId: _studentId ?? '',
                        onChanged: _loadAllData,
                      ),
                    ),
                    DashboardSection(
                      data: _c4Adaptive,
                      onRetry: _loadAllData,
                      child: TherapistAdaptiveEvidenceView(
                        student: widget.student,
                        initialData: _c4Adaptive,
                      ),
                    ),
                    DashboardSection(
                      data: {},
                      onRetry: _loadAllData,
                      child: _buildAssessmentTab(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ==========================================
  // 1. OVERVIEW
  // ==========================================
  Widget _buildOverviewTab() {
    final overview = _overview ?? const <String, dynamic>{};
    final coverage = Map<String, dynamic>.from(overview['coverage'] as Map? ?? const {});
    final alerts = overview['alerts'] as List<dynamic>? ?? const [];
    final sectionsDone = DashFormat.number(coverage['questionnaire_sections_done'])?.round() ?? 0;
    final sectionsTotal = DashFormat.number(coverage['questionnaire_sections_total'])?.round() ?? 4;
    final recordings = DashFormat.number(coverage['recordings'])?.round() ?? 0;
    final usable = DashFormat.number(coverage['usable_recordings'])?.round() ?? 0;
    final sessions = DashFormat.number(coverage['activity_sessions'])?.round() ?? 0;
    final days = coverage['window_days'] ?? 30;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildChildProfileCard(widget.student),
        const SizedBox(height: 14),
        DashCard(
          title: 'Evidence collected',
          subtitle: 'Last $days days · last active ${DashFormat.date(coverage['last_active_at'] ?? overview['last_active'])}',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: 'Activities: $sessions sessions',
                tone: sessions > 0 ? DashTone.good : DashTone.neutral,
                icon: Icons.touch_app_outlined,
              ),
              StatusChip(
                label: 'Reading: $usable of $recordings clear',
                tone: recordings == 0 ? DashTone.neutral : (usable > 0 ? DashTone.good : DashTone.watch),
                icon: Icons.mic_none_rounded,
              ),
              StatusChip(
                label: 'Questionnaire: $sectionsDone of $sectionsTotal',
                tone: sectionsDone >= sectionsTotal ? DashTone.good : DashTone.neutral,
                icon: Icons.assignment_outlined,
              ),
              StatusChip(
                label: coverage['combined_profile_ready'] == true ? 'Combined profile ready' : 'Combined profile not ready',
                tone: coverage['combined_profile_ready'] == true ? DashTone.good : DashTone.neutral,
                icon: Icons.hub_outlined,
              ),
              StatusChip(
                label: coverage['professional_review'] == true ? 'Reviewed by you' : 'Not reviewed yet',
                tone: coverage['professional_review'] == true ? DashTone.good : DashTone.neutral,
                icon: Icons.rate_review_outlined,
              ),
            ],
          ),
        ),
        DashCard(
          title: 'Needs attention',
          subtitle: 'Remote-monitoring prompts from recent activity',
          child: AlertList(alerts: alerts),
        ),
        DashCard(
          title: 'At a glance',
          subtitle: 'Latest session; details in each tab',
          child: MetricGrid(
            children: [
              MetricTile(
                label: 'Correct on first try',
                value: DashFormat.percent(overview['accuracy']),
                icon: Icons.check_circle_outline_rounded,
                tone: DashTone.good,
              ),
              MetricTile(
                label: 'Completed sessions',
                value: DashFormat.count(overview['completed_sessions']),
                icon: Icons.event_available_outlined,
              ),
              MetricTile(
                label: 'Within-session fatigue',
                value: (overview['fatigue_status'] ?? DashFormat.missing).toString(),
                icon: Icons.battery_charging_full_rounded,
                tone: DashTone.watch,
              ),
              MetricTile(
                label: 'Average mastery estimate',
                value: DashFormat.percent(overview['overall_mastery']),
                detail: (overview['reading_fluency_status'] ?? '').toString(),
                icon: Icons.insights_outlined,
              ),
            ],
          ),
        ),
        if (overview['latest_recommendation'] != null)
          DashCard(
            title: 'Latest adaptive decision',
            child: Text(
              overview['latest_recommendation'].toString(),
              style: DashText.body(fontSize: 15),
            ),
          ),
        _buildClinicalReportExportCard(),
      ],
    );
  }

  // ==========================================
  // 1b. PARENT ASSESSMENT TAB
  // ==========================================
  Widget _buildAssessmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildAssessmentAnswersSection(widget.student),
    );
  }

  // ==========================================
  // 5. C4 — ADAPTIVE LEARNING
  // ==========================================
  // Retained as a rollback reference while the production tab uses the
  // focused evidence view above. No other learner-detail tab is replaced.
  // ignore: unused_element
  Widget _buildC4AdaptiveTab() {
    final kcs = _c4Adaptive?['knowledge_components'] as List<dynamic>? ?? [];
    final history = _c4Adaptive?['history'] as List<dynamic>? ?? [];
    final theta = _c4Adaptive?['theta'];
    final thetaSe = _c4Adaptive?['theta_se'];
    final policyStatus =
        (_c4Adaptive?['policy_status'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final latestPolicy =
        (_c4Adaptive?['latest_policy_decision'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final effectiveness =
        (_c4Adaptive?['support_effectiveness'] as List<dynamic>?) ?? [];
    final persistentNeeds =
        (_c4Adaptive?['persistent_learning_needs'] as List<dynamic>?) ?? [];
    final dataQuality =
        (_c4Adaptive?['data_quality'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final policyMode = policyStatus['mode']?.toString() ?? 'baseline';
    final controlsLive = policyStatus['controls_live_adaptation'] == true;
    final executionSource =
        latestPolicy['execution_source']?.toString() ??
        policyStatus['applied_policy']?.toString() ??
        '';
    final isSimulation = executionSource == 'synthetic_model_simulation';
    final linkedOutcomes = dataQuality['policy_rows_with_outcomes'] ?? 0;
    final immediateOutcomes =
        dataQuality['policy_rows_with_proximal_outcomes'] ?? 0;
    final agreementRate = dataQuality['recommendation_agreement_rate'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.calmBlue.withValues(alpha: 0.18),
                  AppColors.gentleGreen.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.calmBlue.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.calmBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.psychology_alt_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adaptive support evidence',
                            style: DashText.heading(fontSize: 20),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isSimulation
                                ? 'Standardized adaptive policy model is actively directing progression'
                                : controlsLive
                                ? 'Validated model-assisted policy is active'
                                : 'Safe rule policy is active; ML is monitored in $policyMode mode',
                            style: DashText.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildC4MetricTile(
                        'Decisions',
                        '${dataQuality['policy_rows'] ?? 0}',
                        Icons.route_rounded,
                        AppColors.calmBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildC4MetricTile(
                        'Follow-ups',
                        '$linkedOutcomes',
                        Icons.fact_check_outlined,
                        AppColors.gentleGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildC4MetricTile(
                        'Agreement',
                        agreementRate is num
                            ? '${(agreementRate * 100).round()}%'
                            : '—',
                        Icons.compare_arrows_rounded,
                        AppColors.warmAmber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (policyStatus.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.calmBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.calmBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        controlsLive
                            ? (isSimulation
                                  ? Icons.science_outlined
                                  : Icons.model_training)
                            : Icons.shield_outlined,
                        color: controlsLive
                            ? AppColors.gentleGreen
                            : AppColors.warmAmber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controlsLive
                              ? (isSimulation
                                    ? 'Research simulation control enabled'
                                    : 'Validated model control enabled')
                              : 'Research shadow mode — model does not control the child task',
                          style: DashText.heading(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildC4LabelValue(
                    'Applied policy',
                    policyStatus['applied_policy'],
                  ),
                  _buildC4LabelValue(
                    'Research model',
                    policyStatus['model_version'],
                  ),
                  _buildC4LabelValue(
                    'Validation',
                    policyStatus['model_validation_status'],
                  ),
                  _buildC4LabelValue(
                    'Evidence',
                    policyStatus['evidence_scope'],
                  ),
                  if (latestPolicy.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text(
                      'Latest support decision',
                      style: DashText.heading(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildC4LabelValue('Item', latestPolicy['item_id']),
                    _buildC4LabelValue(
                      'ML suggested',
                      _friendlyC4Action(latestPolicy['model_recommendation']),
                    ),
                    _buildC4LabelValue(
                      'App applied',
                      _friendlyC4Action(latestPolicy['applied_action']),
                    ),
                    _buildC4LabelValue(
                      'Ranking margin',
                      metricText(latestPolicy['model_confidence']),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The ranking margin is the score gap between the best two actions; it is not a clinical confidence score.',
                      style: DashText.caption(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (effectiveness.isNotEmpty) ...[
            Text(
              'Observed support outcomes',
              style: DashText.heading(fontSize: 18),
            ),
            const SizedBox(height: 3),
            Text(
              'Descriptive follow-up evidence from this learner; not proof that an action caused the outcome.',
              style: DashText.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ...effectiveness.map((raw) {
              final row = raw as Map<String, dynamic>;
              final rate = row['next_independent_success_rate'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.support_rounded,
                      color: AppColors.calmBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _friendlyC4Action(row['action']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${row['outcomes'] ?? 0} linked checks from ${row['uses'] ?? 0} uses',
                            style: DashText.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      rate == null ? '—' : '${((rate as num) * 100).round()}%',
                      style: DashText.heading(
                        fontSize: 16,
                        color: AppColors.gentleGreen,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          if (persistentNeeds.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Persistent learning needs',
              style: DashText.heading(fontSize: 18),
            ),
            const SizedBox(height: 3),
            Text(
              'Units that remain unresolved after bounded checks in different task contexts. This is instructional evidence, not a diagnosis.',
              style: DashText.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ...persistentNeeds.map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              final activities = (row['activities'] as List? ?? const [])
                  .map((value) => value.toString())
                  .join(', ');
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warmAmber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warmAmber.withValues(alpha: 0.32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target: ${row['unit'] ?? '—'}',
                      style: DashText.heading(fontSize: 15),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${row['independent_failures'] ?? 0} failed opportunities • ${row['independent_success_contexts'] ?? 0}/2 independent success contexts • $activities',
                      style: DashText.caption(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      row['recommendation']?.toString() ?? '',
                      style: DashText.body(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          if (dataQuality.isNotEmpty) ...[
            Text(
              'Evidence links: $linkedOutcomes follow-up checks and $immediateOutcomes immediate responses',
              style: DashText.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'C3 fusion: ${dataQuality['c3_pipeline_status'] ?? 'not_run'}',
              style: DashText.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if ((dataQuality['c3_missing_inputs'] as List<dynamic>?)
                    ?.isNotEmpty ==
                true) ...[
              const SizedBox(height: 4),
              Text(
                'C3 unavailable inputs: ${(dataQuality['c3_missing_inputs'] as List<dynamic>).join(', ')}',
                style: DashText.caption(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              dataQuality['calibration_warning']?.toString() ?? '',
              style: DashText.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Current Decision Card
          if (history.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                border: Border.all(color: AppColors.calmBlue, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "LATEST ADAPTIVE ROUTING DECISION",
                      style: DashText.heading(
                        fontSize: 16,
                        color: AppColors.calmBlue,
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Difficulty", style: DashText.caption()),
                          Text(
                            "${metricText(history.last['previous_difficulty'])} → ${metricText(history.last['selected_difficulty'])}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Scaffold", style: DashText.caption()),
                          Text(
                            "Level ${history.last['scaffold_level'] ?? 0}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Next Activity", style: DashText.caption()),
                  Text(
                    "${history.last['next_activity'] ?? 'Unknown'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text("Reason", style: DashText.caption()),
                  Text(
                    "${history.last['reason'] ?? 'N/A'}",
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          Text(
            "Estimated KC Mastery (BKT)",
            style: DashText.heading(fontSize: 18),
          ),
          const SizedBox(height: 12),
          ...kcs.map(
            (kc) => _buildHorizontalBar(
              kc['name'] ?? '',
              (kc['mastery'] as num).toDouble(),
              AppColors.gentleGreen,
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "IRT Ability (θ)",
                  metricText(theta),
                  Icons.person,
                  AppColors.calmBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "IRT SE",
                  metricText(thetaSe),
                  Icons.error_outline,
                  AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Text(
            "Adaptive Decision Timeline",
            style: DashText.heading(fontSize: 18),
          ),
          const SizedBox(height: 16),

          // Timeline
          ...history.asMap().entries.map((entry) {
            int idx = entry.key;
            var dec = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.calmBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "${idx + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mastery ${metricText(dec['mastery_after'])}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Difficulty ${metricText(dec['selected_difficulty'])}",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((dec['scaffold_level'] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warmAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Scaffold ON",
                        style: TextStyle(
                          color: AppColors.warmAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildC4MetricTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value, style: DashText.heading(fontSize: 17, color: color)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashText.caption(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildC4LabelValue(String label, dynamic rawValue) {
    final value = rawValue?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 106,
            child: Text(
              label,
              style: DashText.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value.isEmpty ? 'Unavailable' : value,
              style: DashText.caption(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyC4Action(dynamic rawAction) {
    const labels = <String, String>{
      'RETRY_CURRENT': 'Retry current task',
      'SCAFFOLD_REMOVE_DISTRACTOR': 'Remove one distractor',
      'SCAFFOLD_DISABLE_DISTRACTOR': 'Lock one distractor',
      'SCAFFOLD_HIGHLIGHT_CORRECT': 'Highlight the correct choice',
      'SCAFFOLD_REVEAL_FIRST_TOKEN': 'Reveal the next correct token',
      'SCAFFOLD_REPLAY_INSTRUCTION': 'Replay the instruction',
    };
    final action = rawAction?.toString();
    return labels[action] ?? action ?? 'Unavailable';
  }

  // ==========================================
  // SHARED WIDGETS
  // ==========================================
  Widget _buildHorizontalBar(
    String label,
    dynamic rawValue,
    Color color, {
    String prefix = "",
  }) {
    final value = rawValue != null ? (rawValue as num).toDouble() : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (value != null)
                  FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value != null ? " $prefix${(value * 100).toInt()}%" : "N/A",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: value != null ? Colors.black : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, dynamic icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon is IconData
              ? Icon(icon, color: color, size: 20)
              : FaIcon(icon as FaIconData, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: DashText.heading(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: DashText.caption(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CHILD PROFILE DETAILS CARD
  // ==========================================
  Widget _buildChildProfileCard(Map<String, dynamic> student) {
    final firstName =
        _overview?['first_name'] ??
        student['first_name'] ??
        _overview?['student_name'] ??
        student['student_name'] ??
        'Student';
    final lastName = _overview?['last_name'] ?? student['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final grade = _overview?['grade'] ?? student['grade'] ?? 'Grade 1';
    final rawAge = _overview?['age'] ?? student['age'];
    final age = rawAge != null ? "$rawAge Years" : "Not provided";
    final studentId =
        student['student_id'] ??
        student['id'] ??
        student['_id'] ??
        _overview?['student_id'] ??
        'N/A';
    final parentName =
        _overview?['parent_name'] ??
        student['consent_parent_name'] ??
        student['parent_name'] ??
        'Parent / Guardian';
    final consentDate = student['consent_date'] ?? 'Registered';
    final avatar = AvatarUtils.getCorrectedAvatarPath(
      (_overview?['avatar_url'] ?? student['avatar_url']) as String?,
      'assets/images/characters/human/human_student_1.png',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.calmBlue.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 28, backgroundImage: AssetImage(avatar)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: DashText.heading(
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$grade • Age: $age',
                      style: DashText.body(
                        fontSize: 14,
                        color: AppColors.calmBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gentleGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gentleGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.gentleGreen,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Active Student',
                      style: TextStyle(
                        color: AppColors.gentleGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: AppColors.borderLight),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildDetailChip(
                Icons.badge_outlined,
                "Student ID",
                studentId.toString(),
              ),
              _buildDetailChip(
                Icons.family_restroom_rounded,
                "Parent / Guardian",
                parentName.toString(),
              ),
              _buildDetailChip(
                Icons.calendar_today_rounded,
                "Consent Date",
                consentDate.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: DashText.caption(color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CLINICAL REPORT EXPORT CARD (ABOVE PARENT SECTION)
  // ==========================================
  Widget _buildClinicalReportExportCard() {
    return DashCard(
      title: 'Professional summary report',
      subtitle: 'PDF with activity, reading and combined-profile evidence, including model labels and limitations',
      accent: AppColors.calmBlue,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _downloadPdf,
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: Text('Share report (PDF)', style: DashText.button()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.calmBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAssessmentReviewed(
    String categoryKey,
    bool currentStatus,
  ) async {
    final studentId =
        widget.student['student_id']?.toString() ??
        widget.student['id']?.toString() ??
        widget.student['_id']?.toString();
    if (studentId == null) return;
    try {
      final newStatus = !currentStatus;
      setState(() {
        final revMap = Map<String, dynamic>.from(
          _overview?['reviewed_assessments'] ?? {},
        );
        revMap[categoryKey] = newStatus;
        if (_overview != null) {
          _overview!['reviewed_assessments'] = revMap;
        }
      });
      await _dashboardService.markAssessmentReviewed(
        studentId,
        categoryKey,
        newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Assessment marked as reviewed!'
                : 'Assessment review status updated.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update review status: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _loadAllData();
    }
  }

  // ==========================================
  // PARENT ASSESSMENT ANSWERS SECTION (ALL 4 ASSESSMENTS)
  // ==========================================
  List<bool> _assessmentAnswerValues(dynamic raw) {
    if (raw is! List) return const <bool>[];
    return raw.map<bool>((item) {
      if (item is bool) return item;
      if (item is Map) return item['answer'] == true;
      return false;
    }).toList();
  }

  List<dynamic> _assessmentRawValues(dynamic raw) =>
      raw is List ? List<dynamic>.from(raw) : const <dynamic>[];

  Widget _buildAssessmentAnswersSection(Map<String, dynamic> student) {
    final basicResults = _assessmentRawValues(
      _overview?['assessment_results'] ?? student['assessment_results'],
    );

    final compMap =
        (_overview?['comprehensive_assessment_results'] as Map?)
            ?.cast<String, dynamic>() ??
        (student['comprehensive_assessment_results'] as Map?)
            ?.cast<String, dynamic>() ??
        {};

    final readingResults = _assessmentRawValues(compMap['reading']);
    final writingResults = _assessmentRawValues(compMap['writing']);
    final otherResults = _assessmentRawValues(compMap['other']);

    final totalCompleted =
        (basicResults.isNotEmpty ? 1 : 0) +
        (readingResults.isNotEmpty ? 1 : 0) +
        (writingResults.isNotEmpty ? 1 : 0) +
        (otherResults.isNotEmpty ? 1 : 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "දෙමාපිය දැනුවත් කිරීමේ ප්‍රශ්නාවලිය",
                style: DashText.sinhala(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Parent Awareness Questionnaires ($totalCompleted/4 Completed) — Tap to Expand Details",
                style: DashText.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category Filter Chips for All 4 Assessments
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', 'සියල්ල (All 4)', totalCompleted),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'basic',
                  '1. මූලික පරීක්ෂණය (14)',
                  basicResults.isNotEmpty ? 1 : 0,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'reading',
                  '2. කියවීම හා දෘශ්‍ය (10)',
                  readingResults.isNotEmpty ? 1 : 0,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'writing',
                  '3. ලිවීම (6)',
                  writingResults.isNotEmpty ? 1 : 0,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'other',
                  '4. වෙනත් (12)',
                  otherResults.isNotEmpty ? 1 : 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Render Collapsible Cards for Selected Category or All 4 Categories
          if (_selectedAssessmentCategory == 'all' ||
              _selectedAssessmentCategory == 'basic')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'basic',
              titleSi: "1. මූලික කියවීමේ අපහසුතා නිරීක්ෂණ (14)",
              titleEn: "1. Basic reading-difficulty observations",
              questions: ComprehensiveAssessmentData.basicAssessment,
              answers: basicResults,
            ),

          if (_selectedAssessmentCategory == 'all' ||
              _selectedAssessmentCategory == 'reading')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'reading',
              titleSi: "2. කියවීම හා දෘශ්‍ය සංජානන සම්බන්ධ අපහසුතා (10)",
              titleEn: "2. Reading & Visual Perception",
              questions: ComprehensiveAssessmentData.readingAssessment,
              answers: readingResults,
            ),

          if (_selectedAssessmentCategory == 'all' ||
              _selectedAssessmentCategory == 'writing')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'writing',
              titleSi: "3. ලිවීම සම්බන්ධ අපහසුතා (6)",
              titleEn: "3. Writing Difficulties",
              questions: ComprehensiveAssessmentData.writingAssessment,
              answers: writingResults,
            ),

          if (_selectedAssessmentCategory == 'all' ||
              _selectedAssessmentCategory == 'other')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'other',
              titleSi: "4. වෙනත් සම්බන්ධ අපහසුතා (12)",
              titleEn: "4. Other Associated / Health & Speech",
              questions: ComprehensiveAssessmentData.otherAssessment,
              answers: otherResults,
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleAssessmentCard({
    required Map<String, dynamic> student,
    required String categoryKey,
    required String titleSi,
    required String titleEn,
    required List<ComprehensiveQuestion> questions,
    required List<dynamic> answers,
  }) {
    final isCompleted = answers.isNotEmpty;
    final revMap =
        (_overview?['reviewed_assessments'] as Map?)?.cast<String, dynamic>() ??
        (student['reviewed_assessments'] as Map?)?.cast<String, dynamic>() ??
        {};
    final isReviewed = revMap[categoryKey] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? AppColors.calmBlue.withValues(alpha: 0.3)
              : AppColors.borderLight,
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: 14,
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleSi,
                      style: DashText.sinhala(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      titleEn,
                      style: DashText.caption(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.gentleGreen.withValues(alpha: 0.15)
                      : AppColors.warmAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.gentleGreen
                        : AppColors.warmAmber,
                  ),
                ),
                child: Text(
                  isCompleted ? "Finished ✓" : "Pending",
                  style: TextStyle(
                    color: isCompleted
                        ? AppColors.gentleGreen
                        : AppColors.warmAmber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isCompleted) ...[
                  InkWell(
                    onTap: () =>
                        _toggleAssessmentReviewed(categoryKey, isReviewed),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isReviewed
                            ? AppColors.calmBlue.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isReviewed
                              ? AppColors.calmBlue
                              : AppColors.textHint,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReviewed
                                ? Icons.check_circle_rounded
                                : Icons.outlined_flag_rounded,
                            size: 13,
                            color: isReviewed
                                ? AppColors.calmBlue
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isReviewed ? "Reviewed ✓" : "Mark as Reviewed",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isReviewed
                                  ? AppColors.calmBlue
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    "Not Submitted",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                InkWell(
                  onTap: () =>
                      _exportAssessmentMedicalReport(student, categoryKey),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.calmBlue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 13,
                          color: AppColors.calmBlue,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Export PDF",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.calmBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 16),
            _buildAssessmentCategoryTable(
              titleSi: titleSi,
              titleEn: titleEn,
              questions: questions,
              answers: answers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label, int statusCount) {
    final isSelected = _selectedAssessmentCategory == categoryKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.calmBlue.withValues(alpha: 0.2),
      backgroundColor: AppColors.cream,
      side: BorderSide(
        color: isSelected ? AppColors.calmBlue : AppColors.borderLight,
        width: 1.5,
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _selectedAssessmentCategory = categoryKey);
        }
      },
    );
  }

  Widget _buildAssessmentCategoryTable({
    required String titleSi,
    required String titleEn,
    required List<ComprehensiveQuestion> questions,
    required List<dynamic> answers,
  }) {
    TableRow rowAt(int index) {
      final raw = index < answers.length ? answers[index] : null;
      final answer = raw is bool
          ? raw
          : raw is Map && raw['answer'] is bool
          ? raw['answer'] as bool
          : null;
      return _buildTableRowItem(
        index: index + 1,
        question: questions[index],
        answer: answer,
        questionSi: raw is Map ? raw['question_si']?.toString() : null,
        questionEn: raw is Map
            ? (raw['question_en'] ?? raw['question_text'])?.toString()
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header Title
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.calmBlue.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(
              color: AppColors.calmBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SelectableText(
                  "$titleSi ($titleEn)",
                  style: DashText.sinhala(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.calmBlueDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: answers.isNotEmpty
                      ? AppColors.gentleGreen
                      : Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  answers.isNotEmpty
                      ? "${answers.length}/${questions.length} Saved"
                      : "Not Done",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Header
        Table(
          border: TableBorder.all(color: AppColors.borderLight),
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FlexColumnWidth(4),
            2: FixedColumnWidth(65),
            3: FixedColumnWidth(65),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
              children: const [
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      "අංකය\n(No)",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      "ප්‍රශ්නය (Question)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      "ඔව්\n(Yes)",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.softCoral,
                      ),
                    ),
                  ),
                ),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      "නැත\n(No)",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.gentleGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            for (int i = 0; i < questions.length; i++) rowAt(i),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRowItem({
    required int index,
    required ComprehensiveQuestion question,
    required bool? answer,
    String? questionSi,
    String? questionEn,
  }) {
    return TableRow(
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: SelectableText(
              "$index",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  questionSi ?? question.textSi,
                  style: DashText.sinhala(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  questionEn ?? question.textEn,
                  style: DashText.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Column 1: ඔව් (Yes)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Center(
            child: answer == true
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.softCoral,
                      size: 20,
                    ),
                  )
                : const Icon(
                    Icons.check_box_outline_blank_rounded,
                    color: Colors.black26,
                    size: 18,
                  ),
          ),
        ),
        // Column 2: නැත (No)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Center(
            child: answer == false
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF9F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.gentleGreen,
                      size: 20,
                    ),
                  )
                : const Icon(
                    Icons.check_box_outline_blank_rounded,
                    color: Colors.black26,
                    size: 18,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportAssessmentMedicalReport(
    Map<String, dynamic> student,
    String categoryKey,
  ) async {
    final firstName = student['first_name'] ?? 'Student';
    final lastName = student['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final grade = student['grade'] ?? 'Grade 1';
    final age = student['age'] != null ? "${student['age']} Years" : "6 Years";
    final studentId =
        student['student_id'] ?? student['id'] ?? student['_id'] ?? 'N/A';
    final parentName =
        student['consent_parent_name'] ??
        student['parent_name'] ??
        'Parent / Guardian';

    final basicResults = _assessmentAnswerValues(
      _overview?['assessment_results'] ?? student['assessment_results'],
    );

    final compMap =
        (_overview?['comprehensive_assessment_results'] as Map?)
            ?.cast<String, dynamic>() ??
        (student['comprehensive_assessment_results'] as Map?)
            ?.cast<String, dynamic>() ??
        {};

    final readingResults = _assessmentAnswerValues(compMap['reading']);
    final writingResults = _assessmentAnswerValues(compMap['writing']);
    final otherResults = _assessmentAnswerValues(compMap['other']);

    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      "==========================================================================================",
    );
    buffer.writeln(
      "                             දෙමාපිය දැනුවත් කිරීමේ ප්‍රශ්නාවලිය",
    );
    buffer.writeln(
      "   Parent Awareness Questionnaire — Basic reading-difficulty observations (for professional review)",
    );
    buffer.writeln(
      "==========================================================================================",
    );
    buffer.writeln(
      "දරුවාගේ නම (Child Name): $fullName | වයස (Age): $age ($grade) | දිනය (Date): ${DateTime.now().toString().split(' ')[0]}",
    );
    buffer.writeln("Student ID: $studentId | Parent/Guardian: $parentName");
    buffer.writeln(
      "==========================================================================================",
    );
    buffer.writeln(
      "උපදෙස්: කරුණාකර පහත එක් එක් ප්‍රශ්නය සඳහා දරුවා පිළිබඳ ඔබේ නිරීක්ෂණයට අනුව",
    );
    buffer.writeln(
      "\"ඔව්\", \"නැත\" හෝ \"හඳුනාගත නොහැක\" යන කොටුවලින් එකක් ලකුණු කරන්න.",
    );
    buffer.writeln(
      "------------------------------------------------------------------------------------------\n",
    );

    void formatCategoryTable(
      String sectionTitle,
      List<ComprehensiveQuestion> questions,
      List<bool> answers,
    ) {
      buffer.writeln(
        "------------------------------------------------------------------------------------------",
      );
      buffer.writeln(sectionTitle);
      buffer.writeln(
        "------------------------------------------------------------------------------------------",
      );
      buffer.writeln(
        "| අංකය | ප්‍රශ්නය                                               | ඔව්(Yes) | නැත(No) |",
      );
      buffer.writeln(
        "+------+-------------------------------------------------------+----------+---------+",
      );

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final bool? val = i < answers.length ? answers[i] : null;
        final String colYes = val == true ? "[ X ]" : "[   ]";
        final String colNo = val == false ? "[ X ]" : "[   ]";

        final numStr = (i + 1).toString().padLeft(2, '0');
        buffer.writeln("|  $numStr  | ${q.textSi}");
        buffer.writeln(
          '${"|      | (${q.textEn})".padRight(63)}|  $colYes  |  $colNo  |',
        );
        buffer.writeln(
          "+------+-------------------------------------------------------+----------+---------+",
        );
      }
      buffer.writeln();
    }

    if (categoryKey == 'all' || categoryKey == 'basic') {
      formatCategoryTable(
        "1. මූලික කියවීමේ අපහසුතා නිරීක්ෂණ (Basic reading-difficulty observations — 14 questions)",
        ComprehensiveAssessmentData.basicAssessment,
        basicResults,
      );
    }
    if (categoryKey == 'all' || categoryKey == 'reading') {
      formatCategoryTable(
        "2. කියවීම හා දෘශ්‍ය සංජානන සම්බන්ධ අපහසුතා (Reading & Visual Perception — 10 Questions)",
        ComprehensiveAssessmentData.readingAssessment,
        readingResults,
      );
    }
    if (categoryKey == 'all' || categoryKey == 'writing') {
      formatCategoryTable(
        "3. ලිවීම සම්බන්ධ අපහසුතා (Writing Difficulties — 6 Questions)",
        ComprehensiveAssessmentData.writingAssessment,
        writingResults,
      );
    }
    if (categoryKey == 'all' || categoryKey == 'other') {
      formatCategoryTable(
        "4. වෙනත් සම්බන්ධ අපහසුතා (Other Associated / Health & Speech — 12 Questions)",
        ComprehensiveAssessmentData.otherAssessment,
        otherResults,
      );
    }

    buffer.writeln(
      "------------------------------------------------------------------------------------------",
    );
    buffer.writeln(
      "වෛද්‍ය නිරීක්ෂණ / අදහස් (Doctor Notes & Medical Observations):",
    );
    buffer.writeln(
      "------------------------------------------------------------------------------------------",
    );
    buffer.writeln(
      "1. ____________________________________________________________________________________",
    );
    buffer.writeln(
      "2. ____________________________________________________________________________________",
    );
    buffer.writeln(
      "3. ____________________________________________________________________________________\n",
    );

    try {
      final reportText = buffer.toString();
      final XFile file = XFile.fromData(
        Uint8List.fromList(reportText.codeUnits),
        mimeType: 'text/plain',
        name: '${fullName.replaceAll(' ', '_')}_Medical_Questionnaire.txt',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text:
              'Parent Awareness Questionnaire (Medical Review Report) for $fullName',
          subject: 'Medical Questionnaire - $fullName',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting medical questionnaire: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
