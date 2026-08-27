import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

/// Skill Detail Progress Screen — Drill-down for a specific skill
/// showing activity-by-activity breakdown and performance trend.
class SkillDetailProgressScreen extends StatelessWidget {
  final String skillName;
  final Color skillColor;
  final dynamic skillIcon;
  final Map<String, dynamic> studentData;
  final List<dynamic> events;

  const SkillDetailProgressScreen({
    super.key,
    required this.skillName,
    required this.skillColor,
    required this.skillIcon,
    required this.studentData,
    this.events = const [],
  });

  // Dynamic activity data derived from actual telemetry events
  List<Map<String, dynamic>> get _activities {
    if (events.isEmpty) {
      return [
        {'name': LocalizationService.instance.t('no_attempts_yet'), 'score': 0, 'time': '--', 'attempts': 0, 'status': 'locked'},
      ];
    }
    
    return List.generate(events.length, (index) {
      final ev = events[index];
      final rNumber = ev['round_number'] ?? (index + 1);
      final score = ev['score'] as int? ?? 0;
      final latencyMs = ev['total_round_latency_ms'] as int? ?? 0;
      
      final mins = latencyMs ~/ 60000;
      final secs = (latencyMs % 60000) ~/ 1000;
      final timeStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
      
      return {
        'name': '${LocalizationService.instance.t('attempt')} $rNumber',
        'score': score,
        'time': timeStr,
        'attempts': 1,
        'status': 'completed',
      };
    }).reversed.toList();
  }

  // Dynamic trend data (last 7 sessions accuracy %)
  List<int> get _trendData {
    if (events.isEmpty) return [0, 0, 0, 0, 0, 0, 0];
    final scores = events.map((e) => e['score'] as int? ?? 0).toList();
    if (scores.length >= 7) {
      return scores.sublist(scores.length - 7);
    } else {
      final padded = List<int>.filled(7, 0);
      for (int i = 0; i < scores.length; i++) {
        padded[7 - scores.length + i] = scores[i];
      }
      return padded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = studentData['first_name'] ?? 'student';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, name),
              const SizedBox(height: 24),
              _buildTrendChart(context),
              const SizedBox(height: 24),
              _buildActivityBreakdown(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(BuildContext context, String childName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            skillColor.withValues(alpha: 0.08),
            AppColors.cream,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: skillColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: FaIcon(skillIcon, size: 26, color: skillColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.instance.t(skillName.toLowerCase().replaceAll(' ', '_')),
                      style: AppTypography.heading(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "$childName${LocalizationService.instance.t('child_progress_suffix')}",
                      style: AppTypography.caption(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Overall accuracy badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: skillColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_trendData.last}%',
                      style: AppTypography.heading(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: skillColor,
                      ),
                    ),
                    Text(
                      LocalizationService.instance.t('accuracy'),
                      style: AppTypography.caption(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: skillColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Trend Chart ───
  Widget _buildTrendChart(BuildContext context) {
    final maxVal = _trendData.reduce((a, b) => a > b ? a : b).toDouble() > 0 
        ? _trendData.reduce((a, b) => a > b ? a : b).toDouble() 
        : 100.0;

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
            Text(
              LocalizationService.instance.t('performance_trend'),
              style: AppTypography.heading(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              LocalizationService.instance.t('accuracy_over_sessions'),
              style: AppTypography.caption(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: CustomPaint(
                size: Size(MediaQuery.of(context).size.width - 80, 120),
                painter: _TrendLinePainter(
                  data: _trendData,
                  color: skillColor,
                  maxVal: maxVal,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                  7,
                  (i) => Text(
                        'S${i + 1}',
                        style: AppTypography.caption(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      )),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Activity Breakdown ───
  Widget _buildActivityBreakdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationService.instance.t('activity_breakdown'),
            style: AppTypography.heading(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.calmBlue,
            ),
          ),
          const SizedBox(height: 16),
          ..._activities.map((a) => _buildActivityRow(a)),
        ],
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> activity) {
    final isLocked = activity['status'] == 'locked';
    final score = activity['score'] as int;
    Color scoreColor;
    if (score >= 80) {
      scoreColor = AppColors.gentleGreen;
    } else if (score >= 60) {
      scoreColor = AppColors.warmAmber;
    } else {
      scoreColor = AppColors.softCoral;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocked
            ? AppColors.borderLight.withValues(alpha: 0.5)
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked ? AppColors.borderLight : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLocked
                  ? AppColors.borderLight
                  : skillColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isLocked
                  ? const FaIcon(FontAwesomeIcons.lock,
                      size: 14, color: AppColors.textHint)
                  : FaIcon(FontAwesomeIcons.check,
                      size: 14, color: skillColor),
            ),
          ),
          const SizedBox(width: 14),
          // Activity info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['name'] as String,
                  style: AppTypography.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isLocked
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                ),
                if (!isLocked)
                  Text(
                    '${activity['time']} · ${activity['attempts']} ${(activity['attempts'] as int) > 1 ? LocalizationService.instance.t('attempts') : LocalizationService.instance.t('attempt')}',
                    style: AppTypography.caption(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          ),
          // Score
          if (!isLocked)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$score%',
                style: AppTypography.caption(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the trend line chart
class _TrendLinePainter extends CustomPainter {
  final List<int> data;
  final Color color;
  final double maxVal;

  _TrendLinePainter({
    required this.data,
    required this.color,
    required this.maxVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.2), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxVal) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (data[i - 1] / maxVal) * size.height;
        final controlX1 = prevX + (x - prevX) / 2;
        final controlX2 = prevX + (x - prevX) / 2;
        path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        fillPath.cubicTo(controlX1, prevY, controlX2, y, x, y);
      }

      // Dots
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(
          Offset(x, y), 2, Paint()..color = Colors.white);
    }

    // Fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Line
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
