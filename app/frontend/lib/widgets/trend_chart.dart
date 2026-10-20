import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class TrendChart extends StatelessWidget {
  final String title;
  final List<double?> dataPoints;
  final List<String>? labels;
  final Color lineColor;
  final String yAxisTitle;
  final double? minY;
  final double? maxY;

  const TrendChart({
    super.key,
    required this.title,
    required this.dataPoints,
    this.labels,
    this.lineColor = AppColors.calmBlue,
    this.yAxisTitle = '',
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.whereType<double>().where((v) => v.isFinite).isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: DashText.heading(fontSize: 16)),
            const SizedBox(height: 24),
            Center(child: Text("A trend appears after two or more sessions.", style: DashText.body(fontSize: 14))),
          ],
        ),
      );
    }

    final spots = dataPoints
        .asMap()
        .entries
        .map((e) => e.value == null || !e.value!.isFinite ? FlSpot.nullSpot : FlSpot(e.key.toDouble(), e.value!))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DashText.heading(fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.borderLight,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        // Show at most ~6 labels so they never overlap.
                        final step = (dataPoints.length / 6).ceil().clamp(1, 1000).toInt();
                        if (value != index.toDouble() || index % step != 0) {
                          return const SizedBox.shrink();
                        }
                        final text = labels != null && index >= 0 && index < labels!.length
                            ? labels![index]
                            : 'S${index + 1}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            text.length > 8 ? text.substring(0, 8) : text,
                            style: DashText.caption(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        // Hide the extra label fl_chart adds at a non-round max.
                        if (value == meta.max && value != meta.min &&
                            (value / meta.appliedInterval) % 1 != 0) {
                          return const SizedBox.shrink();
                        }
                        final text = meta.max.abs() >= 10
                            ? value.round().toString()
                            : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
                        return Text(
                          text,
                          style: DashText.caption(fontSize: 12, color: AppColors.textSecondary),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (dataPoints.length - 1).toDouble() > 0 ? (dataPoints.length - 1).toDouble() : 1.0,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: lineColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.1),
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
}
