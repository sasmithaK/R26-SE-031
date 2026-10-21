import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/parent_dashboard_service.dart';
import '../../services/progress_service.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/research_evidence_panel.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/dashboard/dashboard_kit.dart';
import '../../widgets/dashboard/letter_practice_grid.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/curriculum_models.dart';
import '../../models/comprehensive_assessment_questions.dart';
import '../../models/assessment_question.dart';
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
  Map<String, dynamic>? _progress;

  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _skills;
  Map<String, dynamic>? _learningPattern;
  Map<String, dynamic>? _activityHistory;
  Map<String, dynamic>? _adaptiveInsights;
  Map<String, dynamic>? _componentAnalytics;
  Map<String, dynamic>? _activityPerformance;
  Map<String, dynamic>? _assessmentSummary;
  int _activityDays = 30;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    await ProgressService().init();
    final studentId =
        widget.studentData['student_id']?.toString() ??
        widget.studentData['id']?.toString() ??
        widget.studentData['_id']?.toString() ??
        '';

    Future<Map<String, dynamic>> capture(
      Future<Map<String, dynamic>> request,
    ) async {
      try {
        return await request;
      } catch (error) {
        return {'_error': error.toString()};
      }
    }

    final responses = studentId.isEmpty
        ? List.generate(
            5,
            (_) => <String, dynamic>{'_error': 'Invalid student ID'},
          )
        : await Future.wait([
            capture(_dashboardService.getOverview(studentId)),
            capture(_dashboardService.getAdaptiveInsights(studentId)),
            capture(_dashboardService.getComponentAnalytics(studentId)),
            capture(
              _dashboardService.getActivityPerformance(
                studentId,
                days: _activityDays,
              ),
            ),
            capture(_dashboardService.getAssessmentSummary(studentId)),
          ]);

    if (!mounted) return;
    setState(() {
      _overview = responses[0];
      _adaptiveInsights = responses[1];
      _componentAnalytics = responses[2];
      _activityPerformance = responses[3];
      _assessmentSummary = responses[4];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.studentData['first_name'] ?? 'student';
    final grade = widget.studentData['grade'] ?? 'Grade 1';
    final compactToolbar =
        MediaQuery.sizeOf(context).width < 390 ||
        MediaQuery.textScalerOf(context).scale(12) > 14;
    final avatar = AvatarUtils.getCorrectedAvatarPath(
      widget.studentData['avatar_url'] as String?,
      'assets/images/characters/human/human_student_1.png',
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cardSurface,
          elevation: 0,
          toolbarHeight: 78,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leadingWidth: compactToolbar ? 56 : 66,
          leading: Padding(
            padding: EdgeInsets.only(
              left: compactToolbar ? 8 : 14,
              top: 12,
              bottom: 12,
            ),
            child: Material(
              color: AppColors.slateBg,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          actions: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.slateBg,
                foregroundColor: AppColors.calmBlue,
              ),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reload latest data',
              onPressed: _loadAllData,
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Filter activity details',
              color: AppColors.cardSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onSelected: (String newValue) {
                if (newValue != _activityDays.toString()) {
                  setState(() {
                    _activityDays = int.tryParse(newValue) ?? 30;
                    _isLoading = true;
                  });
                  _loadAllData();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: '7', child: Text('Last 7 days')),
                PopupMenuItem(value: '30', child: Text('Last 30 days')),
                PopupMenuItem(value: '90', child: Text('Last 90 days')),
              ],
              child: Container(
                margin: EdgeInsets.only(right: compactToolbar ? 4 : 14),
                padding: EdgeInsets.symmetric(
                  horizontal: compactToolbar ? 8 : 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slateBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: compactToolbar
                    ? const Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: AppColors.calmBlue,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 17,
                            color: AppColors.calmBlue,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Activities · ${_activityDays}d',
                            style: DashText.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
          titleSpacing: compactToolbar ? 4 : 8,
          title: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderBlue, width: 2),
                ),
                child: CircleAvatar(backgroundImage: AssetImage(avatar)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toString(),
                      style: DashText.heading(
                        fontSize: 19,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$grade · Learning progress',
                      style: DashText.caption(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              height: 56,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.slateBg.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderBlue),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.calmBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: DashText.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                unselectedLabelStyle: DashText.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
                tabs: const [
                  Tab(
                    child: _ProgressTab(
                      icon: Icons.dashboard_rounded,
                      label: 'Progress',
                    ),
                  ),
                  Tab(
                    child: _ProgressTab(
                      icon: Icons.favorite_rounded,
                      label: 'Learning support',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : TabBarView(
                children: [
                  DashboardSection(
                    data: _componentAnalytics,
                    onRetry: _loadAllData,
                    child: _buildComponentAnalyticsTab(),
                  ),
                  DashboardSection(
                    data: _adaptiveInsights,
                    onRetry: _loadAllData,
                    child: _buildAdaptiveInsightsTab(),
                  ),
                ],
              ),
      ),
    );
  }

  String metricText(
    dynamic value, {
    String suffix = '',
    int decimals = 1,
    double scale = 1,
  }) {
    if (value == null) return '—';
    final number = value is num ? value : num.tryParse(value.toString());
    if (number == null) return value.toString();
    return '${(number * scale).toStringAsFixed(decimals)}$suffix';
  }

  Widget _buildComponentAnalyticsTab() {
    final data = _componentAnalytics ?? const <String, dynamic>{};
    final components = <Map<String, dynamic>>[
      {
        'title': 'Touch and learning behaviour',
        'subtitle': 'Touch responses, attempts and response time',
        'icon': Icons.touch_app_rounded,
        'color': AppColors.calmBlue,
        'data': data['c1_behavioral'],
        'empty':
            'Complete an activity to start collecting touch and activity observations.',
        'metrics': <Map<String, dynamic>>[
          {
            'label': 'Correct on first try (last 30 days)',
            'key': 'first_attempt_accuracy',
            'scale': 100.0,
            'suffix': '%',
          },
          {
            'label': 'Rounds needing another try',
            'key': 'retry_rate',
            'scale': 100.0,
            'suffix': '%',
          },
          {
            'label': 'Typical time to first touch',
            'key': 'median_response_latency_ms',
            'scale': 0.001,
            'suffix': ' s',
          },
        ],
      },
      {
        'id': 'letter_practice',
        'title': 'Sinhala letter practice',
        'subtitle': 'Progress across the vowel and consonant letter sets',
        'icon': Icons.grid_view_rounded,
        'color': AppColors.calmBlue,
        'data': <String, dynamic>{
          'letter_progress': data['c2_speech'] is Map
              ? (data['c2_speech'] as Map)['letter_progress']
              : const [],
        },
        'empty': 'Letter practice will appear after the child records a try.',
        'metrics': <Map<String, dynamic>>[],
      },
      {
        'title': 'Speaking and reading',
        'subtitle': 'Reading recordings and speech observations',
        'icon': Icons.record_voice_over_rounded,
        'color': AppColors.softCoral,
        'data': data['c2_speech'],
        'empty':
            'Try letter practice or one of the reading activities to start collecting speaking observations.',
        'metrics': <Map<String, dynamic>>[
          {'label': 'Recordings', 'key': 'recording_count'},
          {'label': 'Clear enough to measure', 'key': 'usable_recording_count'},
          {
            'label': 'Text match (latest clear recording)',
            'key': 'grapheme_accuracy',
            'scale': 100.0,
            'suffix': '%',
          },
        ],
      },
      {
        'id': 'c3_explainability',
        'title': 'Progress summary',
        'subtitle':
            'A plain-language view of recent activity and reading progress',
        'icon': Icons.insights_rounded,
        'color': AppColors.warmAmber,
        'data': data['c3_explainability'],
        'empty':
            'A combined summary appears after activities and reading recordings.',
        'metrics': <Map<String, dynamic>>[],
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: components.length + 4,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These are learning observations from app activities. They are not marks, rankings or a diagnosis.',
                style: DashText.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildLearningSummaryDownload(),
            ],
          );
        }
        if (index <= components.length) {
          return _buildComponentCard(components[index - 1]);
        }
        if (index == components.length + 1)
          return _buildParentOverviewSummary();
        if (index == components.length + 2) {
          return _buildParentActivitySummary();
        }
        return _buildParentObservations();
      },
    );
  }

  Widget _buildParentOverviewSummary() {
    final data = _overview ?? const <String, dynamic>{};
    final accuracy = data['accuracy'];
    final items = <(String, String)>[
      ('Practice sessions', '${data['sessions_completed'] ?? 0}'),
      ('Completed rounds', '${data['completed_rounds'] ?? 0}'),
      (
        'Practice time',
        metricText(data['practice_time_minutes'], suffix: ' min', decimals: 0),
      ),
      ('Correct on first try', accuracy is num ? '${accuracy.round()}%' : '—'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overall progress', style: DashText.heading(fontSize: 17)),
          Text(
            'Last ${data['window_days'] ?? 30} days'
            '${(data['sessions_ended_early'] ?? 0) is num && (data['sessions_ended_early'] ?? 0) > 0 ? ' · ${data['sessions_ended_early']} session(s) ended before a round was finished' : ''}',
            style: DashText.caption(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.slateBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2, style: DashText.heading(fontSize: 16)),
                        Text(
                          item.$1,
                          style: DashText.caption(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildParentActivitySummary() {
    final activities =
        _activityPerformance?['activities'] as List<dynamic>? ?? const [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity-by-activity progress',
            style: DashText.heading(fontSize: 17),
          ),
          const SizedBox(height: 8),
          if (activities.isEmpty)
            const Text(
              'Activity details will appear after the first completed activity.',
            )
          else
            ...activities.map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              final accuracy = row['first_attempt_accuracy'];
              final voice = Map<String, dynamic>.from(
                row['voice'] as Map? ?? const {},
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  (row['activity_display'] ??
                          row['activity_name'] ??
                          _activityLabel(row['activity_id']))
                      .toString(),
                  style: DashText.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  [
                    (row['skill_name_en'] ?? _parentSkillLabel(row['skill_id']))
                        .toString(),
                    '${row['trials'] ?? 0} responses',
                    if ((voice['recordings'] ?? 0) is num &&
                        (voice['recordings'] ?? 0) > 0)
                      '${voice['usable_recordings'] ?? 0} of ${voice['recordings']} recordings clear',
                  ].join(' · '),
                  style: DashText.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      accuracy is num ? '${(accuracy * 100).round()}%' : '—',
                      style: DashText.heading(fontSize: 17),
                    ),
                    Text('first try', style: DashText.caption(fontSize: 12)),
                  ],
                ),
              );
            }),
          Text(
            'Last 30 days. Percentages describe practice, not test marks.',
            style: DashText.caption(fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _parentSkillLabel(dynamic raw) =>
      switch ((raw?.toString() ?? '').replaceFirst('skill_', '')) {
        '1' => 'Picture skills',
        '2' => 'Letter skills',
        '3' => 'Word skills',
        '4' => 'Sentence skills',
        '5' => 'Reading comprehension',
        '6' => 'Textbook reading',
        'sinhala_vowels' => 'Sinhala vowel letters',
        'sinhala_consonants' => 'Sinhala consonant letters',
        _ => 'Other practice',
      };

  String _activityLabel(dynamic raw) {
    final match = RegExp(r'(\d+)$').firstMatch(raw?.toString() ?? '');
    return match == null ? 'Activity' : 'Activity ${match.group(1)}';
  }

  Widget _buildComponentCard(Map<String, dynamic> definition) {
    final raw = definition['data'];
    final component = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final available = component['available'] == true;
    final color = definition['color'] as Color;
    final metrics = definition['metrics'] as List<Map<String, dynamic>>;

    if (definition['id'] == 'letter_practice') {
      final groups = (component['letter_progress'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      return LetterPracticeGrid(groups: groups);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(definition['icon'] as IconData, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition['title'] as String,
                      style: DashText.heading(fontSize: 16),
                    ),
                    Text(
                      definition['subtitle'] as String,
                      style: DashText.caption(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                available
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                color: available ? AppColors.gentleGreen : AppColors.textHint,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!available)
            Text(
              (definition['empty'] ?? 'Nothing recorded yet.').toString(),
              style: DashText.body(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            if (component['summary_text'] is String)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  component['summary_text'] as String,
                  style: DashText.body(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            if (definition['id'] == 'c3_explainability')
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StatusChip(
                  label: component['combined_estimate_reviewed'] == true
                      ? 'Reviewed by your therapist'
                      : 'Not yet reviewed by a therapist',
                  tone: component['combined_estimate_reviewed'] == true
                      ? DashTone.good
                      : DashTone.neutral,
                  icon: Icons.rate_review_outlined,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics.map((metric) {
                final value = component[metric['key']];
                const qualityLabels = <String, String>{
                  'valid': 'Clear enough to measure',
                  'retry_required': 'Needs a clearer recording',
                  'uncertain': 'Uncertain',
                };
                final text = value is num
                    ? metricText(
                        value,
                        suffix: metric['suffix']?.toString() ?? '',
                        decimals: value % 1 == 0 ? 0 : 1,
                        scale: (metric['scale'] as num?)?.toDouble() ?? 1,
                      )
                    : metric['key'] == 'recording_quality'
                    ? qualityLabels[value?.toString()] ?? 'Not available'
                    : (value?.toString().trim().isNotEmpty == true
                          ? value.toString()
                          : '—');
                return Container(
                  constraints: const BoxConstraints(minWidth: 110),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: DashText.heading(fontSize: 15, color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        metric['label'] as String,
                        style: DashText.caption(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLearningSummaryDownload() {
    return DashCard(
      title: 'Learning summary (PDF)',
      subtitle:
          'Last 30 days, in plain language. Useful to share with a teacher or therapist.',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            'Download and share',
            style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          onPressed: () async {
            final studentId =
                widget.studentData['student_id']?.toString() ??
                widget.studentData['id']?.toString() ??
                widget.studentData['_id']?.toString();
            if (studentId == null) return;
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              const SnackBar(content: Text('Preparing the summary...')),
            );
            try {
              final bytes = await _dashboardService.downloadLearningSummary(
                studentId,
              );
              await SharePlus.instance.share(
                ShareParams(
                  files: [
                    XFile.fromData(
                      bytes,
                      mimeType: 'application/pdf',
                      name: 'Sipsara_Learning_Summary.pdf',
                    ),
                  ],
                  fileNameOverrides: ['Sipsara_Learning_Summary.pdf'],
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                ),
              );
            }
          },
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
    final assessment = Map<String, dynamic>.from(
      _overview?['assessment_summary'] ?? {},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Summary", style: DashText.heading(fontSize: 20)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                "First-attempt accuracy",
                metricText(accuracy, suffix: '%', decimals: 0),
                Icons.track_changes_rounded,
                AppColors.gentleGreen,
              ),
              _buildStatCard(
                "Reading Practice",
                metricText(practice, suffix: ' min', decimals: 0),
                Icons.schedule_rounded,
                AppColors.calmBlue,
              ),
              _buildStatCard(
                "Reading Sessions",
                "$sessions",
                Icons.videogame_asset_rounded,
                AppColors.softCoral,
              ),
              _buildStatCard(
                "Reading Progress",
                progress,
                Icons.trending_up_rounded,
                AppColors.warmAmber,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildParentObservations(),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.calmBlue.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent Assessment Summary',
                  style: DashText.heading(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Completed categories: ${assessment['completed_categories'] ?? 0}/${assessment['total_categories'] ?? 4}',
                ),
                Text(
                  'Reported observations: ${assessment['reported_observations'] ?? 0}',
                ),
                const SizedBox(height: 6),
                const Text(
                  'This parent observation summary highlights behavioral patterns for discussion with educational specialists.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text("Interpretation Limits", style: DashText.heading(fontSize: 20)),
          const SizedBox(height: 16),
          _buildFluencyCard(),
        ],
      ),
    );
  }

  Widget _buildParentObservations() {
    final data = _assessmentSummary ?? const <String, dynamic>{};
    if (data['_error'] != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Parent observations could not be loaded. Refresh this page to try again.',
            style: DashText.body(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final raw = Map<String, dynamic>.from(data['raw_responses'] ?? const {});
    final categories = <String, Map<String, dynamic>>{
      'basic': {
        'title': 'Basic questions',
        'questions': ComprehensiveAssessmentData.basicAssessment,
      },
      'reading': {
        'title': 'Reading and visual skills',
        'questions': ComprehensiveAssessmentData.readingAssessment,
      },
      'writing': {
        'title': 'Writing',
        'questions': ComprehensiveAssessmentData.writingAssessment,
      },
      'other': {
        'title': 'Other observations',
        'questions': ComprehensiveAssessmentData.otherAssessment,
      },
    };
    List<dynamic> responses(String key) =>
        raw[key] is List ? raw[key] as List : const [];

    Widget renderAnswers(List<dynamic> values, List<dynamic> questions) {
      if (values.isEmpty) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text('Not completed yet.'),
        );
      }
      return Column(
        children: List.generate(values.length, (index) {
          final value = values[index];
          final answer = value is Map ? value['answer'] : value;
          final question = index < questions.length ? questions[index] : null;
          final text = value is Map
              ? (value['question_si'] ??
                        value['question_en'] ??
                        value['question_text'])
                    ?.toString()
              : null;
          final questionText =
              text ??
              (question is ComprehensiveQuestion
                  ? question.text
                  : question is AssessmentQuestion
                  ? question.questionText
                  : 'Question ${index + 1}');
          return ListTile(
            dense: true,
            title: Text(questionText, style: DashText.body(fontSize: 13)),
            trailing: Text(
              answer == true
                  ? 'ඔව් / Yes'
                  : answer == false
                  ? 'නැත / No'
                  : 'පිළිතුරු නැත / Not answered',
              style: DashText.caption(fontWeight: FontWeight.w700),
            ),
          );
        }),
      );
    }

    final initial = data['initial_responses'] is List
        ? data['initial_responses'] as List
        : const <dynamic>[];
    final completed = categories.keys
        .where((key) => responses(key).isNotEmpty)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What you’ve shared', style: DashText.heading(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              '$completed of ${categories.length} questionnaire sections completed',
              style: DashText.caption(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Parent-reported observations for discussion, not a diagnosis.',
              style: DashText.caption(color: AppColors.textSecondary),
            ),
            if (initial.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Initial child observations'),
                children: [
                  renderAnswers(initial, AssessmentQuestion.allQuestions),
                ],
              ),
            ...categories.entries.map((entry) {
              final values = responses(entry.key);
              final questions = entry.value['questions'] as List<dynamic>;
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${entry.value['title']} (${values.length}/${questions.length})',
                ),
                children: [renderAnswers(values, questions)],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFluencyCard() => const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Oral-reading fluency has not been validated. Accuracy and BKT mastery are different measures and are not used as a fluency score.',
    ),
  );

  Widget _buildReadingProgressTab() {
    List<dynamic> trendRaw = _progress?['accuracy_trend'] ?? [];
    List<double?> trendData = trendRaw
        .map((e) => (e['accuracy'] as num?)?.toDouble())
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Accuracy Over Time", style: DashText.heading(fontSize: 18)),
          const SizedBox(height: 16),
          TrendChart(
            title: "Reading Accuracy (%)",
            dataPoints: trendData,
            labels: trendRaw.map((e) => e['session'].toString()).toList(),
            lineColor: AppColors.calmBlue,
            minY: 0,
            maxY: 100,
          ),
          Text(
            'Estimated skill mastery',
            style: DashText.heading(fontSize: 18),
          ),
          if (_skills?['_error'] != null) Text(_skills!['_error'].toString()),
          ...((_skills?['skills'] as List?) ?? []).map(
            (r) => ListTile(
              title: Text(r['skill_name'].toString()),
              subtitle: Text(r['status'].toString()),
              trailing: Text(
                metricText(r['mastery_percentage'], suffix: '%', decimals: 0),
              ),
            ),
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
          Text("Observation", style: DashText.heading(fontSize: 18)),
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
                const Icon(
                  Icons.insights_rounded,
                  color: AppColors.gentleGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _learningPattern?['observation'] ??
                        "No learning-pattern evidence is available.",
                    style: DashText.body(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("Recommended Practice", style: DashText.heading(fontSize: 18)),
          const SizedBox(height: 12),
          ...(_learningPattern?['recommended_practices'] as List<dynamic>? ??
                  [])
              .map((p) => _buildRecommendationTile(p.toString())),
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
          Expanded(child: Text(text, style: DashText.body())),
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
          Text(
            "Recent Reading Activity",
            style: DashText.heading(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.calmBlue.withValues(alpha: 0.05),
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Activity',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Result',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: ((_activityHistory?['history'] as List?) ?? [])
                  .map(
                    (r) => DataRow(
                      cells: [
                        DataCell(Text('${r['session_date']}')),
                        DataCell(Text('${r['activity_name']}')),
                        DataCell(
                          Text(
                            metricText(r['accuracy'], suffix: '%', decimals: 0),
                          ),
                        ),
                        DataCell(
                          Text(
                            metricText(
                              r['duration_minutes'],
                              suffix: ' min',
                              decimals: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
          Text(
            value,
            style: DashText.heading(fontSize: 18, color: AppColors.textPrimary),
          ),
          Text(
            label,
            style: DashText.caption(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _filterLabel(String value) {
    switch (value) {
      case 'limit=5':
        return 'History 5';
      case 'limit=20':
        return 'History 20';
      case 'days=7':
        return 'History 7d';
      case 'days=30':
        return 'History 30d';
      default:
        return 'History 10';
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _fallbackPracticeNeeds(
    List<Map<String, dynamic>> activities,
  ) {
    final needs = <Map<String, dynamic>>[];
    for (final activity in activities) {
      final total = (activity['first_try_total'] as num?)?.toInt() ?? 0;
      final correct = (activity['first_try_correct'] as num?)?.toInt() ?? 0;
      final guided = (activity['guided_rounds'] as num?)?.toInt() ?? 0;
      final misses = (total - correct).clamp(0, total);
      if (total == 0 || (misses == 0 && guided == 0)) continue;
      needs.add({
        'activity_id': activity['activity_id'],
        'activity_name': activity['activity_name'],
        'title': activity['activity_name'],
        'icon_key': 'practice',
        'first_try_misses': misses,
        'guided_rounds': guided,
        'observed_rounds': total,
        'priority_score': misses + (guided * 2),
        'evidence_text': guided > 0
            ? 'Needed help on $guided ${guided == 1 ? 'task' : 'tasks'}.'
            : '$misses ${misses == 1 ? 'task was' : 'tasks were'} not correct on the first try.',
        'practice_available': false,
        'practice_steps': const <Map<String, dynamic>>[],
      });
    }
    needs.sort(
      (a, b) => ((b['priority_score'] as num?) ?? 0).compareTo(
        (a['priority_score'] as num?) ?? 0,
      ),
    );
    return needs.take(3).toList();
  }

  IconData _parentAreaIcon(String? key) {
    switch (key) {
      case 'pictures':
        return Icons.image_search_rounded;
      case 'matching':
        return Icons.compare_arrows_rounded;
      case 'sorting':
        return Icons.category_rounded;
      case 'patterns':
        return Icons.grid_view_rounded;
      case 'memory':
        return Icons.psychology_alt_rounded;
      case 'letters':
        return Icons.text_fields_rounded;
      case 'listening':
        return Icons.hearing_rounded;
      case 'words':
        return Icons.spellcheck_rounded;
      case 'sentences':
        return Icons.short_text_rounded;
      case 'sequence':
        return Icons.format_list_numbered_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  Widget _buildAdaptiveInsightsTab() {
    final activities = _mapList(_adaptiveInsights?['activities']);
    final supportSummary = _adaptiveInsights?['support_summary'] is Map
        ? Map<String, dynamic>.from(
            _adaptiveInsights!['support_summary'] as Map,
          )
        : <String, dynamic>{};
    if (activities.isEmpty && supportSummary.isEmpty) {
      return _buildEmptyParentSupport();
    }

    var needsPractice = _mapList(supportSummary['needs_practice']);
    if (needsPractice.isEmpty) {
      needsPractice = _fallbackPracticeNeeds(activities);
    }
    final goingWell = _mapList(supportSummary['going_well']);
    final skillProgress = _mapList(supportSummary['skill_progress']);
    final coverage = supportSummary['coverage'] is Map
        ? Map<String, dynamic>.from(supportSummary['coverage'] as Map)
        : <String, dynamic>{};
    final homePractice = supportSummary['home_practice'] is Map
        ? Map<String, dynamic>.from(supportSummary['home_practice'] as Map)
        : <String, dynamic>{};
    final name = widget.studentData['first_name']?.toString() ?? 'Your child';
    final completed = (supportSummary['completed_tasks'] as num?)?.toInt() ?? 0;
    final independent =
        (supportSummary['independent_successes'] as num?)?.toInt() ?? 0;
    final supported =
        (supportSummary['supported_successes'] as num?)?.toInt() ?? 0;
    final checks =
        (supportSummary['confirmation_checks'] as num?)?.toInt() ?? 0;
    final summaryMessage = needsPractice.isEmpty
        ? '$name is managing the recent activities independently.'
        : '${needsPractice.length} ${needsPractice.length == 1 ? 'area is' : 'areas are'} ready for a little extra practice.';

    return RefreshIndicator(
      color: AppColors.calmBlue,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDDEEFF), Color(0xFFE7F5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.borderBlue),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x164A90D9),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LEARNING SUPPORT',
                    style: DashText.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.calmBlueDark,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  needsPractice.isEmpty
                      ? 'Learning is moving forward'
                      : 'A clear next step for $name',
                  style: DashText.heading(
                    fontSize: 26,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  summaryMessage,
                  style: DashText.body(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (completed > 0) ...[
                  const SizedBox(height: 7),
                  Text(
                    '$completed recent learning tasks reviewed',
                    style: DashText.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.calmBlueDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildParentMetric(
                  icon: Icons.favorite_rounded,
                  value: independent,
                  label: 'Independent',
                  color: AppColors.gentleGreen,
                  onTap: independent > 0
                      ? () => _showMetricBreakdown('independent')
                      : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildParentMetric(
                  icon: Icons.volunteer_activism_rounded,
                  value: supported,
                  label: 'Helped',
                  color: AppColors.warmAmber,
                  onTap: supported > 0
                      ? () => _showMetricBreakdown('helped')
                      : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildParentMetric(
                  icon: Icons.fact_check_rounded,
                  value: checks,
                  label: 'Checked again',
                  color: AppColors.calmBlue,
                  onTap: checks > 0
                      ? () => _showMetricBreakdown('checked')
                      : null,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showLearningSupportGuide,
              icon: const Icon(Icons.help_outline_rounded, size: 17),
              label: Text(
                'What do these mean?',
                style: DashText.button(
                  fontSize: 12,
                  color: AppColors.calmBlueDark,
                ),
              ),
            ),
          ),
          if (skillProgress.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildParentSectionTitle(
              title: 'Learning across skills',
              subtitle: _coverageText(coverage),
            ),
            const SizedBox(height: 12),
            _buildSkillProgressPanel(skillProgress),
          ],
          const SizedBox(height: 28),
          _buildParentSectionTitle(
            title: needsPractice.isEmpty
                ? 'No urgent practice right now'
                : 'Needs a little practice',
            subtitle: needsPractice.isEmpty
                ? 'Recent tasks did not show a repeated need for help.'
                : 'Based on first attempts and help used in recent activities.',
          ),
          const SizedBox(height: 12),
          if (needsPractice.isEmpty)
            _buildCalmStatusCard()
          else
            ...needsPractice.map(_buildPracticeNeedCard),
          if (goingWell.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildParentSectionTitle(
              title: 'Going well',
              subtitle: 'Areas completed independently in recent activities.',
            ),
            const SizedBox(height: 12),
            ...goingWell.map(_buildGoingWellCard),
          ],
          if (homePractice.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildParentSectionTitle(
              title: 'Try together at home',
              subtitle: 'A calm five-minute activity with no score.',
            ),
            const SizedBox(height: 12),
            _buildHomePracticeCard(homePractice),
          ],
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _showRecentLearningSheet(activities),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                foregroundColor: AppColors.calmBlueDark,
                side: const BorderSide(color: AppColors.borderBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.history_rounded),
              label: Text(
                'View recent learning details',
                style: DashText.button(
                  fontSize: 14,
                  color: AppColors.calmBlueDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyParentSupport() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.borderBlue),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  color: AppColors.slateBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  color: AppColors.calmBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Learning insights will appear here',
                textAlign: TextAlign.center,
                style: DashText.heading(fontSize: 20),
              ),
              const SizedBox(height: 7),
              Text(
                'After your child completes an activity, you will see what is going well and one clear area to practise next.',
                textAlign: TextAlign.center,
                style: DashText.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentMetric({
    required IconData icon,
    required int value,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 128),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: DashText.heading(fontSize: 24, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: DashText.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 7),
              if (onTap != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: DashText.caption(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: color),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _coverageText(Map<String, dynamic> coverage) {
    final tried = (coverage['activities_tried'] as num?)?.toInt() ?? 0;
    final available = (coverage['activities_available'] as num?)?.toInt() ?? 0;
    final completed = (coverage['activities_completed'] as num?)?.toInt() ?? 0;
    if (available == 0) return 'Progress from activities your child has tried.';
    return '$tried of $available activity areas tried · $completed completed';
  }

  Widget _buildSkillProgressPanel(List<Map<String, dynamic>> skills) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderBlue),
      ),
      child: Column(
        children: skills.map((skill) {
          final observed = (skill['observed_tasks'] as num?)?.toInt() ?? 0;
          final firstTry = (skill['first_try_successes'] as num?)?.toInt() ?? 0;
          final progress = observed == 0
              ? 0.0
              : (firstTry / observed).clamp(0.0, 1.0);
          final helped = (skill['helped_tasks'] as num?)?.toInt() ?? 0;
          final title = skill['title']?.toString() ?? 'Learning skill';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: const BoxDecoration(
                    color: AppColors.slateBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _parentAreaIcon(skill['icon_key']?.toString()),
                    size: 21,
                    color: AppColors.calmBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: DashText.heading(fontSize: 14),
                            ),
                          ),
                          Text(
                            skill['status']?.toString() ?? '',
                            style: DashText.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: progress >= 0.8
                                  ? AppColors.gentleGreenDark
                                  : AppColors.warmAmber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: AppColors.slateBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 0.8
                                ? AppColors.gentleGreen
                                : AppColors.calmBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$firstTry of $observed first try · $helped helped',
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
          );
        }).toList(),
      ),
    );
  }

  Widget _buildParentSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DashText.heading(fontSize: 21)),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: DashText.caption(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildHomePracticeCard(Map<String, dynamic> homePractice) {
    final minutes = (homePractice['minutes'] as num?)?.toInt() ?? 5;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4DD), Color(0xFFFFFAEF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.warmAmberLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warmAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.home_rounded, color: AppColors.warmAmber),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homePractice['title']?.toString() ?? 'Short home practice',
                  style: DashText.heading(fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  homePractice['instruction']?.toString() ?? '',
                  style: DashText.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$minutes minutes · no score needed',
                    style: DashText.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmAmber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMetricBreakdown(String metric) async {
    const meanings = {
      'independent': (
        'Independent',
        'Your child completed the task correctly on the first try without an app hint. It does not mean they must always work alone.',
        Icons.favorite_rounded,
        AppColors.gentleGreen,
      ),
      'helped': (
        'Helped',
        'Your child completed the task after the app gave support, such as another try, fewer choices, a highlight, or repeated audio. This is successful learning with help—not failure.',
        Icons.volunteer_activism_rounded,
        AppColors.warmAmber,
      ),
      'checked': (
        'Checked again',
        'After support, the app used a different task to see whether your child could use the same learning again.',
        Icons.fact_check_rounded,
        AppColors.calmBlue,
      ),
    };
    final meaning = meanings[metric]!;
    final supportSummary = _adaptiveInsights?['support_summary'] is Map
        ? Map<String, dynamic>.from(
            _adaptiveInsights!['support_summary'] as Map,
          )
        : <String, dynamic>{};
    final metricDetails = supportSummary['metric_details'] is Map
        ? Map<String, dynamic>.from(supportSummary['metric_details'] as Map)
        : <String, dynamic>{};
    var details = _mapList(metricDetails[metric]);
    var usingCompatibilityDetails = false;
    if (details.isEmpty) {
      details = _fallbackMetricDetails(metric);
      usingCompatibilityDetails = details.isNotEmpty;
    }
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final detail in details) {
      final skillNumber = (detail['skill_number'] as num?)?.toInt();
      if (skillNumber != null) {
        grouped.putIfAbsent(skillNumber, () => []).add(detail);
      }
    }
    final skillNumbers = grouped.keys.toList()..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              24 + MediaQuery.of(sheetContext).padding.bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: meaning.$4.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(meaning.$3, color: meaning.$4, size: 26),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meaning.$1, style: DashText.heading(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          meaning.$2,
                          style: DashText.body(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                details.isEmpty
                    ? 'No matching tasks in the current activity history.'
                    : '${details.length} ${details.length == 1 ? 'task' : 'tasks'} across ${skillNumbers.length} ${skillNumbers.length == 1 ? 'skill' : 'skills'}',
                style: DashText.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              if (usingCompatibilityDetails) ...[
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.slateBg.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 17,
                        color: AppColors.calmBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing the matching core tasks from the child\'s saved activity journey.',
                          style: DashText.caption(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ...skillNumbers.map(
                (skillNumber) => _buildMetricSkillDropdown(
                  skillNumber,
                  grouped[skillNumber]!,
                  meaning.$4,
                ),
              ),
              if (metric == 'checked' && details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.slateBg.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'A checked-again task can also appear under Independent or Helped, depending on how your child completed it.',
                    style: DashText.caption(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _fallbackMetricDetails(String metric) {
    final activities = _mapList(_adaptiveInsights?['activities']);
    final details = <Map<String, dynamic>>[];
    const skillTitles = {
      1: ('Pictures', 'pictures'),
      2: ('Letters', 'letters'),
      3: ('Words', 'words'),
      4: ('Sentences', 'sentences'),
    };
    for (final activity in activities) {
      final activityId = activity['activity_id']?.toString() ?? '';
      final parts = activityId.split('.');
      final skillNumber = parts.isNotEmpty ? int.tryParse(parts.first) : null;
      if (skillNumber == null || !skillTitles.containsKey(skillNumber)) {
        continue;
      }
      final journey = _mapList(activity['round_journey']);
      for (final round in journey) {
        final firstTry = round['was_first_try'] == true;
        final neededSupport = round['needed_remediation'] == true;
        final include = switch (metric) {
          'independent' => firstTry && !neededSupport,
          'helped' => !firstTry || neededSupport,
          'checked' => neededSupport,
          _ => false,
        };
        if (!include) continue;
        final roundNumber = (round['round_number'] as num?)?.toInt();
        final skill = skillTitles[skillNumber]!;
        details.add({
          'skill_number': skillNumber,
          'skill_title': skill.$1,
          'skill_icon_key': skill.$2,
          'activity_id': activityId,
          'activity_name':
              activity['activity_name']?.toString() ?? 'Learning activity',
          'task_number': roundNumber,
          'task_label': roundNumber == null ? 'Task' : 'Task $roundNumber',
          'task_kind': metric == 'checked'
              ? 'Fresh check after support'
              : 'Learning task',
          'detail': metric == 'independent'
              ? 'Correct on the first try without an app hint.'
              : metric == 'helped'
              ? 'Completed after the app provided learning support.'
              : 'The app checked this learning again after support.',
        });
      }
    }
    return details;
  }

  Widget _buildMetricSkillDropdown(
    int skillNumber,
    List<Map<String, dynamic>> details,
    Color color,
  ) {
    final skillTitle = details.first['skill_title']?.toString() ?? 'Learning';
    final activities = <String, List<Map<String, dynamic>>>{};
    for (final detail in details) {
      final activityId = detail['activity_id']?.toString() ?? '';
      activities.putIfAbsent(activityId, () => []).add(detail);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _parentAreaIcon(details.first['skill_icon_key']?.toString()),
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            'Skill $skillNumber · $skillTitle',
            style: DashText.heading(fontSize: 14),
          ),
          subtitle: Text(
            '${details.length} ${details.length == 1 ? 'task' : 'tasks'}',
            style: DashText.caption(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          iconColor: color,
          collapsedIconColor: AppColors.textSecondary,
          children: activities.values
              .map((rows) => _buildMetricActivityGroup(rows, color))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildMetricActivityGroup(
    List<Map<String, dynamic>> rows,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rows.first['activity_name']?.toString() ?? 'Learning activity',
            style: DashText.heading(fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      row['task_label']?.toString() ?? 'Task',
                      textAlign: TextAlign.center,
                      style: DashText.caption(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['task_kind']?.toString() ?? 'Learning task',
                          style: DashText.caption(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          row['detail']?.toString() ?? '',
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
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLearningSupportGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          22 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'How to read this page',
                style: DashText.heading(fontSize: 22),
              ),
              const SizedBox(height: 16),
              _buildGuideRow(
                Icons.favorite_rounded,
                AppColors.gentleGreen,
                'Independent',
                'Correct on the first try without an app hint.',
              ),
              _buildGuideRow(
                Icons.volunteer_activism_rounded,
                AppColors.warmAmber,
                'Helped',
                'Completed after the app gave learning support.',
              ),
              _buildGuideRow(
                Icons.fact_check_rounded,
                AppColors.calmBlue,
                'Checked again',
                'A different task checked the same learning after help.',
              ),
              const SizedBox(height: 8),
              Text(
                'These are learning observations, not marks, rankings, or a diagnosis.',
                style: DashText.caption(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideRow(
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DashText.heading(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: DashText.body(
                    fontSize: 13,
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

  Widget _buildPracticeNeedCard(Map<String, dynamic> need) {
    final title =
        need['title']?.toString() ??
        need['activity_name']?.toString() ??
        'Practice activity';
    final evidence = need['evidence_text']?.toString() ?? '';
    final available = need['practice_available'] == true;
    final savedRound = _savedParentPracticeRound(need);
    final canResume = savedRound > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.warmAmberLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0FE8A54B),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warmAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _parentAreaIcon(need['icon_key']?.toString()),
                  color: AppColors.warmAmber,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DashText.heading(fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(
                      evidence,
                      style: DashText.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.creamDark.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  available
                      ? Icons.verified_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 18,
                  color: available ? AppColors.gentleGreen : AppColors.calmBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    canResume
                        ? 'Practice saved after task $savedRound. Continue when your child is ready.'
                        : available
                        ? 'Reviewed support task and fresh check are available.'
                        : 'Open the reviewed activity for another calm practice.',
                    style: DashText.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPracticePlan(need),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: canResume
                    ? AppColors.warmAmber
                    : AppColors.calmBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                canResume
                    ? Icons.play_circle_fill_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                canResume
                    ? 'Continue from task ${savedRound + 1}'
                    : 'See practice plan',
                style: DashText.button(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _savedParentPracticeRound(Map<String, dynamic> need) {
    final parts = (need['activity_id']?.toString() ?? '').split('.');
    if (parts.length != 2) return 0;
    final skillNumber = int.tryParse(parts[0]);
    final activityNumber = int.tryParse(parts[1]);
    if (skillNumber == null || activityNumber == null) return 0;
    return ProgressService().getActivityState(
      'skill_$skillNumber',
      'parent_practice_act_$activityNumber',
    );
  }

  Widget _buildGoingWellCard(Map<String, dynamic> area) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.gentleGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGreen),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.mintBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _parentAreaIcon(area['icon_key']?.toString()),
              color: AppColors.gentleGreenDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area['title']?.toString() ?? 'Learning activity',
                  style: DashText.heading(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  area['evidence_text']?.toString() ??
                      'Completed independently.',
                  style: DashText.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.gentleGreen),
        ],
      ),
    );
  }

  Widget _buildCalmStatusCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.gentleGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGreen),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.gentleGreen,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Continue with the next normal activity. The app will keep checking learning as your child progresses.',
              style: DashText.body(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPracticePlan(Map<String, dynamic> need) async {
    final canOpen = (need['activity_id']?.toString() ?? '').isNotEmpty;
    final savedRound = _savedParentPracticeRound(need);
    final canResume = savedRound > 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          22 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                need['title']?.toString() ?? 'Practice plan',
                style: DashText.heading(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                need['evidence_text']?.toString() ?? '',
                style: DashText.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                canResume
                    ? 'Your child stopped before finishing. Continue from task ${savedRound + 1}; completed practice tasks will not repeat.'
                    : 'This opens a fresh version of the full activity. Every round uses a reviewed task of the same difficulty instead of repeating the original core task.',
                style: DashText.caption(
                  fontSize: 12,
                  color: AppColors.calmBlueDark,
                ),
              ),
              const SizedBox(height: 18),
              _buildPracticeStep(
                number: '1',
                title: 'Fresh tasks at the same level',
                subtitle:
                    'The full activity uses reviewed confirmation tasks instead of repeating the original questions.',
                color: AppColors.warmAmber,
              ),
              const SizedBox(height: 10),
              _buildPracticeStep(
                number: '2',
                title: 'Safe extra practice',
                subtitle:
                    'This session does not change the child\'s normal skill position or mastery estimate.',
                color: AppColors.gentleGreen,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slateBg.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'This suggestion is based on your child\'s recent first tries and the help the app gave.',
                  style: DashText.caption(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canOpen
                      ? () {
                          Navigator.pop(sheetContext);
                          _navigateToPracticeActivity(need);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canResume
                        ? AppColors.warmAmber
                        : AppColors.calmBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    canResume
                        ? Icons.play_circle_fill_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    canResume
                        ? 'Continue from task ${savedRound + 1}'
                        : 'Start fresh practice',
                    style: DashText.button(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeStep({
    required String number,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: DashText.heading(fontSize: 16, color: color),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DashText.heading(fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: DashText.caption(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToPracticeActivity(Map<String, dynamic> need) async {
    final parts = (need['activity_id']?.toString() ?? '').split('.');
    if (parts.length != 2) return;
    final skillNumber = int.tryParse(parts[0]);
    final activityNumber = int.tryParse(parts[1]);
    if (skillNumber == null || activityNumber == null) return;
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/curriculum/skill_$skillNumber.json',
      );
      final detail = SkillDetail.fromJson(
        json.decode(jsonString),
        'skill_$skillNumber',
        'Skill $skillNumber',
      );
      ActivityNode? activity;
      for (final candidate in detail.activities) {
        if (candidate.id == 'act_$activityNumber') {
          activity = candidate;
          break;
        }
      }
      if (activity == null || !mounted) return;
      activity.skillId = 'skill_$skillNumber';
      activity.skillTitle = detail.title;
      final practiceActivity = activity.asParentPractice();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameFactory.buildGame(
            practiceActivity,
            studentData: widget.studentData,
          ),
        ),
      );
      if (mounted) await _loadAllData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this activity: $error')),
      );
    }
  }

  Future<void> _showRecentLearningSheet(
    List<Map<String, dynamic>> activities,
  ) async {
    final activitiesBySkill = <int, List<Map<String, dynamic>>>{};
    for (final activity in activities) {
      final activityId = activity['activity_id']?.toString() ?? '';
      final skillNumber = int.tryParse(activityId.split('.').first);
      if (skillNumber != null) {
        activitiesBySkill.putIfAbsent(skillNumber, () => []).add(activity);
      }
    }
    final skillNumbers = activitiesBySkill.keys.toList()..sort();
    const skillNames = {
      1: 'Pictures',
      2: 'Letters',
      3: 'Words',
      4: 'Sentences',
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Recent learning details',
                style: DashText.heading(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                'Latest observed attempt for each activity.',
                style: DashText.caption(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ...skillNumbers.expand((skillNumber) {
                final skillActivities = activitiesBySkill[skillNumber]!;
                return <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.calmBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.calmBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$skillNumber',
                            style: DashText.heading(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Skill $skillNumber · ${skillNames[skillNumber] ?? 'Learning'}',
                            style: DashText.heading(fontSize: 16),
                          ),
                        ),
                        Text(
                          '${skillActivities.length}',
                          style: DashText.caption(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.calmBlueDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...skillActivities.map(_buildRecentActivityCard),
                  const SizedBox(height: 8),
                ];
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(Map<String, dynamic> activity) {
    final total = (activity['first_try_total'] as num?)?.toInt() ?? 0;
    final correct = (activity['first_try_correct'] as num?)?.toInt() ?? 0;
    final guided = (activity['guided_rounds'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.slateBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.calmBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['activity_name']?.toString() ?? 'Activity',
                  style: DashText.heading(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '$correct of $total first try · $guided helped',
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
    );
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
    );
  }
}
