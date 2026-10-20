import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../trend_chart.dart';

/// Shared building blocks for parent and therapist dashboards.
///
/// Rules applied everywhere:
///  * text never below 12 pt (see [DashText]);
///  * every label inside a Row is Expanded/Flexible, so nothing overflows;
///  * colour carries meaning only: good / watch / review / no data;
///  * missing values read "Not recorded yet", never 0 or a default.

enum DashTone { good, watch, review, neutral, info }

Color dashToneColor(DashTone tone) {
  switch (tone) {
    case DashTone.good:
      return AppColors.gentleGreenDark;
    case DashTone.watch:
      return const Color(0xFFB7791F);
    case DashTone.review:
      return AppColors.softCoralDark;
    case DashTone.info:
      return AppColors.calmBlueDark;
    case DashTone.neutral:
      return AppColors.textSecondary;
  }
}

/// Format helpers. All accept dynamic JSON values and return a display string.
class DashFormat {
  static const String missing = 'Not recorded yet';

  static double? number(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String percent(dynamic value, {String fallback = missing}) {
    final v = number(value);
    return v == null ? fallback : '${(v * 100).round()}%';
  }

  static String millis(dynamic value, {String fallback = missing}) {
    final v = number(value);
    if (v == null) return fallback;
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} s';
    return '${v.round()} ms';
  }

  static String count(dynamic value, {String fallback = '0'}) {
    final v = number(value);
    return v == null ? fallback : v.round().toString();
  }

