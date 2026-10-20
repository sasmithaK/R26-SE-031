import 'package:flutter/material.dart';

import '../../services/therapist_dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/c3_evidence_chat_panel.dart';
import '../../widgets/dashboard/dashboard_kit.dart';

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
  'motor_interaction_index': 'Touch precision',
  'attention_stability_index': 'Attention steadiness',
};

const Map<String, String> kIndexHints = {
  'visual_processing_index': 'From first-touch time on picture and letter tasks',
  'phonological_task_index': 'Only measured on sound and letter-sound tasks',
  'motor_interaction_index': 'Fewer misclicks and hesitations score higher',
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
      return 'Measured, but methods disagree';
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
              Text('Your professional view', style: DashText.heading(fontSize: 19)),
              const SizedBox(height: 6),
              Text(
                'Model estimate: $estimateLabel. Your answer is stored with the measurements '
                'so the model can later be checked against professional judgement.',
                style: DashText.body(fontSize: 14, color: AppColors.textSecondary),
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
                      label: Text(option[1], style: DashText.body(fontSize: 14)),
                      selected: agreement == option[0],
                      onSelected: (_) => setSheetState(() => agreement = option[0]),
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
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
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
                Text(error!, style: DashText.body(fontSize: 14, color: AppColors.softCoralDark)),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                          } catch (e) {
                            setSheetState(() {
                              saving = false;
                              error = e.toString().replaceFirst('Exception: ', '');
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
            message: 'Measures appear after the child completes an activity in Skills 1-4.',
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

  Widget _sessionState(Map<String, dynamic> state, Map<String, dynamic> data) {
    final fatigueState = (data['fatigue_state'] ?? _map(state['fatigue'])['state'])?.toString();
    final load = _map(state['interaction_state'])['state']?.toString();
    final quality = DashFormat.number(_map(state['quality'])['quality_score']);
    return DashCard(
      title: 'During the latest session',
      subtitle: 'Fatigue compares the first and last three rounds',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip(
            label: 'Fatigue: ${fatigueState == null || fatigueState == 'UNAVAILABLE' ? 'needs 6+ rounds' : DashFormat.words(fatigueState)}',
            tone: _stateTone(fatigueState),
            icon: Icons.battery_charging_full_rounded,
          ),
          StatusChip(
            label: 'Effort: ${load == null ? DashFormat.missing : DashFormat.words(load)}',
            tone: _stateTone(load),
            icon: Icons.psychology_alt_outlined,
          ),
          StatusChip(
            label: 'Data quality: ${quality == null ? DashFormat.missing : '${(quality * 100).round()}%'}',
            tone: quality == null ? DashTone.neutral : (quality >= 0.8 ? DashTone.good : DashTone.watch),
            icon: Icons.fact_check_outlined,
          ),
        ],
      ),
    );
  }

  Widget _keyNumbers() {
    return DashCard(
      title: 'Key numbers',
      subtitle: 'Weighted by responses across the period',
      child: MetricGrid(
        children: [
          MetricTile(
            label: 'Correct on first try',
            value: DashFormat.percent(data['first_attempt_accuracy']),
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
            label: 'Median response time',
            value: DashFormat.millis(data['median_response_latency_ms']),
            icon: Icons.timer_outlined,
          ),
          MetricTile(
            label: 'Time to correct answer',
            value: DashFormat.millis(data['median_time_to_correct_ms']),
            icon: Icons.hourglass_bottom_rounded,
          ),
          MetricTile(
            label: 'Attempts per round',
            value: DashFormat.number(data['mean_attempts_per_round'])?.toStringAsFixed(1) ?? DashFormat.missing,
            icon: Icons.tag_rounded,
          ),
          MetricTile(
            label: 'Self-corrections',
            value: DashFormat.percent(data['correction_rate']),
            icon: Icons.edit_outlined,
          ),
        ],
      ),
    );
  }

  Widget _indices(Map<String, dynamic> state) {
    final indices = _map(state['indices']);
    final baseline = _map(state['baseline_indices']);
    final measured = kIndexNames.keys.where((k) => DashFormat.number(indices[k]) != null).toList();
    return DashCard(
      title: 'Learner indices (0-100)',
      subtitle: baseline.isEmpty
          ? 'Latest session'
          : 'Latest session; the black line marks the child\'s first measured session',
      child: measured.isEmpty
          ? Text('Indices appear after a complete activity session.', style: DashText.body(fontSize: 14))
          : Column(
              children: [
                for (final key in kIndexNames.keys)
                  PercentBar(
                    label: kIndexNames[key]!,
                    value: DashFormat.number(indices[key]) == null ? null : DashFormat.number(indices[key])! / 100,
                    marker: DashFormat.number(baseline[key]) == null ? null : DashFormat.number(baseline[key])! / 100,
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
          ? Text('No learning-area data in this period.', style: DashText.body(fontSize: 14))
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
      subtitle: total == 0 ? 'No first-try mistakes in this period' : 'Share of $total first-try mistakes, as reported by each task',
      child: total == 0
          ? Text('Nothing to show.', style: DashText.body(fontSize: 14))
          : Column(
              children: [
                for (final row in categories)
                  if ((DashFormat.number(row['count']) ?? 0) > 0 || row['key'] == 'unknown_error')
                    PercentBar(
                      label: (row['label'] ?? row['key']).toString(),
                      value: DashFormat.number(row['share']),
                      detail: '${DashFormat.count(row['count'])} mistakes',
                      color: row['key'] == 'unknown_error' ? AppColors.textHint : AppColors.warmAmber,
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
      subtitle: 'Medians from drag and trace activities ($sessions sessions)',
      child: sessions == 0
          ? Text('Appears after drag activities such as sorting, word building or sentence order.',
              style: DashText.body(fontSize: 14))
          : Column(
              children: [
                LabeledValueRow(label: 'Time to first touch', value: DashFormat.millis(k['time_to_first_touch_ms'])),
                LabeledValueRow(label: 'Touch hold time', value: DashFormat.millis(k['dwell_time_ms'])),
                LabeledValueRow(
                  label: 'Directness of finger path',
                  hint: '100% = straight line to the target',
                  value: DashFormat.percent(k['path_efficiency_ratio']),
                ),
                LabeledValueRow(
                  label: 'Movement smoothness (jerk)',
                  hint: 'Lower = smoother movement',
                  value: DashFormat.number(k['dimensionless_jerk'])?.toStringAsFixed(1) ?? DashFormat.missing,
                ),
                LabeledValueRow(
                  label: 'Look-alike letter choices',
                  hint: k['orthographic_confusion_note']?.toString(),
                  value: DashFormat.percent(k['orthographic_confusion_index'], fallback: 'Not measurable yet'),
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
    final predicted = kPatternNames[estimate['predicted_pattern']] ?? estimate['predicted_pattern']?.toString();
    return DashCard(
      title: 'Activity pattern estimate',
      subtitle: 'Random Forest, version ${estimate['model_version'] ?? '-'} · trained on synthetic data · for review only',
      accent: AppColors.calmBlue,
      child: !available
          ? Text(
              estimate['unavailable_reason']?.toString() ?? 'The estimate appears after a complete activity session.',
              style: DashText.body(fontSize: 14),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProbabilityBar(probabilities: probs),
                const SizedBox(height: 12),
                Text('Do you agree with "$predicted"?', style: DashText.body(fontSize: 14, fontWeight: FontWeight.w700)),
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
    final rows = _list(activityPerformance?['activities']).whereType<Map>().toList();
    return DashCard(
      title: 'By activity',
      subtitle: 'Same period as above',
      child: rows.isEmpty
          ? Text('No activity-level observations in this period.', style: DashText.body(fontSize: 14))
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
                                (row['activity_display'] ?? row['activity_name'] ?? row['activity_id']).toString(),
                                style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                [
                                  if (row['skill_name_en'] != null) row['skill_name_en'].toString(),
                                  '${DashFormat.count(row['trials'])} responses',
                                  if ((DashFormat.number(_map(row['voice'])['recordings']) ?? 0) > 0)
                                    '${DashFormat.count(_map(row['voice'])['usable_recordings'])} of ${DashFormat.count(_map(row['voice'])['recordings'])} recordings clear',
                                ].join(' · '),
                                style: DashText.caption(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DashFormat.percent(row['first_attempt_accuracy'], fallback: '-'),
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
        ..sort((a, b) => (DashFormat.number(b.value) ?? 0).compareTo(DashFormat.number(a.value) ?? 0));
      topIssue = '${DashFormat.words(sorted.first.key)} (${DashFormat.count(sorted.first.value)})';
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text((data['reporting_period'] ?? 'Recent recordings').toString(), style: DashText.heading(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          'Reading-aloud measures from Skills 5 and 6. Experimental measures, not a diagnosis.',
          style: DashText.body(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        if (recordings == 0)
          const EmptyHint(
            icon: Icons.mic_none_rounded,
            title: 'No reading recordings yet',
            message: 'Ask the child to try Reading Comprehension (Skill 5) or Textbook Reading (Skill 6).',
          )
        else ...[
          DashCard(
            title: 'Recording health',
            subtitle: 'Can reading be measured reliably at home?',
            child: MetricGrid(
              children: [
                MetricTile(label: 'Recordings', value: '$recordings', icon: Icons.mic_rounded),
                MetricTile(
                  label: 'Clear enough to measure',
                  value: DashFormat.percent(data['usable_recording_rate']),
                  icon: Icons.graphic_eq_rounded,
                  tone: (DashFormat.number(data['usable_recording_rate']) ?? 0) >= 0.5 ? DashTone.good : DashTone.watch,
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
        if (latest['recorded_at'] != null) DashFormat.date(latest['recorded_at']),
      ].join(' · '),
      trailing: StatusChip(label: _readingStatusLabel(status), tone: _stateTone(status)),
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
          LabeledValueRow(label: 'Letters read as expected', value: DashFormat.percent(latest['grapheme_accuracy'])),
          LabeledValueRow(label: 'Words read as expected', value: DashFormat.percent(latest['word_accuracy'])),
          LabeledValueRow(
            label: 'Reading rate',
            value: DashFormat.number(latest['reading_rate_wpm']) == null
                ? DashFormat.missing
                : '${DashFormat.number(latest['reading_rate_wpm'])!.round()} words/min',
          ),
          LabeledValueRow(
            label: 'Time to start speaking',
            hint: 'After the record button was pressed',
            value: DashFormat.millis(latest['voice_onset_ms'] ?? latest['acoustic_latency_ms']),
          ),
          LabeledValueRow(
            label: 'Time to press record',
            hint: 'Interaction time, not reading time',
            value: DashFormat.millis(latest['record_start_delay_ms']),
          ),
          LabeledValueRow(label: 'Pauses (0.2-3 s)', value: DashFormat.count(latest['pause_count'], fallback: DashFormat.missing)),
          LabeledValueRow(label: 'Time spent pausing', value: DashFormat.percent(latest['pause_ratio'])),
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
      decoration: BoxDecoration(color: AppColors.slateBg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expected', style: DashText.caption(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(expected.isEmpty ? '-' : expected, style: DashText.sinhala(fontSize: 17)),
          const SizedBox(height: 8),
          Text('Heard by speech recognition', style: DashText.caption(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(recognized.isEmpty ? '(nothing recognised)' : recognized, style: DashText.sinhala(fontSize: 17)),
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
          ? Text('No sentences in this period.', style: DashText.body(fontSize: 14))
          : Column(
              children: [
                for (final item in items) _itemRow(Map<String, dynamic>.from(item)),
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
      spans.add(TextSpan(
        text: '$word ',
        style: DashText.sinhala(
          fontSize: 16,
          color: wrong ? AppColors.softCoralDark : AppColors.textPrimary,
          fontWeight: wrong ? FontWeight.w700 : FontWeight.w500,
        ),
      ));
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
              Text(DashFormat.percent(item['grapheme_accuracy'], fallback: '-'),
                  style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          if (spans.isNotEmpty)
            RichText(text: TextSpan(children: spans))
          else
            Text((item['expected_text'] ?? '').toString(), style: DashText.sinhala(fontSize: 16)),
          const SizedBox(height: 6),
          StatusChip(label: _readingStatusLabel(status), tone: _stateTone(status)),
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
        title: Text('Research measures (exploratory)', style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700)),
        subtitle: Text('Not used in the reading score', style: DashText.caption(fontSize: 13)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          LabeledValueRow(
            label: 'Voice steadiness (jitter)',
            hint: 'Unreliable on short child recordings',
            value: DashFormat.number(latest['jitter'])?.toStringAsFixed(3) ?? DashFormat.missing,
          ),
          LabeledValueRow(
            label: 'Loudness steadiness (shimmer)',
            value: DashFormat.number(latest['shimmer'])?.toStringAsFixed(3) ?? DashFormat.missing,
          ),
          LabeledValueRow(
            label: 'Spoken beats vs expected syllables',
            value: DashFormat.count(latest['peak_delta'], fallback: DashFormat.missing),
          ),
          LabeledValueRow(
            label: 'Speech-recognition confidence',
            hint: 'Model certainty about the transcript, not reading accuracy',
            value: DashFormat.percent(latest['stt_confidence']),
          ),
          LabeledValueRow(label: 'Pipeline', value: (data['model_version'] ?? '-').toString()),
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
    final checklist = _list(data['coverage_checklist'])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final probs = <String, double>{};
    _map(data['probabilities']).forEach((key, value) {
      final v = DashFormat.number(value);
      if (v != null) probs[key] = v;
    });
    final notes = _list(data['measurement_notes']).map((e) => e.toString()).toList();
    final window = _map(data['evidence_window']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Combined learning profile', style: DashText.heading(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          'Brings touch activities and reading together over the last ${window['days'] ?? 14} days. '
          'A potential pattern for professional review, not a diagnosis.',
          style: DashText.body(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        DashCard(
          title: 'Evidence available',
          subtitle: 'The estimate runs only when touch and reading evidence are both present',
          child: checklist.isEmpty
              ? Text(DashFormat.missing, style: DashText.body(fontSize: 14))
              : CoverageChecklist(items: checklist),
        ),
        if (!available)
          EmptyHint(
            icon: Icons.hourglass_empty_rounded,
            title: 'Estimate not ready yet',
            message: (data['skip_reason'] ?? 'More evidence is needed.').toString(),
          )
        else
          DashCard(
            title: 'Pattern estimate',
            subtitle: 'XGBoost ${data['model_version'] ?? ''} · trained on synthetic data · for review only',
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
                  Text('The top two estimates are close; treat this as inconclusive.',
                      style: DashText.body(fontSize: 14, color: dashToneColor(DashTone.watch))),
                ],
                const SizedBox(height: 14),
                Text('What influenced the estimate', style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final raw in _list(data['shap_explanations']).whereType<Map>())
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
                  'Contributions show what moved the model score, not causes.',
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
              children: [for (final note in notes) Text('• $note', style: DashText.body(fontSize: 14))],
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
              Text((data['summary_text'] ?? '').toString(), style: DashText.body(fontSize: 15)),
              const SizedBox(height: 10),
              Text('Suggested next step', style: DashText.body(fontSize: 14, fontWeight: FontWeight.w700)),
              Text((data['recommendation_text'] ?? '').toString(), style: DashText.body(fontSize: 14)),
            ],
          ),
        ),
        if (studentId.isNotEmpty) ...[
          const SizedBox(height: 4),
          C3EvidenceChatPanel(studentId: studentId),
        ],
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
          ? Text('Review becomes available once an estimate is shown.', style: DashText.body(fontSize: 14))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (latest['note'] != null) ...[
                  Text('"${latest['note']}"', style: DashText.body(fontSize: 14)),
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
