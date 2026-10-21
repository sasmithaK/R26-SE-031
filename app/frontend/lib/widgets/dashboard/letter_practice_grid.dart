import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'dashboard_kit.dart';

/// Shared parent/therapist view of the letter attempts saved by C2.
class LetterPracticeGrid extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final bool detailed;

  const LetterPracticeGrid({
    super.key,
    required this.groups,
    this.detailed = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalAttempts = groups.fold<int>(
      0,
      (sum, group) =>
          sum +
          _letters(group).fold<int>(
            0,
            (subtotal, letter) => subtotal + _count(letter['attempts']),
          ),
    );
    return DashCard(
      title: 'Letter practice',
      subtitle: totalAttempts == 0
          ? 'Letter recordings will appear here as the child practices.'
          : '$totalAttempts practice recordings across the letter sets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in groups) ...[
            Text(
              group['title']?.toString() ?? 'Letters',
              style: DashText.heading(fontSize: 15),
            ),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 460 ? 9 : 6;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _letters(group).length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                    childAspectRatio: detailed ? 0.80 : 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = _letters(group)[index];
                    final attempts = _count(item['attempts']);
                    final clear = _count(item['clear_attempts']);
                    final matched = _count(item['matched_attempts']);
                    final sessions = _count(item['sessions']);
                    final rate = item['match_rate'] is num
                        ? (item['match_rate'] as num).toDouble()
                        : null;
                    final state = attempts == 0
                        ? 'Not tried'
                        : clear == 0
                        ? 'Recording unclear'
                        : clear >= 3 && sessions >= 2 && (rate ?? 0) >= .67
                        ? 'Repeated matches'
                        : 'Practiced';
                    final tone = attempts == 0
                        ? AppColors.textHint
                        : clear == 0
                        ? AppColors.warmAmber
                        : state == 'Repeated matches'
                        ? AppColors.gentleGreen
                        : AppColors.calmBlue;
                    return Semantics(
                      button: true,
                      label: '${item['letter']}, $state, $attempts attempts',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showDetail(
                          context,
                          item,
                          state,
                          attempts,
                          clear,
                          matched,
                          rate,
                          sessions,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tone.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tone.withValues(alpha: .55),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 2,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    item['letter']?.toString() ?? '·',
                                    style: AppTypography.sinhala(
                                      fontSize: detailed ? 19 : 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (detailed && attempts > 0)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '$attempts×',
                                      style: DashText.caption(
                                        fontSize: 9,
                                        color: tone,
                                      ),
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
              },
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _Legend(label: 'Not tried', color: AppColors.textHint),
              _Legend(label: 'Practiced', color: AppColors.calmBlue),
              _Legend(label: 'Recording unclear', color: AppColors.warmAmber),
              _Legend(label: 'Repeated matches', color: AppColors.gentleGreen),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tile status summarizes recording clarity and automatic text matches; it is not a pronunciation judgment.',
            style: DashText.caption(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _letters(Map<String, dynamic> group) =>
      (group['letters'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  static int _count(dynamic value) => value is num ? value.toInt() : 0;

  void _showDetail(
    BuildContext context,
    Map<String, dynamic> item,
    String state,
    int attempts,
    int clear,
    int matched,
    double? rate,
    int sessions,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item['letter']?.toString() ?? 'Letter',
          style: AppTypography.sinhala(
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state),
            const SizedBox(height: 8),
            Text('Practice recordings: $attempts'),
            Text('Clear recordings: $clear'),
            Text('Automatic text matches: $matched'),
            if (detailed) Text('Practice sessions: $sessions'),
            if (detailed && rate != null)
              Text('Match share: ${(rate * 100).round()}%'),
            if (item['last_practiced_at'] != null)
              Text('Last practiced: ${item['last_practiced_at']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: DashText.caption(fontSize: 10)),
    ],
  );
}
