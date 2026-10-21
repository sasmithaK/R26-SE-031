import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/therapist_dashboard_service.dart';
import '../../widgets/app_loading_indicator.dart';

class TherapistAdaptiveEvidenceView extends StatefulWidget {
  const TherapistAdaptiveEvidenceView({
    super.key,
    required this.student,
    this.initialData,
  });

  final Map<String, dynamic> student;
  final Map<String, dynamic>? initialData;

  @override
  State<TherapistAdaptiveEvidenceView> createState() =>
      _TherapistAdaptiveEvidenceViewState();
}

class _TherapistAdaptiveEvidenceViewState
    extends State<TherapistAdaptiveEvidenceView> {
  final _service = TherapistDashboardService();
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;
  String? _selectedSkill;

  String get _studentId =>
      widget.student['student_id']?.toString() ??
      widget.student['id']?.toString() ??
      widget.student['_id']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    if (_data == null) _load();
  }

  @override
  void didUpdateWidget(covariant TherapistAdaptiveEvidenceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != null &&
        !identical(widget.initialData, oldWidget.initialData)) {
      _data = widget.initialData;
      _error = null;
    }
  }

  Future<void> _load() async {
    if (_studentId.isEmpty) {
      setState(() => _error = 'This learner has no valid student identifier.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getC4Adaptive(_studentId, window: 100);
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null && _data == null) {
      return _ErrorPanel(message: _error!, onRetry: _load);
    }

    final data = _data ?? const <String, dynamic>{};
    final summary = _map(data['summary']);
    final skills = _list(data['skills']);
    final activities = _list(data['activities']);
    final support = _list(data['support_effectiveness']);
    final targets = _list(data['recurring_targets']);
    final visibleActivities = _selectedSkill == null
        ? activities
        : activities
              .where((row) => row['skill_id']?.toString() == _selectedSkill)
              .toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: _Palette.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: [
          _DashboardHeader(onRefresh: _load, refreshing: _loading),
          const SizedBox(height: 18),
          _PortfolioSummary(summary: summary),
          const SizedBox(height: 26),
          const _SectionHeader(
            title: 'Skill overview',
            subtitle:
                'All observed learning domains. Select a skill to inspect its activities and task evidence.',
          ),
          const SizedBox(height: 12),
          ...skills.map(
            (skill) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _SkillOverviewCard(
                skill: skill,
                selected: _selectedSkill == skill['skill_id']?.toString(),
                onTap: () => _openSkill(skill, activities),
                onFilter: () {
                  final id = skill['skill_id']?.toString();
                  setState(
                    () => _selectedSkill = _selectedSkill == id ? null : id,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 17),
          _ActivitySectionHeader(
            selectedSkill: _selectedSkill,
            skills: skills,
            activityCount: visibleActivities.length,
            onClear: () => setState(() => _selectedSkill = null),
          ),
          const SizedBox(height: 12),
          if (visibleActivities.isEmpty)
            const _EmptyCard(
              icon: Icons.fact_check_outlined,
              title: 'No completed activity evidence yet',
              detail:
                  'An activity will appear after the learner completes its first recorded task.',
            )
          else
            ...visibleActivities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActivityEvidenceCard(
                  activity: activity,
                  onTap: () => _openActivity(activity),
                ),
              ),
            ),
          if (support.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionHeader(
              title: 'Response to app support',
              subtitle:
                  'How often each support was followed by an independently correct response. Small samples remain marked as early evidence.',
            ),
            const SizedBox(height: 12),
            _SupportResponsePanel(rows: support),
          ],
          if (targets.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Recurring learning targets',
              subtitle:
                  'Letters, words, or images recorded in more than one struggle event.',
            ),
            const SizedBox(height: 12),
            _RecurringTargetPanel(targets: targets),
          ],
        ],
      ),
    );
  }

  Future<void> _openSkill(
    Map<String, dynamic> skill,
    List<Map<String, dynamic>> activities,
  ) async {
    final skillActivities = activities
        .where(
          (activity) =>
              activity['skill_id']?.toString() == skill['skill_id']?.toString(),
        )
        .toList();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SkillEvidencePage(
          skill: skill,
          activities: skillActivities,
          onOpenActivity: _openActivityFromNestedPage,
        ),
      ),
    );
  }

  Future<void> _openActivityFromNestedPage(
    BuildContext context,
    Map<String, dynamic> activity,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ActivityEvidencePage(activity: activity),
    ),
  );

  Future<void> _openActivity(Map<String, dynamic> activity) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ActivityEvidencePage(activity: activity),
        ),
      );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onRefresh, required this.refreshing});
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adaptive learning overview', style: _display(25)),
            const SizedBox(height: 5),
            Text(
              'Observed performance across skills, activities, and learning checks.',
              style: _body(12.5),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      _RoundIconButton(
        icon: refreshing ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
        tooltip: 'Refresh evidence',
        onTap: refreshing ? null : onRefresh,
      ),
    ],
  );
}

