import 'package:flutter/material.dart';

import '../../services/therapist_dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard/dashboard_kit.dart';
import '../../widgets/dashboard/letter_practice_grid.dart';

/// Therapist student-detail tabs for C1 (activities and touch), C2 (reading
/// and speech) and C3 (combined profile). Every number shows its period and
/// count; model outputs are labelled as estimates for professional review.

const Map<String, String> kPatternNames = {
  'TYPICAL': 'Typical',
  'VISUAL_ORTHOGRAPHIC_PATTERN': 'Visual-orthographic',
  'PHONOLOGICAL_PATTERN': 'Phonological',
  'COMBINED_PATTERN': 'Combined',
  'NOT_SURE': 'Not sure',
};

const Map<String, String> kIndexNames = {
  'visual_processing_index': 'Visual processing speed',
  'phonological_task_index': 'Sound-task speed',
  'motor_interaction_index': 'Wrong taps and pauses',
  'attention_stability_index': 'Attention steadiness',
};

const Map<String, String> kIndexHints = {
  'visual_processing_index':
      'From average time to first touch (3.5 s scores 50)',
  'phonological_task_index': 'Only measured on sound and letter-sound tasks',
  'motor_interaction_index': 'Fewer wrong answers and long pauses score higher',
  'attention_stability_index': 'Fewer pauses over 8 seconds score higher',
};

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _list(dynamic value) => value is List ? value : const [];

DashTone _stateTone(String? state) {
  switch ((state ?? '').toUpperCase()) {
    case 'LOW':
    case 'ENGAGED':
    case 'VALID':
      return DashTone.good;
    case 'MODERATE':
    case 'MODERATE_LOAD':
    case 'UNCERTAIN':
      return DashTone.watch;
    case 'HIGH':
    case 'VERY_HIGH':
    case 'HIGH_LOAD':
    case 'RETRY_REQUIRED':
      return DashTone.review;
    default:
      return DashTone.neutral;
  }
}