  static String date(dynamic iso, {String fallback = missing}) {
    if (iso == null) return fallback;
    final parsed = DateTime.tryParse(iso.toString());
    if (parsed == null) return fallback;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = parsed.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String words(dynamic value) {
    final text = (value ?? '').toString().replaceAll('_', ' ').toLowerCase();
    if (text.isEmpty) return missing;
    return text[0].toUpperCase() + text.substring(1);
  }
}

class DashCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  const DashCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent?.withValues(alpha: 0.45) ?? AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: DashText.heading(fontSize: 17)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: DashText.caption()),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          if (title != null) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final DashTone tone;
  final IconData? icon;

  const StatusChip({super.key, required this.label, this.tone = DashTone.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = dashToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              style: DashText.caption(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact number tile: value on top, plain label underneath.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final DashTone tone;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.tone = DashTone.info,
  });

  /// Numbers stay large; word values ("Not enough rounds") use a smaller
  /// size, and a single long word scales down instead of breaking mid-word.
  Widget _value() {
    final isText = RegExp(r'[A-Za-z]{4,}').hasMatch(value);
    final text = Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: DashText.heading(
        fontSize: isText ? 16 : 19,
        color: AppColors.textPrimary,
      ),
    );
    if (value.contains(' ')) return text;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = dashToneColor(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _value(),
                const SizedBox(height: 2),
                Text(label, style: DashText.body(fontSize: 13, color: AppColors.textSecondary)),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: DashText.caption(fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays tiles out two per row on phones and four per row on wide screens.
class MetricGrid extends StatelessWidget {
  final List<Widget> children;
  const MetricGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

/// Label on the left, value on the right; long labels wrap instead of overflowing.
class LabeledValueRow extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const LabeledValueRow({super.key, required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DashText.body(fontSize: 14)),
                if (hint != null) Text(hint!, style: DashText.caption(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: DashText.body(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal 0–1 bar with the value and an optional count ("12 responses").
class PercentBar extends StatelessWidget {
  final String label;
  final double? value;
  final String? detail;
  final Color color;
  final double? marker; // e.g. the child's own earlier value
  /// Overrides the "NN%" text, e.g. "6 / 100" for a 0-100 index.
  final String? valueLabel;

  const PercentBar({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.color = AppColors.calmBlue,
    this.marker,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final v = value?.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: DashText.body(fontSize: 14))),
              Text(
                v == null ? DashFormat.missing : (valueLabel ?? '${(v * 100).round()}%'),
                style: DashText.body(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  if (v != null)
                    Container(
                      height: 10,
                      width: width * v,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    ),
                  if (marker != null)
                    Positioned(
                      left: (width * marker!.clamp(0.0, 1.0)) - 1,
                      top: -3,
                      child: Container(width: 2, height: 16, color: AppColors.textPrimary),
                    ),
                ],
              );
            },
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: DashText.caption(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyHint({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slateBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.calmBlueDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DashText.body(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(message, style: DashText.body(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Checklist of evidence sources: done / still needed, with a short detail.
class CoverageChecklist extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const CoverageChecklist({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: item['done'] == true ? AppColors.gentleGreenDark : AppColors.textHint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((item['label'] ?? '').toString(),
                          style: DashText.body(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (item['detail'] != null)
                        Text(item['detail'].toString(), style: DashText.caption(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Remote-monitoring prompts from the API (`alerts`).
class AlertList extends StatelessWidget {
  final List<dynamic> alerts;
  final bool showStudentName;
  const AlertList({super.key, required this.alerts, this.showStudentName = false});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const EmptyHint(
        icon: Icons.check_circle_outline_rounded,
        title: 'Nothing needs attention',
        message: 'No monitoring prompts for this period.',
      );
    }
    return Column(
      children: [
        for (final raw in alerts.whereType<Map>())
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (raw['severity'] == 'watch' ? dashToneColor(DashTone.watch) : dashToneColor(DashTone.info))
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  raw['severity'] == 'watch' ? Icons.visibility_outlined : Icons.info_outline_rounded,
                  size: 20,
                  color: raw['severity'] == 'watch' ? dashToneColor(DashTone.watch) : dashToneColor(DashTone.info),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    showStudentName && raw['student_name'] != null
                        ? '${raw['student_name']}: ${raw['message']}'
                        : (raw['message'] ?? '').toString(),
                    style: DashText.body(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One stacked bar for class probabilities, with a legend underneath.
class ProbabilityBar extends StatelessWidget {
  final Map<String, double> probabilities;
  const ProbabilityBar({super.key, required this.probabilities});

  static const _palette = [
    AppColors.gentleGreen,
    AppColors.calmBlue,
    AppColors.warmAmber,
    AppColors.softCoral,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = probabilities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    if (entries.isEmpty || total <= 0) {
      return Text(DashFormat.missing, style: DashText.body(fontSize: 14));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              for (var i = 0; i < entries.length; i++)
                Expanded(
                  flex: ((entries[i].value / total) * 1000).round().clamp(1, 1000).toInt(),
                  child: Container(height: 16, color: _palette[i % _palette.length]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _palette[i % _palette.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${entries[i].key} ${(entries[i].value * 100).round()}%',
                      style: DashText.body(fontSize: 13)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Trend chart whose x-axis uses the API's "S3 · 19 Oct" labels.
class DateTrendChart extends StatelessWidget {
  final String title;
  final List<dynamic> points;
  final String valueKey;
  final Color color;
  final double scale;
  final double? minY;
  final double? maxY;

  const DateTrendChart({
    super.key,
    required this.title,
    required this.points,
    this.valueKey = 'value',
    this.color = AppColors.calmBlue,
    this.scale = 1,
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final rows = points.whereType<Map>().toList();
    final values = rows.map((p) {
      final v = DashFormat.number(p[valueKey]);
      return v == null ? null : v * scale;
    }).toList();
    final labels = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final label = rows[i]['label'];
      labels.add(label == null ? 'S${i + 1}' : label.toString().split(' · ').first);
    }
    if (values.whereType<double>().length < 2) {
      return DashCard(
        title: title,
        child: Text('A trend appears after two or more sessions.', style: DashText.body(fontSize: 14)),
      );
    }
    return TrendChart(
      title: title,
      dataPoints: values,
      labels: labels,
      lineColor: color,
      minY: minY,
      maxY: maxY,
    );
  }
}
