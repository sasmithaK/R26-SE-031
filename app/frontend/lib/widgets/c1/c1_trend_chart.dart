import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/c1/c1_trend_point.dart';

class C1TrendChart extends StatelessWidget {
  final List<C1TrendPoint> points;
  final String metric;
  final String label;

  const C1TrendChart({
    super.key,
    required this.points,
    required this.metric,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No trend data available.'),
      ));
    }

    final sortedPoints = List<C1TrendPoint>.from(points)..sort((a, b) => a.sessionIndex.compareTo(b.sessionIndex));
    
    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var i = 0; i < sortedPoints.length; i++) {
      double val = 0.0;
      switch (metric) {
        case 'accuracy': val = sortedPoints[i].accuracy * 100; break;
        case 'latency': val = sortedPoints[i].medianLatencyMs / 1000.0; break;
        case 'fatigue': val = sortedPoints[i].fatigueScore; break;
        case 'hesitation': val = sortedPoints[i].hesitationRate * 100; break;
      }
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (minY == maxY) { minY -= 1; maxY += 1; }
    if (metric == 'accuracy' || metric == 'hesitation') { minY = 0; maxY = 100; }
    if (metric == 'fatigue') { minY = 0; maxY = 1; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        AspectRatio(
          aspectRatio: 1.8,
          child: Padding(
            padding: const EdgeInsets.only(right: 18.0, left: 12.0, top: 24, bottom: 12),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Theme.of(context).primaryColor.withOpacity(0.1)),
                  ),
                ],
                minY: minY,
                maxY: maxY,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedPoints.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('S${sortedPoints[value.toInt()].sessionIndex}', style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