String _readingStatusLabel(String? status) {
  switch (status) {
    case 'valid':
    case 'available':
      return 'Clear enough to measure';
    case 'uncertain':
      return 'Measured with low confidence';
    case 'retry_required':
      return 'Recording too unclear to measure';
    case 'persistence_failed':
      return 'Not saved - please retry';
    case null:
    case 'unavailable':
      return 'No recording yet';
    default:
      return DashFormat.words(status);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Professional feedback sheet (C1 and C3)
// ─────────────────────────────────────────────────────────────────────────
Future<bool> showProfessionalFeedbackSheet(
  BuildContext context, {
  required String studentId,
  required String component,
  required String estimateLabel,
  String initialAgreement = 'agree',
  String? sessionId,
}) async {
  String agreement = initialAgreement;
  String? pattern;
  final noteController = TextEditingController();
  bool saving = false;
  String? error;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your professional view',
                style: DashText.heading(fontSize: 19),
              ),
              const SizedBox(height: 6),
              Text(
                'Model estimate: $estimateLabel. Your answer is stored with the measurements '
                'so the model can later be checked against professional judgement.',
                style: DashText.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    ['agree', 'Agree'],
                    ['disagree', 'Disagree'],
                    ['unsure', 'Unsure'],
                  ])
                    ChoiceChip(
                      label: Text(
                        option[1],
                        style: DashText.body(fontSize: 14),
                      ),
                      selected: agreement == option[0],
                      onSelected: (_) =>
                          setSheetState(() => agreement = option[0]),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: pattern,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pattern you observe (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final entry in kPatternNames.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setSheetState(() => pattern = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                Text(
                  error!,
                  style: DashText.body(
                    fontSize: 14,
                    color: AppColors.softCoralDark,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text('Save', style: DashText.button()),
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await TherapistDashboardService().submitFeedback(
                              studentId,
                              component: component,
                              agreement: agreement,
                              professionalPattern: pattern,
                              note: noteController.text,
                              sessionId: sessionId,
                            );
                            if (sheetContext.mounted)
                              Navigator.pop(sheetContext, true);
                          } catch (e) {
                            setSheetState(() {
                              saving = false;
                              error = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  noteController.dispose();
  return saved == true;
}

class _FeedbackButtons extends StatelessWidget {
  final void Function(String agreement) onSelected;
  const _FeedbackButtons({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => onSelected('agree'),
          icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
          label: Text('Agree', style: DashText.body(fontSize: 14)),
        ),
        OutlinedButton.icon(
          onPressed: () => onSelected('disagree'),
          icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
          label: Text('Disagree', style: DashText.body(fontSize: 14)),
        ),
        OutlinedButton.icon(
          onPressed: () => onSelected('unsure'),
          icon: const Icon(Icons.help_outline_rounded, size: 18),
          label: Text('Unsure', style: DashText.body(fontSize: 14)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// C1 — Activities and touch
// ─────────────────────────────────────────────────────────────────────────
class TherapistActivityTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? activityPerformance;
  final String studentId;
  final VoidCallback onChanged;

  const TherapistActivityTab({
    super.key,
    required this.data,
    required this.activityPerformance,
    required this.studentId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sessions = DashFormat.number(data['session_count'])?.round() ?? 0;
    final state = _map(data['c1_state']);
    final trends = _map(data['trends']);
    final period = (data['reporting_period'] ?? 'Recent sessions').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(period, style: DashText.heading(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          '$sessions sessions · ${DashFormat.count(data['total_trials'])} responses. '
          'Practice observations to guide support, not a diagnosis.',
          style: DashText.body(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        if (sessions == 0)
          const EmptyHint(
            icon: Icons.touch_app_outlined,
            title: 'No activity sessions yet',
            message:
                'Measures appear after the child completes an activity in Skills 1-4.',
          )
        else ...[
          _sessionState(state, data),
          _keyNumbers(),
          _indices(state),
          _knowledgeAreas(),
          _errors(),
          _movement(),
          _patternEstimate(context, state),
          DateTrendChart(
            title: 'Correct on first try (%)',
            points: _list(trends['accuracy']),
            color: AppColors.gentleGreen,
            scale: 100,
            minY: 0,
            maxY: 100,
          ),
          DateTrendChart(
            title: 'Median response time (ms)',
            points: _list(trends['latency']),
            color: AppColors.calmBlue,
            minY: 0,
          ),
          DateTrendChart(
            title: 'Within-session fatigue (0 = none, 1 = high)',
            points: _list(trends['fatigue']),
            color: AppColors.softCoral,
            minY: 0,
            maxY: 1,
          ),
        ],
        _activities(),
      ],
    );
  }

  static bool _insufficient(String? state) =>
      state == null || state == 'UNAVAILABLE' || state == 'INSUFFICIENT_DATA';

  Widget _sessionState(Map<String, dynamic> state, Map<String, dynamic> data) {
    final fatigueState =
        (data['fatigue_state'] ?? _map(state['fatigue'])['state'])?.toString();
    final load = _map(state['interaction_state'])['state']?.toString();
    final quality = DashFormat.number(_map(state['quality'])['quality_score']);
    return DashCard(
      title: 'During the latest session',
      subtitle:
          'Fatigue compares early and late completed rounds (2 vs 2 for 4-5 rounds, 3 vs 3 for 6+)',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip(
            label:
                'Fatigue: ${_insufficient(fatigueState) ? 'needs 4+ completed rounds' : DashFormat.words(fatigueState!)}',
            tone: _stateTone(fatigueState),
            icon: Icons.battery_charging_full_rounded,
          ),
          StatusChip(
            label:
                'Effort: ${_insufficient(load) ? 'needs 3+ completed rounds' : DashFormat.words(load!)}',
            tone: _stateTone(load),
            icon: Icons.psychology_alt_outlined,
          ),
          StatusChip(
            label:
                'Data completeness: ${quality == null ? DashFormat.missing : '${(quality * 100).round()}%'}',
            tone: quality == null
                ? DashTone.neutral
                : (quality >= 0.8 ? DashTone.good : DashTone.watch),
            icon: Icons.fact_check_outlined,
          ),
        ],
      ),
    );
  }

  Widget _keyNumbers() {
    final window = _map(data['window']);
    final rounds = DashFormat.number(window['completed_rounds'])?.round();
    final started = DashFormat.number(window['sessions_started'])?.round();
    final early =
        DashFormat.number(window['sessions_ended_early'])?.round() ?? 0;
    return DashCard(
      title: 'Key numbers',
      subtitle: rounds == null
          ? 'Pooled over completed rounds in the period'
          : '$rounds completed rounds in $started sessions'
                '${early > 0 ? ' ($early ended before a round was finished)' : ''}'
                ' · every completed round counts once',
      child: MetricGrid(
        children: [
          MetricTile(
            label: 'Correct on first try',
            value: DashFormat.percent(data['first_attempt_accuracy']),
            detail: rounds == null
                ? null
                : '${window['first_try_correct'] ?? 0} of $rounds rounds',
            icon: Icons.check_circle_outline_rounded,
            tone: DashTone.good,
          ),
          MetricTile(
            label: 'Rounds needing another try',
            value: DashFormat.percent(data['retry_rate']),
            icon: Icons.replay_rounded,
            tone: DashTone.watch,
          ),
          MetricTile(
            label: 'Median time to first answer',
            value: DashFormat.millis(data['median_response_latency_ms']),
            detail: 'First choice, tap or drop (older sessions: first touch)',
            icon: Icons.timer_outlined,
          ),
          MetricTile(
            label: 'Time to correct answer',
            value: DashFormat.millis(data['median_time_to_correct_ms']),
            detail: 'Round start to final correct answer',
            icon: Icons.hourglass_bottom_rounded,
          ),
          MetricTile(
            label: 'Attempts per round',
            value:
                DashFormat.number(
                  data['mean_attempts_per_round'],
                )?.toStringAsFixed(1) ??
                DashFormat.missing,
            icon: Icons.tag_rounded,
          ),
          MetricTile(
            label: 'Self-corrections',
            value: DashFormat.percent(data['correction_rate']),
            detail: 'Recorded in letter/word ordering tasks only',
            icon: Icons.edit_outlined,
          ),
          if (window['stray_drops_per_drag_round'] != null)
            MetricTile(
              label: 'Drags dropped outside a target',
              value: DashFormat.number(
                window['stray_drops_per_drag_round'],
              )!.toStringAsFixed(1),
              detail: 'Per drag round; a movement miss, not a wrong answer',
              icon: Icons.pan_tool_alt_outlined,
            ),
        ],
      ),
    );
  }

  Widget _indices(Map<String, dynamic> state) {
    final indices = _map(state['indices']);
    final baseline = _map(state['baseline_indices']);
    final measured = kIndexNames.keys
        .where((k) => DashFormat.number(indices[k]) != null)
        .toList();
    return DashCard(
      title: 'Learner indices (0-100)',
      subtitle: baseline.isEmpty
          ? 'Latest session'
          : 'Latest session; the black line marks the child\'s first measured session',
      child: measured.isEmpty
          ? Text(
              'Indices appear after a complete activity session.',
              style: DashText.body(fontSize: 14),
            )
          : Column(
              children: [
                for (final key in kIndexNames.keys)
                  PercentBar(
                    label: kIndexNames[key]!,
                    value: DashFormat.number(indices[key]) == null
                        ? null
                        : DashFormat.number(indices[key])! / 100,
                    marker: DashFormat.number(baseline[key]) == null
                        ? null
                        : DashFormat.number(baseline[key])! / 100,
                    valueLabel: DashFormat.number(indices[key]) == null
                        ? null
                        : '${DashFormat.number(indices[key])!.round()} / 100',
                    detail: kIndexHints[key],
                    color: AppColors.calmBlue,
                  ),
              ],
            ),
    );
  }

  Widget _knowledgeAreas() {
    final rows = _list(data['kc_breakdown']).whereType<Map>().toList();
    return DashCard(
      title: 'Learning areas',
      subtitle: 'Correct on first try, with the number of responses',
      child: rows.isEmpty
          ? Text(
              'No learning-area data in this period.',
              style: DashText.body(fontSize: 14),
            )
          : Column(
              children: [
                for (final row in rows)
                  PercentBar(
                    label: (row['name'] ?? row['kc_id']).toString(),
                    value: DashFormat.number(row['accuracy']),
                    detail: '${DashFormat.count(row['trials'])} responses',
                    color: AppColors.gentleGreen,
                  ),
              ],
            ),
    );
  }

  Widget _errors() {
    final breakdown = _map(data['error_breakdown']);
    final total = DashFormat.number(breakdown['total_errors'])?.round() ?? 0;
    final categories = _list(breakdown['categories']).whereType<Map>().toList();
    return DashCard(
      title: 'Types of first-try mistakes',
      subtitle: total == 0
          ? 'No first-try mistakes in this period'
          : 'Share of $total first-try mistakes, as reported by each task',
      child: total == 0
          ? Text('Nothing to show.', style: DashText.body(fontSize: 14))
          : Column(
              children: [
                for (final row in categories)
                  if ((DashFormat.number(row['count']) ?? 0) > 0 ||
                      row['key'] == 'unknown_error')
                    PercentBar(
                      label: (row['label'] ?? row['key']).toString(),
                      value: DashFormat.number(row['share']),
                      detail: '${DashFormat.count(row['count'])} mistakes',
                      color: row['key'] == 'unknown_error'
                          ? AppColors.textHint
                          : AppColors.warmAmber,
                    ),
              ],
            ),
    );
  }

  Widget _movement() {
    final k = _map(data['kinematics']);
    final sessions = DashFormat.number(k['sessions'])?.round() ?? 0;
    return DashCard(
      title: 'Touch and movement',
      subtitle:
          'Medians over $sessions sessions · path and smoothness from drag strokes only',
      child: sessions == 0
          ? Text(
              'Appears after drag activities such as sorting, word building or sentence order.',
              style: DashText.body(fontSize: 14),
            )
          : Column(
              children: [
                LabeledValueRow(
                  label: 'Time to first touch',
                  value: DashFormat.millis(k['time_to_first_touch_ms']),
                ),
                LabeledValueRow(
                  label: 'Touch hold time',
                  value: DashFormat.millis(k['dwell_time_ms']),
                ),
                LabeledValueRow(
                  label: 'Directness of finger path',
                  hint: '100% = straight line to the target',
                  value: DashFormat.percent(k['path_efficiency_ratio']),
                ),
                LabeledValueRow(
                  label: 'Movement smoothness (jerk)',
                  hint: 'Lower = smoother movement',
                  value:
                      DashFormat.number(
                        k['dimensionless_jerk'],
                      )?.toStringAsFixed(1) ??
                      DashFormat.missing,
                ),
                LabeledValueRow(
                  label: 'Look-alike letter choices',
                  hint: k['orthographic_confusion_note']?.toString(),
                  value: DashFormat.percent(
                    k['orthographic_confusion_index'],
                    fallback: 'Not measurable yet',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _patternEstimate(BuildContext context, Map<String, dynamic> state) {
    final estimate = _map(state['pattern_estimate']);
    final available = estimate['available'] == true;
    final probs = <String, double>{};
    _map(estimate['probabilities']).forEach((key, value) {
      final v = DashFormat.number(value);
      if (v != null) probs[kPatternNames[key] ?? key] = v;
    });
    final predicted =
        kPatternNames[estimate['predicted_pattern']] ??
        estimate['predicted_pattern']?.toString();
    final evidence = _map(estimate['evidence']);
    final missing = _list(
      estimate['missing_evidence'],
    ).map((e) => e.toString()).toList();
    final outside = _list(estimate['outside_range']).whereType<Map>().toList();
    final notes = _list(estimate['notes']).map((e) => e.toString()).toList();
    final rounds = DashFormat.number(evidence['completed_rounds'])?.round();
    return DashCard(
      title:
          'Learner pattern estimate (last ${estimate['window_days'] ?? 14} days)',
      subtitle:
          'Gradient boosting, version ${estimate['model_version'] ?? '-'} · trained on simulated learners · '
          'for review only${rounds == null ? '' : ' · $rounds completed rounds'}',
      accent: AppColors.calmBlue,
      child: !available
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estimate['unavailable_reason']?.toString() ??
                      'The estimate updates after each activity.',
                  style: DashText.body(fontSize: 14),
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final gap in missing)
                    LabeledValueRow(label: 'Still needed', value: gap),
                ],
                if (outside.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final row in outside)
                    LabeledValueRow(
                      label: (row['label'] ?? row['feature']).toString(),
                      hint:
                          'Trained range ${_list(row['training_range']).map((v) => DashFormat.number(v)?.toStringAsFixed(2) ?? '-').join(' to ')}',
                      value:
                          DashFormat.number(row['value'])?.toStringAsFixed(2) ??
                          DashFormat.missing,
                    ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProbabilityBar(probabilities: probs),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(note, style: DashText.caption(fontSize: 13)),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Do you agree with "$predicted"?',
                  style: DashText.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _FeedbackButtons(
                  onSelected: (agreement) async {
                    final saved = await showProfessionalFeedbackSheet(
                      context,
                      studentId: studentId,
                      component: 'c1',
                      estimateLabel: predicted ?? 'activity pattern',
                      initialAgreement: agreement,
                      sessionId: state['session_id']?.toString(),
                    );
                    if (saved) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Feedback saved.')),
                        );
                      }
                      onChanged();
                    }
                  },
                ),
              ],
            ),
    );
  }

  Widget _activities() {
    final rows = _list(
      activityPerformance?['activities'],
    ).whereType<Map>().toList();
    return DashCard(
      title: 'By activity',
      subtitle: 'Same period as above',
      child: rows.isEmpty
          ? Text(
              'No activity-level observations in this period.',
              style: DashText.body(fontSize: 14),
            )
          : Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (row['activity_display'] ??
                                        row['activity_name'] ??
                                        row['activity_id'])
                                    .toString(),
                                style: DashText.body(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                [
                                  if (row['skill_name_en'] != null)
                                    row['skill_name_en'].toString(),
                                  '${DashFormat.count(row['trials'])} responses',
                                  if ((DashFormat.number(
                                            _map(row['voice'])['recordings'],
                                          ) ??
                                          0) >
                                      0)
                                    '${DashFormat.count(_map(row['voice'])['usable_recordings'])} of ${DashFormat.count(_map(row['voice'])['recordings'])} recordings clear',
                                ].join(' · '),
                                style: DashText.caption(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DashFormat.percent(
                            row['first_attempt_accuracy'],
                            fallback: '-',
                          ),
                          style: DashText.heading(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// C2 — Reading and speech
// ─────────────────────────────────────────────────────────────────────────
class TherapistReadingTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const TherapistReadingTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final recordings = DashFormat.number(data['recording_count'])?.round() ?? 0;
    final latest = _map(data['latest']);
    final issues = _map(data['quality_issue_counts']);
    String? topIssue;
    if (issues.isNotEmpty) {
      final sorted = issues.entries.toList()
        ..sort(
          (a, b) => (DashFormat.number(b.value) ?? 0).compareTo(
            DashFormat.number(a.value) ?? 0,
          ),
        );
      topIssue =
          '${DashFormat.words(sorted.first.key)} (${DashFormat.count(sorted.first.value)})';
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          (data['reporting_period'] ?? 'Recent recordings').toString(),
          style: DashText.heading(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          'Reading recordings and repeated letter-practice attempts. These are observations, not a diagnosis.',
          style: DashText.body(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        LetterPracticeGrid(
          groups: _list(data['letter_progress'])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(),
          detailed: true,
        ),
        if (recordings == 0)
          const EmptyHint(
            icon: Icons.mic_none_rounded,
            title: 'No reading recordings yet',
            message:
                'Invite the child to try a letter-practice or reading activity.',
          )
        else ...[
          DashCard(
            title: 'Recording health',
            subtitle: 'Can reading be measured reliably at home?',
            child: MetricGrid(
              children: [
                MetricTile(
                  label: 'Recordings',
                  value: '$recordings',
                  icon: Icons.mic_rounded,
                ),
                MetricTile(
                  label: 'Clear enough to measure',
                  value: DashFormat.percent(data['usable_recording_rate']),
                  icon: Icons.graphic_eq_rounded,
                  tone:
                      (DashFormat.number(data['usable_recording_rate']) ?? 0) >=
                          0.5
                      ? DashTone.good
                      : DashTone.watch,
                ),
                MetricTile(
                  label: 'Most common recording issue',
                  value: topIssue ?? 'None',
                  icon: Icons.warning_amber_rounded,
                  tone: topIssue == null ? DashTone.good : DashTone.watch,
                ),
              ],
            ),
          ),
          _latestCard(latest),
          DateTrendChart(
            title: 'Letters read as expected (%, session median)',
            points: _list(data['session_trend']),
            valueKey: 'grapheme_accuracy',
            color: AppColors.gentleGreen,
            scale: 100,
            minY: 0,
            maxY: 100,
          ),
          DateTrendChart(
            title: 'Time to start speaking after recording starts (ms)',
            points: _list(data['session_trend']),
            valueKey: 'voice_onset_ms',
            color: AppColors.warmAmber,
            minY: 0,
          ),
          DateTrendChart(
            title: 'Reading rate (words per minute, clear recordings)',
            points: _list(data['session_trend']),
            valueKey: 'reading_rate_wpm',
            color: AppColors.calmBlue,
            minY: 0,
          ),
          _letterChanges(),
          _items(),
          _research(latest),
        ],
      ],
    );
  }

  Widget _latestCard(Map<String, dynamic> latest) {
    final status = latest['measurement_status']?.toString();
    return DashCard(
      title: 'Latest reading',
      subtitle: [
        if (latest['item_id'] != null) 'Item ${latest['item_id']}',
        if (latest['recorded_at'] != null)
          DashFormat.date(latest['recorded_at']),
      ].join(' · '),
      trailing: StatusChip(
        label: _readingStatusLabel(status),
        tone: _stateTone(status),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricGrid(
            children: [
              MetricTile(
                label: 'Reading score',
                value: DashFormat.percent(latest['reading_performance_score']),
                detail: '70% letters, 20% words, 10% syllable beats',
                icon: Icons.menu_book_rounded,
                tone: DashTone.good,
              ),
              MetricTile(
                label: 'Measurement confidence',
                value: DashFormat.percent(latest['combined_confidence']),
                detail: 'Recording quality and method agreement',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LabeledValueRow(
            label: 'Letters read as expected',
            value: DashFormat.percent(latest['grapheme_accuracy']),
          ),
          LabeledValueRow(
            label: 'Words read as expected',
            value: DashFormat.percent(latest['word_accuracy']),
          ),
          LabeledValueRow(
            label: 'Reading rate',
            value: DashFormat.number(latest['reading_rate_wpm']) == null
                ? DashFormat.missing
                : '${DashFormat.number(latest['reading_rate_wpm'])!.round()} words/min',
          ),
          LabeledValueRow(
            label: 'Time to start speaking',
            hint: 'After the record button was pressed',
            value: DashFormat.millis(
              latest['voice_onset_ms'] ?? latest['acoustic_latency_ms'],
            ),
          ),
          LabeledValueRow(
            label: 'Time to press record',
            hint: 'Interaction time, not reading time',
            value: DashFormat.millis(latest['record_start_delay_ms']),
          ),
          LabeledValueRow(
            label: 'Pauses (0.2-3 s)',
            value: DashFormat.count(
              latest['pause_count'],
              fallback: DashFormat.missing,
            ),
          ),
          LabeledValueRow(
            label: 'Time spent pausing',
            value: DashFormat.percent(latest['pause_ratio']),
          ),
          if (_list(latest['disagreement_reasons']).isNotEmpty)
            LabeledValueRow(
              label: 'Why confidence is low',
              value: _list(
                latest['disagreement_reasons'],
              ).map((r) => DashFormat.words(r.toString())).join(', '),
            ),
          if (_list(latest['quality_issues']).isNotEmpty)
            LabeledValueRow(
              label: 'Recording issues',
              value: _list(
                latest['quality_issues'],
              ).map((r) => DashFormat.words(r.toString())).join(', '),
            ),
          if (latest['measured'] == false &&
              status != null &&
              status != 'unavailable')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'This recording could not be measured, so no reading accuracy is shown for it.',
                style: DashText.caption(fontSize: 13),
              ),
            ),
          const SizedBox(height: 10),
          _comparison(
            (latest['expected_text'] ?? '').toString(),
            (latest['transcription'] ?? '').toString(),
          ),
        ],
      ),
    );
  }

  Widget _comparison(String expected, String recognized) {
    if (expected.isEmpty && recognized.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slateBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expected',
            style: DashText.caption(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            expected.isEmpty ? '-' : expected,
            style: DashText.sinhala(fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            'Heard by speech recognition',
            style: DashText.caption(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            recognized.isEmpty ? '(nothing recognised)' : recognized,
            style: DashText.sinhala(fontSize: 17),
          ),
        ],
      ),
    );
  }

  Widget _letterChanges() {
    final counts = _map(data['letter_change_counts']);
    if (counts.isEmpty) return const SizedBox.shrink();
    return DashCard(
      title: 'Letters read differently',
      subtitle:
          'Expected letter → letter recognised, across clear recordings. '
          'Speech recognition can also cause these; check before acting.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in counts.entries)
            StatusChip(
              label: '${entry.key} · ${DashFormat.count(entry.value)}',
              tone: DashTone.watch,
            ),
        ],
      ),
    );
  }

  Widget _items() {
    final items = _list(data['items']).whereType<Map>().toList();
    return DashCard(
      title: 'Recent sentences',
      subtitle: 'Red words were missed or read differently',
      child: items.isEmpty
          ? Text(
              'No sentences in this period.',
              style: DashText.body(fontSize: 14),
            )
          : Column(
              children: [
                for (final item in items)
                  _itemRow(Map<String, dynamic>.from(item)),
              ],
            ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final ops = _list(item['word_operations']).whereType<Map>().toList();
    final spans = <TextSpan>[];
    for (final op in ops) {
      final kind = op['op']?.toString();
      if (kind == 'insertion') continue;
      final word = (op['expected'] ?? '').toString();
      if (word.isEmpty) continue;
      final wrong = kind == 'substitution' || kind == 'deletion';
      spans.add(
        TextSpan(
          text: '$word ',
          style: DashText.sinhala(
            fontSize: 16,
            color: wrong ? AppColors.softCoralDark : AppColors.textPrimary,
            fontWeight: wrong ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }
    final status = item['status']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['activity'] ?? 'Reading'} · ${DashFormat.date(item['recorded_at'])}',
                  style: DashText.caption(fontSize: 13),
                ),
              ),
              Text(
                DashFormat.percent(item['grapheme_accuracy'], fallback: '-'),
                style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (spans.isNotEmpty)
            RichText(text: TextSpan(children: spans))
          else
            Text(
              (item['expected_text'] ?? '').toString(),
              style: DashText.sinhala(fontSize: 16),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip(
                label: _readingStatusLabel(status),
                tone: _stateTone(status),
              ),
              if ((DashFormat.number(item['attempts_for_item']) ?? 1) > 1)
                StatusChip(
                  label:
                      'Recorded ${DashFormat.count(item['attempts_for_item'])} times',
                  tone: DashTone.neutral,
                ),
            ],
          ),
          if (_list(item['letter_changes']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Letters: ${_list(item['letter_changes']).whereType<Map>().map((c) => c['op'] == 'deletion' ? '${c['expected']} missed' : '${c['expected']} → ${c['observed']}').join(', ')}',
                style: DashText.sinhala(fontSize: 14),
              ),
            ),
          if (_list(item['quality_issues']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Recording issues: ${_list(item['quality_issues']).map((r) => DashFormat.words(r.toString())).join(', ')}',
                style: DashText.caption(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _research(Map<String, dynamic> latest) {
    return Card(
      elevation: 0,
      color: AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: ExpansionTile(
        title: Text(
          'Research measures (exploratory)',
          style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Not used in the reading score',
          style: DashText.caption(fontSize: 13),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          LabeledValueRow(
            label: 'Voice steadiness (jitter)',
            hint: 'Unreliable on short child recordings',
            value:
                DashFormat.number(latest['jitter'])?.toStringAsFixed(3) ??
                DashFormat.missing,
          ),
          LabeledValueRow(
            label: 'Loudness steadiness (shimmer)',
            value:
                DashFormat.number(latest['shimmer'])?.toStringAsFixed(3) ??
                DashFormat.missing,
          ),
          LabeledValueRow(
            label: 'Spoken beats vs expected syllables',
            value: DashFormat.count(
              latest['peak_delta'],
              fallback: DashFormat.missing,
            ),
          ),
          LabeledValueRow(
            label: 'Speech-recognition confidence',
            hint: 'Model certainty about the transcript, not reading accuracy',
            value: DashFormat.percent(latest['stt_confidence']),
          ),
          LabeledValueRow(
            label: 'Pipeline',
            value: [latest['pipeline_version'], latest['asr_model']]
                .where((v) => v != null && v.toString().isNotEmpty)
                .join(' · ')
                .ifEmpty((data['model_version'] ?? '-').toString()),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// C3 — Combined profile
// ─────────────────────────────────────────────────────────────────────────
class TherapistCombinedProfileTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String studentId;
  final VoidCallback onChanged;

  const TherapistCombinedProfileTab({
    super.key,
    required this.data,
    required this.studentId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final available = data['classifier_available'] == true;
    final checklist = _list(
      data['coverage_checklist'],
    ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final probs = <String, double>{};
    _map(data['probabilities']).forEach((key, value) {
      final v = DashFormat.number(value);
      if (v != null) probs[key] = v;
    });
    final notes = _list(
      data['measurement_notes'],
    ).map((e) => e.toString()).toList();
    final window = _map(data['evidence_window']);
    final letterPractice = _map(window['letter_practice']);
    final letterSkills = _list(letterPractice['skills'])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Combined learning profile',
          style: DashText.heading(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          'Brings touch activities and reading together over the last ${window['days'] ?? 14} days. '
          'A potential pattern for professional review, not a diagnosis.',
          style: DashText.body(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        DashCard(
          title: 'Evidence available',
          subtitle:
              'The estimate runs only when touch and reading evidence are both present',
          child: checklist.isEmpty
              ? Text(DashFormat.missing, style: DashText.body(fontSize: 14))
              : CoverageChecklist(items: checklist),
        ),
        if ((DashFormat.number(letterPractice['attempts']) ?? 0) > 0)
          DashCard(
            title: 'Letter-practice context',
            subtitle:
                'Shown as learning evidence; automatic transcript matches are not pronunciation scores and do not enter the combined estimate.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final skill in letterSkills) ...[
                  Text(
                    '${skill['title']}: ${skill['letters_practiced']}/${skill['letters_total']} letters practised',
                    style: DashText.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${skill['attempts']} attempts · ${skill['clear_attempts']} clear recordings · ${skill['automatic_text_matches']} automatic text matches${skill['automatic_text_match_rate'] == null ? '' : ' (${((DashFormat.number(skill['automatic_text_match_rate']) ?? 0) * 100).round()}%)'}',
                    style: DashText.caption(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        if (!available)
          EmptyHint(
            icon: Icons.hourglass_empty_rounded,
            title: 'Estimate not ready yet',
            message: (data['skip_reason'] ?? 'More evidence is needed.')
                .toString(),
          )
        else
          DashCard(
            title: 'Pattern estimate',
            subtitle: 'A learning-pattern estimate for professional review, not a diagnosis.',
            accent: AppColors.calmBlue,
            trailing: data['low_agreement'] == true
                ? const StatusChip(label: 'Low agreement', tone: DashTone.watch)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProbabilityBar(probabilities: probs),
                if (data['low_agreement'] == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'The top two estimates are close; treat this as inconclusive.',
                    style: DashText.body(
                      fontSize: 14,
                      color: dashToneColor(DashTone.watch),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'What was observed alongside this estimate',
                  style: DashText.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final raw in _list(
                  data['shap_explanations'],
                ).whereType<Map>())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          (DashFormat.number(raw['contribution']) ?? 0) > 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (raw['plain_text'] ?? raw['feature']).toString(),
                            style: DashText.body(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'These observations describe associations; they do not establish causes.',
                  style: DashText.caption(fontSize: 12),
                ),
              ],
            ),
          ),
        if (notes.isNotEmpty)
          DashCard(
            title: 'Measurement notes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in notes)
                  Text('• $note', style: DashText.body(fontSize: 14)),
              ],
            ),
          ),
        _reviewCard(context, available),
        DashCard(
          title: 'Combined summary',
          subtitle: _list(data['sources_used']).isEmpty
              ? null
              : 'Based on: ${_list(data['sources_used']).join(', ')}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (data['summary_text'] ?? '').toString(),
                style: DashText.body(fontSize: 15),
              ),
              const SizedBox(height: 10),
              Text(
                'Suggested next step',
                style: DashText.body(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                (data['recommendation_text'] ?? '').toString(),
                style: DashText.body(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewCard(BuildContext context, bool available) {
    final latest = _map(data['latest_feedback']);
    final pattern = (data['primary_pattern'] ?? '').toString();
    return DashCard(
      title: 'Professional review',
      subtitle: latest.isEmpty
          ? 'Not reviewed yet'
          : 'Last review: ${DashFormat.words(latest['agreement'])} · ${DashFormat.date(latest['created_at'])}',
      child: !available
          ? Text(
              'Review becomes available once an estimate is shown.',
              style: DashText.body(fontSize: 14),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (latest['note'] != null) ...[
                  Text(
                    '"${latest['note']}"',
                    style: DashText.body(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                ],
                _FeedbackButtons(
                  onSelected: (agreement) async {
                    final saved = await showProfessionalFeedbackSheet(
                      context,
                      studentId: studentId,
                      component: 'c3',
                      estimateLabel: pattern,
                      initialAgreement: agreement,
                    );
                    if (saved) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Feedback saved.')),
                        );
                      }
                      onChanged();
                    }
                  },
                ),
              ],
            ),
    );
  }
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