class _PortfolioSummary extends StatelessWidget {
  const _PortfolioSummary({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final core = _integer(summary['all_core_tasks']);
    final independent = _integer(summary['all_independent_core_tasks']);
    final supported = _integer(summary['all_supported_core_tasks']);
    final checks = _integer(summary['all_confirmation_tasks']);
    final passedChecks = _integer(summary['all_independent_confirmations']);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panel(
        radius: 26,
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF5FF), Color(0xFFF2FAF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: const Color(0xFFBADAF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: _Palette.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Learner evidence portfolio', style: _label(16)),
                    Text(
                      '${_integer(summary['observed_activities'])} of 19 activities observed',
                      style: _body(11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _OverviewMetric(
                    width: width,
                    icon: Icons.task_alt_rounded,
                    value: '$core',
                    label: 'Core tasks observed',
                    color: _Palette.navy,
                  ),
                  _OverviewMetric(
                    width: width,
                    icon: Icons.auto_awesome_rounded,
                    value: '$independent',
                    label: 'Independent first responses',
                    color: _Palette.green,
                  ),
                  _OverviewMetric(
                    width: width,
                    icon: Icons.volunteer_activism_rounded,
                    value: '$supported',
                    label: 'Tasks needing support',
                    color: _Palette.amber,
                  ),
                  _OverviewMetric(
                    width: width,
                    icon: Icons.verified_rounded,
                    value: '$passedChecks / $checks',
                    label: 'Fresh checks passed independently',
                    color: _Palette.blue,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final double width;
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    constraints: const BoxConstraints(minHeight: 92),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .84),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(height: 7),
        Text(value, style: _display(19, color: color)),
        const SizedBox(height: 2),
        Text(label, style: _body(9.5, height: 1.25)),
      ],
    ),
  );
}

class _SkillOverviewCard extends StatelessWidget {
  const _SkillOverviewCard({
    required this.skill,
    required this.selected,
    required this.onTap,
    required this.onFilter,
  });
  final Map<String, dynamic> skill;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final id = skill['skill_id']?.toString() ?? '';
    final mastery = _number(skill['average_mastery']);
    final attempted = _integer(skill['activities_attempted']);
    final total = _integer(skill['activities_total']);
    final core = _integer(skill['core_tasks']);
    final independent = _integer(skill['independent_core_tasks']);
    final color = _skillColor(id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: _panel(
            radius: 23,
            border: selected ? color : _Palette.line,
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_skillIcon(id), color: color, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill['skill_name']?.toString() ?? 'Learning skill',
                      style: _sinhala(13.5, FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$attempted of $total activities observed · $independent of $core core tasks independent',
                      style: _body(10, height: 1.35),
                    ),
                    const SizedBox(height: 9),
                    _MasteryBar(value: mastery, color: color),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _percent(mastery),
                    style: _display(
                      19,
                      color: mastery == null ? _Palette.muted : color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: .15)
                            : const Color(0xFFF3F5F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        selected ? 'Showing' : 'Filter',
                        style: _label(8.5, color: color),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: _Palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySectionHeader extends StatelessWidget {
  const _ActivitySectionHeader({
    required this.selectedSkill,
    required this.skills,
    required this.activityCount,
    required this.onClear,
  });
  final String? selectedSkill;
  final List<Map<String, dynamic>> skills;
  final int activityCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selected;
    for (final skill in skills) {
      if (skill['skill_id']?.toString() == selectedSkill) selected = skill;
    }
    return Row(
      children: [
        Expanded(
          child: _SectionHeader(
            title: selected == null
                ? 'Observed activities'
                : selected['skill_name']?.toString() ?? 'Observed activities',
            subtitle:
                '$activityCount activities with recorded learner evidence.',
          ),
        ),
        if (selected != null)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Show all'),
            style: TextButton.styleFrom(foregroundColor: _Palette.blue),
          ),
      ],
    );
  }
}

class _ActivityEvidenceCard extends StatelessWidget {
  const _ActivityEvidenceCard({required this.activity, required this.onTap});
  final Map<String, dynamic> activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mastery = _number(activity['mastery']);
    final core = _integer(activity['core_tasks']);
    final independent = _integer(activity['independent_core_tasks']);
    final supported = _integer(activity['supported_core_tasks']);
    final checks = _integer(activity['confirmation_tasks']);
    final passed = _integer(activity['independent_confirmations']);
    final color = _masteryColor(mastery);
    final attempts = activity['task_attempts'] is List
        ? (activity['task_attempts'] as List).length
        : 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: _panel(radius: 23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.extension_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['activity_name']?.toString() ?? 'Activity',
                          style: _sinhala(12.5, FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activity['knowledge_component_name']?.toString() ??
                              'Learning area',
                          style: _body(10),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _percent(mastery),
                        style: _display(19, color: color),
                      ),
                      Text(
                        _masteryLabel(mastery),
                        style: _label(8.5, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _Palette.muted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _MasteryBar(value: mastery, color: color),
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _EvidencePill(
                    icon: Icons.auto_awesome_rounded,
                    label: '$independent / $core independent',
                    color: _Palette.green,
                  ),
                  _EvidencePill(
                    icon: Icons.volunteer_activism_rounded,
                    label: '$supported supported',
                    color: _Palette.amber,
                  ),
                  _EvidencePill(
                    icon: Icons.verified_rounded,
                    label: '$passed / $checks checks',
                    color: _Palette.blue,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: _Palette.muted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '$attempts recorded task events · ${_relativeTime(activity['last_observed_at'])}',
                      style: _body(9.5),
                    ),
                  ),
                  Text(
                    'View activity',
                    style: _label(9.5, color: _Palette.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillEvidencePage extends StatelessWidget {
  const _SkillEvidencePage({
    required this.skill,
    required this.activities,
    required this.onOpenActivity,
  });
  final Map<String, dynamic> skill;
  final List<Map<String, dynamic>> activities;
  final Future<void> Function(BuildContext, Map<String, dynamic>)
  onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final id = skill['skill_id']?.toString() ?? '';
    final color = _skillColor(id);
    final mastery = _number(skill['average_mastery']);
    return _DetailScaffold(
      title: skill['skill_name']?.toString() ?? 'Skill evidence',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _panel(
              radius: 26,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: .13), Colors.white],
              ),
              border: color.withValues(alpha: .25),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CustomPaint(
                    painter: _RingPainter(value: mastery, color: color),
                    child: Center(
                      child: Text(
                        _percent(mastery),
                        style: _display(18, color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Average current estimate', style: _label(15)),
                      const SizedBox(height: 5),
                      Text(
                        '${_integer(skill['activities_attempted'])} of ${_integer(skill['activities_total'])} activities observed',
                        style: _body(11),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_integer(skill['independent_core_tasks'])} independent · ${_integer(skill['supported_core_tasks'])} supported',
                        style: _label(10, color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Activity and KC evidence',
            subtitle:
                'Each activity updates its own knowledge component. Select one to inspect its task history.',
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const _EmptyCard(
              icon: Icons.hourglass_empty_rounded,
              title: 'No activities observed',
              detail: 'This skill has not produced learner evidence yet.',
            )
          else
            ...activities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActivityEvidenceCard(
                  activity: activity,
                  onTap: () => onOpenActivity(context, activity),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityEvidencePage extends StatefulWidget {
  const _ActivityEvidencePage({required this.activity});
  final Map<String, dynamic> activity;

  @override
  State<_ActivityEvidencePage> createState() => _ActivityEvidencePageState();
}

class _ActivityEvidencePageState extends State<_ActivityEvidencePage> {
  String _filter = 'ALL';
  String? _selectedAttemptKey;

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final mastery = _number(activity['mastery']);
    final color = _masteryColor(mastery);
    final trend = _list(activity['trend']);
    final allTasks = _list(activity['task_attempts']);
    final attempts = _activityAttempts(allTasks);
    if (attempts.isNotEmpty &&
        !attempts.any(
          (attempt) => attempt['key']?.toString() == _selectedAttemptKey,
        )) {
      _selectedAttemptKey = attempts.first['key']?.toString();
    }
    final selectedAttempt = attempts.isEmpty
        ? const <String, dynamic>{}
        : attempts.firstWhere(
            (attempt) => attempt['key']?.toString() == _selectedAttemptKey,
            orElse: () => attempts.first,
          );
    final attemptTasks = _list(selectedAttempt['tasks']);
    final tasks = attemptTasks.where((task) {
      if (_filter == 'ALL') return true;
      if (_filter == 'INDEPENDENT') {
        return task['completed_independently'] == true;
      }
      if (_filter == 'SUPPORTED') {
        return _integer(task['scaffold_level']) > 0 ||
            (task['support_actions'] is List &&
                (task['support_actions'] as List).isNotEmpty);
      }
      if (_filter == 'REVIEW') return task['first_response_correct'] == false;
      return task['role']?.toString() == _filter;
    }).toList();
    return _DetailScaffold(
      title: activity['activity_name']?.toString() ?? 'Activity evidence',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
        children: [
          Text(
            activity['skill_name']?.toString() ?? '',
            style: _sinhala(10, FontWeight.w700, color: _Palette.blue),
          ),
          const SizedBox(height: 5),
          Text(
            activity['activity_name']?.toString() ?? 'Activity',
            style: _sinhala(22, FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Knowledge component · ${activity['knowledge_component_name'] ?? 'Unavailable'}',
            style: _body(11),
          ),
          const SizedBox(height: 17),
          _ActivityMasteryPanel(
            activity: activity,
            trend: trend,
            mastery: mastery,
            color: color,
          ),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: 'Task evidence',
            subtitle:
                'One activity attempt is shown at a time. Core, remediation, and confirmation events remain separately labelled.',
          ),
          const SizedBox(height: 11),
          if (attempts.isNotEmpty) ...[
            _AttemptSelector(
              attempts: attempts,
              selectedKey: _selectedAttemptKey!,
              onChanged: (value) => setState(() {
                _selectedAttemptKey = value;
                _filter = 'ALL';
              }),
            ),
            const SizedBox(height: 12),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  value: 'ALL',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Core',
                  value: 'CORE',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Remediation',
                  value: 'REMEDIATION',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Confirmation',
                  value: 'CONFIRMATION',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Independent',
                  value: 'INDEPENDENT',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Used support',
                  value: 'SUPPORTED',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Needs review',
                  value: 'REVIEW',
                  selected: _filter,
                  onTap: _setFilter,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const _EmptyCard(
              icon: Icons.filter_alt_off_rounded,
              title: 'No matching task evidence',
              detail: 'Choose another filter to view the recorded tasks.',
            )
          else
            ...tasks.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskEvidenceCard(
                  task: entry.value,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _TaskReplayPage(
                        activity: activity,
                        tasks: tasks,
                        initialIndex: entry.key,
                        attemptLabel:
                            selectedAttempt['label']?.toString() ??
                            'Activity attempt',
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _setFilter(String value) => setState(() => _filter = value);
}

class _AttemptSelector extends StatelessWidget {
  const _AttemptSelector({
    required this.attempts,
    required this.selectedKey,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> attempts;
  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = attempts.firstWhere(
      (attempt) => attempt['key']?.toString() == selectedKey,
      orElse: () => attempts.first,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 7, 11),
      decoration: _panel(radius: 19, border: const Color(0xFFBEDCF7)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.replay_circle_filled_rounded,
              color: _Palette.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected['label']?.toString() ?? 'Activity attempt',
                  style: _label(12),
                ),
                const SizedBox(height: 3),
                Text(selected['detail']?.toString() ?? '', style: _body(9.5)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Choose activity attempt',
            initialValue: selectedKey,
            onSelected: onChanged,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _Palette.blue,
            ),
            itemBuilder: (context) => attempts
                .map(
                  (attempt) => PopupMenuItem<String>(
                    value: attempt['key']?.toString(),
                    child: Row(
                      children: [
                        Icon(
                          attempt['key']?.toString() == selectedKey
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _Palette.blue,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                attempt['label']?.toString() ??
                                    'Activity attempt',
                                style: _label(10.5),
                              ),
                              Text(
                                attempt['detail']?.toString() ?? '',
                                style: _body(8.5),
                              ),
                            ],
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
}

class _ActivityMasteryPanel extends StatelessWidget {
  const _ActivityMasteryPanel({
    required this.activity,
    required this.trend,
    required this.mastery,
    required this.color,
  });
  final Map<String, dynamic> activity;
  final List<Map<String, dynamic>> trend;
  final double? mastery;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: _panel(radius: 25, border: color.withValues(alpha: .25)),
    child: Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: CustomPaint(
                painter: _RingPainter(value: mastery, color: color),
                child: Center(
                  child: Text(
                    _percent(mastery),
                    style: _display(16, color: color),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activity-linked KC estimate', style: _label(14)),
                  const SizedBox(height: 4),
                  Text(
                    '${_integer(activity['observations'])} mastery observations across ${_integer(activity['session_count'])} sessions',
                    style: _body(10.5),
                  ),
                  const SizedBox(height: 8),
                  Text(_masteryLabel(mastery), style: _label(10, color: color)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        SizedBox(
          height: 145,
          width: double.infinity,
          child: trend.length < 2
              ? Center(
                  child: Text(
                    'More evidence is needed to show change.',
                    style: _body(10.5),
                  ),
                )
              : CustomPaint(painter: _CompactTrendPainter(points: trend)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _EvidencePill(
              icon: Icons.auto_awesome_rounded,
              label:
                  '${_integer(activity['independent_core_tasks'])} independent core',
              color: _Palette.green,
            ),
            _EvidencePill(
              icon: Icons.volunteer_activism_rounded,
              label:
                  '${_integer(activity['supported_core_tasks'])} supported core',
              color: _Palette.amber,
            ),
            _EvidencePill(
              icon: Icons.verified_rounded,
              label:
                  '${_integer(activity['independent_confirmations'])}/${_integer(activity['confirmation_tasks'])} fresh checks',
              color: _Palette.blue,
            ),
          ],
        ),
      ],
    ),
  );
}

class _TaskEvidenceCard extends StatelessWidget {
  const _TaskEvidenceCard({required this.task, required this.onTap});
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = task['role']?.toString() ?? 'CORE';
    final correct = task['first_response_correct'] == true;
    final color = correct ? _Palette.green : _Palette.coral;
    final preview = _map(task['preview']);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: _panel(radius: 20),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  correct ? Icons.check_rounded : Icons.close_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _RoleBadge(role: role),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            task['item_id']?.toString() ?? 'Recorded task',
                            style: _label(11.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview['prompt']?.toString() ?? 'Task response',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _sinhala(10.5, FontWeight.w500),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      correct
                          ? 'Correct on the first independent response'
                          : 'First independent response was incorrect',
                      style: _label(9, color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Column(
                children: [
                  if (_integer(task['scaffold_level']) > 0)
                    const Icon(
                      Icons.lightbulb_rounded,
                      color: _Palette.amber,
                      size: 18,
                    ),
                  const SizedBox(height: 5),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _Palette.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskReplayPage extends StatefulWidget {
  const _TaskReplayPage({
    required this.activity,
    required this.tasks,
    required this.initialIndex,
    required this.attemptLabel,
  });
  final Map<String, dynamic> activity;
  final List<Map<String, dynamic>> tasks;
  final int initialIndex;
  final String attemptLabel;

  @override
  State<_TaskReplayPage> createState() => _TaskReplayPageState();
}

class _TaskReplayPageState extends State<_TaskReplayPage> {
  late int _index = widget.initialIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showTask(int index) {
    setState(() => _index = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.tasks[_index];
    final preview = _map(task['preview']);
    final firstCorrect = task['first_response_correct'] == true;
    final color = firstCorrect ? _Palette.green : _Palette.coral;
    final options = _list(preview['options']);
    final categories = _list(preview['category_pairs']);
    final correct = _strings(preview['correct_response']);
    final responseAttempts = _list(preview['response_attempts']);
    final supports = _strings(task['support_actions']);
    return _DetailScaffold(
      title: 'Task ${_index + 1} of ${widget.tasks.length}',
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFBCDDF8)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  color: _Palette.blue,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Read-only learner replay · this screen cannot change progress.',
                    style: _label(9.5, color: _Palette.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _RoleBadge(role: task['role']?.toString() ?? 'CORE'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.attemptLabel} · ${widget.activity['activity_name']} · ${task['item_id']}',
                  style: _body(10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: _panel(
              radius: 24,
              border: color.withValues(alpha: .28),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    firstCorrect ? Icons.check_rounded : Icons.close_rounded,
                    color: color,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstCorrect
                            ? 'Independent first-response success'
                            : 'First response needs review',
                        style: _label(14, color: color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['final_correct'] == true
                            ? 'The task was ultimately completed correctly.'
                            : 'The recorded task was not completed correctly.',
                        style: _body(10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _TaskVisualPreview(
            preview: preview,
            options: options,
            categories: categories,
          ),
          const SizedBox(height: 18),
          _ResponseJourney(attempts: responseAttempts, correct: correct),
          const SizedBox(height: 18),
          _EvidenceDetailPanel(
            task: task,
            supports: supports,
            responseAttempts: responseAttempts,
          ),
        ],
      ),
      bottom: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: _Palette.cream,
            border: Border(top: BorderSide(color: _Palette.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _index == 0 ? null : () => _showTask(_index - 1),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Previous task'),
                  style: _navButton(outlined: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _index == widget.tasks.length - 1
                      ? null
                      : () => _showTask(_index + 1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next task'),
                  style: _navButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskVisualPreview extends StatelessWidget {
  const _TaskVisualPreview({
    required this.preview,
    required this.options,
    required this.categories,
  });
  final Map<String, dynamic> preview;
  final List<Map<String, dynamic>> options;
  final List<Map<String, dynamic>> categories;

  @override
  Widget build(BuildContext context) {
    final image = preview['image']?.toString();
    final available = preview['available'] == true;
    final template = preview['template_type']?.toString() ?? '';
    final content = _map(preview['content']);
    final sequence = _nullableStrings(content['sequence']);
    final assets = _strings(content['assets']);
    final targetAssets = _strings(content['target_assets']);
    final letters = _strings(content['letters']);
    final scrambled = template == 'skill4_act4_jumbled_sentence'
        ? _strings(content['scrambled_words'])
        : _strings(content['scrambled_letters']);
    final pattern = _strings(content['pattern']);
    final audioText = content['audio_text']?.toString();
    final usesOwnAnswerPool =
        template == 'visual_memory_hats' ||
        template == 'visual_odd_one_out' ||
        template == 'skill2_identical_match';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panel(radius: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_outlined, color: _Palette.blue, size: 20),
              const SizedBox(width: 8),
              Text('Task shown to the learner', style: _label(13)),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FD),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              preview['prompt']?.toString() ?? 'Task prompt unavailable',
              textAlign: TextAlign.center,
              style: _sinhala(15, FontWeight.w700, color: _Palette.navy),
            ),
          ),
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: 14),
            Center(child: _AssetImage(value: image, size: 130)),
          ],
          if (audioText != null && audioText.isNotEmpty) ...[
            const SizedBox(height: 14),
            _AudioPromptPreview(text: audioText),
          ],
          if (template == 'visual_pattern_adventure' &&
              sequence.isNotEmpty) ...[
            const SizedBox(height: 16),
            _PatternTrainPreview(
              sequence: sequence,
              missingIndex: _integer(content['missing_index']),
            ),
          ],
          if (template == 'visual_memory_hats' && assets.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MemoryTaskPreview(
              assets: assets,
              target: content['target_asset']?.toString() ?? '',
            ),
          ],
          if (template == 'visual_odd_one_out' && targetAssets.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ShadowMatchingPreview(assets: targetAssets),
          ],
          if (template == 'visual_sorting_adventure' &&
              categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SortingTaskPreview(
              pairs: categories,
              icons: _map(content['category_icons']),
            ),
          ],
          if (template == 'skill2_identical_match' && letters.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LetterMatchingPreview(letters: letters),
          ],
          if ((template == 'skill3_fill_blank' ||
                  template == 'skill4_act2_fill_blank') &&
              sequence.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ConstructionSlotsPreview(
              values: sequence,
              emptyLabel: '?',
              title: 'Word or sentence shown',
            ),
          ],
          if (template == 'skill2_pattern_memory' && pattern.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ConstructionSlotsPreview(
              values: pattern,
              title: 'Pattern to remember',
            ),
          ],
          if ((template == 'skill3_jumbled_word' ||
                  template == 'skill4_act4_jumbled_sentence') &&
              scrambled.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ConstructionSlotsPreview(
              values: scrambled,
              title: template == 'skill3_jumbled_word'
                  ? 'Letters available'
                  : 'Words available',
            ),
          ],
          if (options.isNotEmpty && !usesOwnAnswerPool) ...[
            const SizedBox(height: 17),
            Text('Answer pool', style: _label(10, color: _Palette.muted)),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = options.length <= 2
                    ? (constraints.maxWidth - 10) / 2
                    : (constraints.maxWidth - 20) / 3;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options
                      .map(
                        (option) =>
                            _AnswerOptionTile(option: option, width: tileWidth),
                      )
                      .toList(),
                );
              },
            ),
          ],
          if (!available)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Reviewed item content is unavailable for this historical record; response evidence is still shown below.',
                style: _body(10),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatternTrainPreview extends StatelessWidget {
  const _PatternTrainPreview({
    required this.sequence,
    required this.missingIndex,
  });
  final List<String?> sequence;
  final int missingIndex;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Pattern train', style: _label(10, color: _Palette.muted)),
      const SizedBox(height: 9),
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 4.0;
          const engineWidth = 34.0;
          final available = constraints.maxWidth - engineWidth - 8;
          final carriageWidth =
              ((available - gap * (sequence.length - 1)) / sequence.length)
                  .clamp(27.0, 52.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: engineWidth,
                height: 47,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _Palette.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.train_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 5),
              ...sequence.asMap().entries.map((entry) {
                final missing =
                    entry.key == missingIndex || entry.value == null;
                return Padding(
                  padding: EdgeInsets.only(
                    right: entry.key == sequence.length - 1 ? 0 : gap,
                  ),
                  child: Container(
                    width: carriageWidth,
                    height: 47,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: missing
                          ? const Color(0xFFFFF1DC)
                          : const Color(0xFFF3F8FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: missing
                            ? _Palette.amber
                            : const Color(0xFFBEDCF7),
                      ),
                    ),
                    child: missing
                        ? Center(
                            child: Text(
                              '?',
                              style: _display(17, color: _Palette.amber),
                            ),
                          )
                        : _AssetImage(
                            value: entry.value!,
                            size: carriageWidth - 8,
                          ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    ],
  );
}

class _MemoryTaskPreview extends StatelessWidget {
  const _MemoryTaskPreview({required this.assets, required this.target});
  final List<String> assets;
  final String target;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Picture to remember', style: _label(10, color: _Palette.muted)),
      const SizedBox(height: 8),
      Center(
        child: Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF8EF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Palette.green.withValues(alpha: .45)),
          ),
          child: _ValueVisual(value: target, size: 66),
        ),
      ),
      const SizedBox(height: 13),
      Text('Cards shown', style: _label(10, color: _Palette.muted)),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = assets.length <= 3 ? assets.length : 4;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: assets
                .map(
                  (asset) => Container(
                    width: width,
                    height: 76,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _Palette.line),
                    ),
                    child: _AssetImage(value: asset, size: 58),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _ShadowMatchingPreview extends StatelessWidget {
  const _ShadowMatchingPreview({required this.assets});
  final List<String> assets;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Pictures and matching shadows',
        style: _label(10, color: _Palette.muted),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: assets
                .map(
                  (asset) => Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AssetImage(value: asset, size: 44),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            Icons.compare_arrows_rounded,
                            size: 16,
                            color: _Palette.muted,
                          ),
                        ),
                        ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF445064),
                            BlendMode.srcIn,
                          ),
                          child: _AssetImage(value: asset, size: 44),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _SortingTaskPreview extends StatelessWidget {
  const _SortingTaskPreview({required this.pairs, required this.icons});
  final List<Map<String, dynamic>> pairs;
  final Map<String, dynamic> icons;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<String>>{};
    for (final pair in pairs) {
      grouped
          .putIfAbsent(
            pair['destination']?.toString() ?? 'Category',
            () => <String>[],
          )
          .add(pair['value']?.toString() ?? '');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sorting destinations', style: _label(10, color: _Palette.muted)),
        const SizedBox(height: 8),
        ...grouped.entries.map(
          (entry) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: _ValueVisual(
                    value: _categoryIconForLabel(entry.key, pairs, icons),
                    size: 36,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: _sinhala(11.5, FontWeight.w700)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: entry.value
                            .map(
                              (value) => _ValueVisual(value: value, size: 34),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LetterMatchingPreview extends StatelessWidget {
  const _LetterMatchingPreview({required this.letters});
  final List<String> letters;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Letter matching board', style: _label(10, color: _Palette.muted)),
      const SizedBox(height: 8),
      for (final row in [letters, letters.reversed.toList()])
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row
                .map(
                  (letter) => Container(
                    width: 58,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBEDCF7)),
                    ),
                    child: Text(letter, style: _sinhala(20, FontWeight.w700)),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );
}

class _ConstructionSlotsPreview extends StatelessWidget {
  const _ConstructionSlotsPreview({
    required this.values,
    required this.title,
    this.emptyLabel = '',
  });
  final List<String?> values;
  final String title;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: _label(10, color: _Palette.muted)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map(
              (value) => Container(
                constraints: const BoxConstraints(minWidth: 54, minHeight: 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == null ? const Color(0xFFFFF1DC) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: value == null
                        ? _Palette.amber
                        : const Color(0xFFBEDCF7),
                  ),
                ),
                child: Text(
                  value ?? emptyLabel,
                  style: _sinhala(17, FontWeight.w700),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}

class _AudioPromptPreview extends StatelessWidget {
  const _AudioPromptPreview({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF4FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFBEDCF7)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.volume_up_rounded, color: _Palette.blue, size: 22),
        const SizedBox(width: 9),
        Flexible(child: Text(text, style: _sinhala(15, FontWeight.w700))),
      ],
    ),
  );
}

class _AnswerOptionTile extends StatelessWidget {
  const _AnswerOptionTile({required this.option, required this.width});
  final Map<String, dynamic> option;
  final double width;

  @override
  Widget build(BuildContext context) {
    final selected = option['was_selected'] == true;
    final correct = option['is_correct'] == true;
    final color = selected && !correct
        ? _Palette.coral
        : correct
        ? _Palette.green
        : _Palette.line;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: correct || selected ? .08 : .025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: correct || selected ? 1.8 : 1),
      ),
      child: Stack(
        children: [
          Center(
            child: _ValueVisual(
              value: option['value']?.toString() ?? '',
              size: 62,
            ),
          ),
          if (selected || correct)
            Positioned(
              right: 0,
              top: 0,
              child: Icon(
                selected && !correct
                    ? Icons.close_rounded
                    : Icons.check_rounded,
                color: color,
                size: 17,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResponseJourney extends StatelessWidget {
  const _ResponseJourney({required this.attempts, required this.correct});
  final List<Map<String, dynamic>> attempts;
  final List<String> correct;

  @override
  Widget build(BuildContext context) {
    final reconstructed = attempts.any(
      (attempt) => attempt['evidence_quality'] == 'reconstructed',
    );
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _panel(radius: 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learner response journey', style: _label(13)),
          const SizedBox(height: 5),
          Text(
            reconstructed
                ? 'Attempt order is reconstructed from the saved historical counts.'
                : 'Exact responses and support state saved for each attempt.',
            style: _body(9.5),
          ),
          const SizedBox(height: 13),
          if (attempts.isEmpty)
            Text('No attempt-level response was stored.', style: _body(10))
          else
            ...attempts.asMap().entries.map((entry) {
              final attempt = entry.value;
              final isCorrect = attempt['is_correct'] == true;
              final usedSupport =
                  attempt['support_applied_before_response'] == true;
              final color = isCorrect ? _Palette.green : _Palette.coral;
              final values = _strings(attempt['selected_answers']);
              final actions = _strings(
                attempt['support_actions_before_response'],
              );
              final actionLabels = actions
                  .map(_friendlyAction)
                  .where((label) => label.isNotEmpty)
                  .toSet()
                  .toList();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: color.withValues(alpha: .24)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${entry.key + 1}',
                        style: _label(11, color: color),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                isCorrect
                                    ? 'Correct response'
                                    : 'Incorrect response',
                                style: _label(10.5, color: color),
                              ),
                              if (usedSupport)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _Palette.amber.withValues(
                                      alpha: .13,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    actionLabels.isEmpty
                                        ? 'After app support'
                                        : 'Support: ${actionLabels.join(', ')}',
                                    style: _label(8.5, color: _Palette.amber),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          if (values.isEmpty)
                            Text(
                              'The exact selected value was not retained.',
                              style: _body(9.5),
                            )
                          else
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: values
                                  .map(
                                    (value) => Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 38,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: color.withValues(alpha: .25),
                                        ),
                                      ),
                                      child: _ValueVisual(
                                        value: value,
                                        size: 34,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: color,
                      size: 21,
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 3),
          Text(
            'Reviewed correct response',
            style: _label(9.5, color: _Palette.green),
          ),
          const SizedBox(height: 7),
          if (correct.isEmpty)
            Text('Correct-answer detail is unavailable.', style: _body(10))
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: correct
                  .map(
                    (value) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _Palette.green.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _Palette.green.withValues(alpha: .22),
                        ),
                      ),
                      child: _ValueVisual(value: value, size: 36),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _EvidenceDetailPanel extends StatelessWidget {
  const _EvidenceDetailPanel({
    required this.task,
    required this.supports,
    required this.responseAttempts,
  });
  final Map<String, dynamic> task;
  final List<String> supports;
  final List<Map<String, dynamic>> responseAttempts;

  @override
  Widget build(BuildContext context) {
    final before = _number(task['mastery_before']);
    final after = _number(task['mastery_after']);
    final update = task['mastery_update_applied'] == true;
    final storedAttemptCount = _integer(task['attempt_count']);
    final attemptCount = storedAttemptCount > 0
        ? storedAttemptCount
        : responseAttempts.length;
    final storedIncorrectCount = _number(task['incorrect_attempt_count']);
    final incorrectCount = storedIncorrectCount == null
        ? responseAttempts
              .where(
                (attempt) =>
                    attempt['is_correct'] is! bool ||
                    attempt['is_correct'] != true,
              )
              .length
        : storedIncorrectCount.toInt();
    final supportLabels = supports
        .map(_friendlyAction)
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _panel(radius: 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evidence details', style: _label(13)),
          const SizedBox(height: 13),
          _EvidenceValueRow(
            icon: Icons.school_outlined,
            label: 'Mastery effect',
            value: update
                ? '${_percent(before)} → ${_percent(after)}'
                : 'Not updated (${_friendlyRole(task['role'])})',
            color: _Palette.green,
          ),
          _EvidenceValueRow(
            icon: Icons.touch_app_outlined,
            label: 'Attempts',
            value: attemptCount <= 0
                ? 'Not recorded for this historical task'
                : '$attemptCount total · $incorrectCount incorrect',
            color: _Palette.blue,
          ),
          _EvidenceValueRow(
            icon: Icons.timer_outlined,
            label: 'Response time',
            value: _durationLabel(task['total_round_latency_ms']),
            color: _Palette.navy,
          ),
          _EvidenceValueRow(
            icon: Icons.lightbulb_outline_rounded,
            label: 'App support',
            value: supportLabels.isEmpty
                ? (_integer(task['scaffold_level']) > 0
                      ? 'Support used · exact scaffold name was not retained'
                      : 'No scaffold recorded')
                : supportLabels.join(', '),
            color: _Palette.amber,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _EvidenceValueRow extends StatelessWidget {
  const _EvidenceValueRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: last ? 0 : 12, top: 2),
    margin: EdgeInsets.only(bottom: last ? 0 : 10),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: _Palette.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(label, style: _body(10.5))),
        const SizedBox(width: 10),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: _label(10.5)),
        ),
      ],
    ),
  );
}

class _SupportResponsePanel extends StatelessWidget {
  const _SupportResponsePanel({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panel(radius: 23),
    child: Column(
      children: rows.asMap().entries.map((entry) {
        final row = entry.value;
        final outcomes = _integer(row['outcomes']);
        final rate = _number(row['next_independent_success_rate']);
        final enough = outcomes >= 3;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: entry.key == rows.length - 1
              ? null
              : const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _Palette.line)),
                ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: _Palette.blue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_friendlyAction(row['action']), style: _label(11.5)),
                    Text(
                      '${_integer(row['uses'])} uses · $outcomes linked follow-ups',
                      style: _body(9.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: (enough ? _Palette.green : _Palette.amber).withValues(
                    alpha: .10,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  enough ? _percent(rate) : 'Early',
                  style: _label(
                    9.5,
                    color: enough ? _Palette.green : _Palette.amber,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _RecurringTargetPanel extends StatelessWidget {
  const _RecurringTargetPanel({required this.targets});
  final List<Map<String, dynamic>> targets;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: _panel(radius: 23),
    child: Wrap(
      spacing: 9,
      runSpacing: 9,
      children: targets.map((target) {
        final observations = _integer(target['observations']);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Palette.coral.withValues(alpha: .22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ValueVisual(value: target['unit']?.toString() ?? '', size: 27),
              const SizedBox(width: 7),
              Text(
                '$observations observations',
                style: _label(9.5, color: _Palette.coral),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _CompactTrendPainter extends CustomPainter {
  const _CompactTrendPainter({required this.points});
  final List<Map<String, dynamic>> points;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 31.0;
    const rightPadding = 8.0;
    const top = 19.0;
    const bottomPadding = 22.0;
    final bottom = size.height - bottomPadding;
    final right = size.width - rightPadding;
    final grid = Paint()
      ..color = const Color(0xFFE3E8EF)
      ..strokeWidth = 1;
    for (final value in [0.0, .5, 1.0]) {
      final y = bottom - value * (bottom - top);
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
    }
    final values = points
        .map((row) => (_number(row['value']) ?? 0).clamp(0, 1).toDouble())
        .toList();
    final step = values.length <= 1
        ? 0.0
        : (right - left) / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        left + step * i,
        bottom - values[i] * (bottom - top),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _Palette.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < values.length; i++) {
      final row = points[i];
      final point = Offset(
        left + step * i,
        bottom - values[i] * (bottom - top),
      );
      final correct = row['first_response_correct'] == true;
      final role = row['role']?.toString();
      final color = !correct
          ? _Palette.coral
          : role == 'CONFIRMATION'
          ? _Palette.green
          : _Palette.blue;
      canvas.drawCircle(point, 5, Paint()..color = color);
      _paintCentered(
        canvas,
        (values[i] * 100).toStringAsFixed(1),
        Offset(point.dx, point.dy - 14),
        _label(8.5),
      );
    }
    _paint(canvas, '0', const Offset(7, 115), _body(8));
    _paint(canvas, '50', const Offset(4, 65), _body(8));
    _paint(canvas, '100', const Offset(0, 15), _body(8));
  }

  static void _paint(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  static void _paintCentered(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompactTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});
  final double? value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final background = Paint()
      ..color = color.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final foreground = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, background);
    if (value != null) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        6.28318 * value!.clamp(0, 1),
        false,
        foreground,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _MasteryBar extends StatelessWidget {
  const _MasteryBar({required this.value, required this.color});
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: value?.clamp(0, 1),
      minHeight: 7,
      backgroundColor: const Color(0xFFE9EDF2),
      valueColor: AlwaysStoppedAnimation(
        value == null ? _Palette.muted : color,
      ),
    ),
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'REMEDIATION' => _Palette.amber,
      'CONFIRMATION' => _Palette.blue,
      _ => _Palette.navy,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(_friendlyRole(role), style: _label(8, color: color)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        selected: active,
        onSelected: (_) => onTap(value),
        label: Text(label),
        labelStyle: _label(9.5, color: active ? Colors.white : _Palette.slate),
        selectedColor: _Palette.blue,
        backgroundColor: Colors.white,
        side: BorderSide(color: active ? _Palette.blue : _Palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        showCheckmark: false,
      ),
    );
  }
}

class _EvidencePill extends StatelessWidget {
  const _EvidencePill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: _label(8.5, color: color)),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: _display(20)),
      const SizedBox(height: 4),
      Text(subtitle, style: _body(10.5, height: 1.4)),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: _panel(radius: 22),
    child: Column(
      children: [
        Icon(icon, size: 32, color: _Palette.muted),
        const SizedBox(height: 9),
        Text(title, style: _label(13), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(detail, style: _body(10), textAlign: TextAlign.center),
      ],
    ),
  );
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.body, this.bottom});
  final String title;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _Palette.cream,
    appBar: AppBar(
      backgroundColor: _Palette.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: _Palette.navy),
      ),
      title: Text(
        title,
        style: _sinhala(13, FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: body,
    bottomNavigationBar: bottom,
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: _Palette.blue),
        ),
      ),
    ),
  );
}

class _ValueVisual extends StatelessWidget {
  const _ValueVisual({required this.value, required this.size});
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (_isAsset(value)) return _AssetImage(value: value, size: size);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: size),
      child: Text(
        _friendlyValue(value),
        textAlign: TextAlign.center,
        style: _sinhala(
          size > 40 ? 19 : 12,
          FontWeight.w700,
          color: _Palette.navy,
        ),
      ),
    );
  }
}

class _AssetImage extends StatelessWidget {
  const _AssetImage({required this.value, required this.size});
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    _assetPath(value),
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => SizedBox(
      width: size,
      height: size,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: _Palette.muted,
      ),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: _Palette.coral),
          const SizedBox(height: 12),
          Text('Learning evidence unavailable', style: _display(18)),
          const SizedBox(height: 6),
          Text(message, style: _body(10.5), textAlign: TextAlign.center),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _Palette {
  static const cream = Color(0xFFFFF8E8);
  static const surface = Color(0xFFFFFEFA);
  static const navy = Color(0xFF17346B);
  static const slate = Color(0xFF53617A);
  static const muted = Color(0xFF8993A5);
  static const line = Color(0xFFE2E5EA);
  static const blue = Color(0xFF2687E9);
  static const green = Color(0xFF17A45B);
  static const amber = Color(0xFFE18A00);
  static const coral = Color(0xFFEF4B55);
}

BoxDecoration _panel({
  double radius = 20,
  Color border = _Palette.line,
  Gradient? gradient,
}) => BoxDecoration(
  color: gradient == null ? _Palette.surface : null,
  gradient: gradient,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: border),
  boxShadow: const [
    BoxShadow(color: Color(0x100D2A54), blurRadius: 18, offset: Offset(0, 7)),
  ],
);

TextStyle _display(double size, {Color color = _Palette.navy}) =>
    GoogleFonts.nunito(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      height: 1.08,
    );

TextStyle _label(double size, {Color color = _Palette.navy}) =>
    GoogleFonts.nunito(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.25,
    );

TextStyle _body(
  double size, {
  Color color = _Palette.slate,
  double height = 1.35,
}) => GoogleFonts.nunito(
  fontSize: size,
  fontWeight: FontWeight.w500,
  color: color,
  height: height,
);

TextStyle _sinhala(
  double size,
  FontWeight weight, {
  Color color = _Palette.navy,
}) => GoogleFonts.notoSansSinhala(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.35,
);

ButtonStyle _navButton({bool outlined = false}) => outlined
    ? OutlinedButton.styleFrom(
        foregroundColor: _Palette.blue,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      )
    : FilledButton.styleFrom(
        backgroundColor: _Palette.blue,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      );

List<Map<String, dynamic>> _activityAttempts(List<Map<String, dynamic>> tasks) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final task in tasks) {
    final sessionId = task['session_id']?.toString().trim() ?? '';
    final key = sessionId.isEmpty ? 'historical-without-session' : sessionId;
    grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(task);
  }
  final attempts = <Map<String, dynamic>>[];
  var index = 0;
  for (final entry in grouped.entries) {
    final attemptTasks = entry.value;
    final isHistorical = entry.key == 'historical-without-session';
    attempts.add({
      'key': entry.key,
      'label': isHistorical
          ? 'Earlier historical records'
          : index == 0
          ? 'Latest activity attempt'
          : 'Earlier attempt ${index + 1}',
      'detail':
          '${attemptTasks.length} task ${attemptTasks.length == 1 ? 'event' : 'events'} · ${_relativeTime(attemptTasks.first['timestamp'])}',
      'tasks': attemptTasks,
    });
    index++;
  }
  return attempts;
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map(_map).toList()
    : <Map<String, dynamic>>[];

List<String> _strings(dynamic value) => value is List
    ? value
          .where((item) => item != null)
          .map((item) => item.toString())
          .toList()
    : <String>[];

List<String?> _nullableStrings(dynamic value) => value is List
    ? value.map((item) => item?.toString()).toList()
    : <String?>[];

String _categoryIconForLabel(
  String label,
  List<Map<String, dynamic>> pairs,
  Map<String, dynamic> icons,
) {
  final pair = pairs.firstWhere(
    (entry) => entry['destination']?.toString() == label,
    orElse: () => const <String, dynamic>{},
  );
  final category = pair['category']?.toString();
  final icon = category == null ? null : icons[category];
  return icon?.toString() ?? 'basket/basket_animals.png';
}

double? _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
String _percent(double? value) =>
    value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';

Color _skillColor(String id) => switch (id) {
  '1' => _Palette.green,
  '2' => _Palette.blue,
  '3' => _Palette.amber,
  '4' => _Palette.coral,
  _ => _Palette.slate,
};

IconData _skillIcon(String id) => switch (id) {
  '1' => Icons.visibility_rounded,
  '2' => Icons.hearing_rounded,
  '3' => Icons.abc_rounded,
  '4' => Icons.menu_book_rounded,
  _ => Icons.school_rounded,
};

Color _masteryColor(double? value) => value == null
    ? _Palette.muted
    : value >= .7
    ? _Palette.green
    : value >= .5
    ? _Palette.blue
    : _Palette.amber;

String _masteryLabel(double? value) => value == null
    ? 'Not observed'
    : value >= .7
    ? 'Higher estimate'
    : value >= .5
    ? 'Developing estimate'
    : 'Needs support';

String _friendlyRole(dynamic role) => switch (role?.toString().toUpperCase()) {
  'REMEDIATION' => 'Remediation',
  'CONFIRMATION' => 'Confirmation',
  _ => 'Core task',
};

String _friendlyAction(dynamic raw) {
  const labels = {
    'RETRY_CURRENT': 'Retry current task',
    'SCAFFOLD_REMOVE_DISTRACTOR': 'Remove a distractor',
    'SCAFFOLD_REMOVE_AND_HIGHLIGHT':
        'Remove a distractor and highlight the answer',
    'SCAFFOLD_DISABLE_DISTRACTOR': 'Disable a distractor',
    'SCAFFOLD_HIGHLIGHT_CORRECT': 'Highlight the correct choice',
    'SCAFFOLD_HIGHLIGHT_DESTINATION': 'Highlight the destination',
    'SCAFFOLD_REPLAY_INSTRUCTION': 'Replay instruction',
    'SCAFFOLD_SLOW_AUDIO': 'Slow audio',
    'SCAFFOLD_REVEAL_FIRST_TOKEN': 'Reveal first token',
    'SCAFFOLD_LOCK_CORRECT_TOKEN': 'Lock the correct token',
    'SCAFFOLD_LOCK_CORRECT_PREFIX': 'Lock correct prefix',
    'SCAFFOLD_SHOW_WORKED_EXAMPLE': 'Show a worked example',
    'REMOVE_OPTIONS': 'Remove a distractor',
    'DISABLE_OPTIONS': 'Disable a distractor',
    'HIGHLIGHT_OPTION': 'Highlight the correct choice',
    'HIGHLIGHT_OPTIONS': 'Highlight the correct choice',
    'HIGHLIGHT_DESTINATION': 'Highlight the destination',
    'REPLAY_INSTRUCTION': 'Replay instruction',
    'SLOW_AUDIO': 'Slow audio',
    'REVEAL_FIRST_TOKEN': 'Reveal first token',
    'LOCK_CORRECT_TOKEN': 'Lock the correct token',
    'LOCK_CORRECT_PREFIX': 'Lock correct prefix',
    'removeOptions': 'Remove a distractor',
    'disableOptions': 'Disable a card',
    'highlightOptions': 'Highlight the correct answer',
    'highlightDestination': 'Highlight the destination',
    'replayInstruction': 'Replay the instruction',
    'slowAudio': 'Play slower audio',
    'revealFirstToken': 'Reveal the first token',
    'lockCorrectToken': 'Lock the correct token',
    'lockCorrectPrefix': 'Lock the correct prefix',
  };
  final value = raw?.toString() ?? '';
  if (value.isEmpty ||
      RegExp(
        r'^S\d+A\d+R\d+(?:V\d+)?-C4-',
        caseSensitive: false,
      ).hasMatch(value) ||
      RegExp(
        r'^(?:command|support)-\d+$',
        caseSensitive: false,
      ).hasMatch(value)) {
    return '';
  }
  return labels[value] ?? value.replaceAll('_', ' ').toLowerCase();
}

bool _isAsset(String value) {
  final lower = value.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg');
}

String _assetPath(String value) =>
    value.startsWith('assets/') ? value : 'assets/images/activity_icons/$value';

String _friendlyValue(String value) {
  if (!_isAsset(value)) return value;
  final name = value.split('/').last.split('.').first.replaceAll('_', ' ');
  return name.isEmpty
      ? 'Image'
      : '${name[0].toUpperCase()}${name.substring(1)}';
}

String _relativeTime(dynamic raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) return 'date unavailable';
  final difference = DateTime.now().difference(parsed.toLocal());
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes.clamp(0, 59)} min ago';
  }
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  return '${parsed.day}/${parsed.month}/${parsed.year}';
}

String _durationLabel(dynamic milliseconds) {
  final value = _integer(milliseconds);
  if (value <= 0) return 'Historical detail unavailable';
  if (value < 1000) return '$value ms';
  return '${(value / 1000).toStringAsFixed(1)} seconds';
}
