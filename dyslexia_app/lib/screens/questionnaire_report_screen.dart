import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/questionnaire_db.dart';

class QuestionnaireReportScreen extends StatefulWidget {
  const QuestionnaireReportScreen({super.key});

  @override
  State<QuestionnaireReportScreen> createState() => _QuestionnaireReportScreenState();
}

class _QuestionnaireReportScreenState extends State<QuestionnaireReportScreen> {
  late Future<List<Map<String, dynamic>>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _submissionsFuture = QuestionnaireDb.instance.fetchAllSubmissions();
  }

  String _formatDate(String isoDate) {
    final dateTime = DateTime.tryParse(isoDate);
    if (dateTime == null) {
      return isoDate;
    }

    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ප්රගති නිරීක්ෂණය'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _submissionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'දත්ත ලබාගැනීමේ දෝෂයකි: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final submissions = snapshot.data ?? <Map<String, dynamic>>[];
          if (submissions.isEmpty) {
            return const Center(
              child: Text(
                'තවම පුරවා ඇති ප්රශ්නාවලි දත්ත නොමැත.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final total = submissions.length;
          final averageScore = submissions
                  .map((e) => (e['part_one_score'] as int?) ?? 0)
                  .fold<int>(0, (a, b) => a + b) /
              total;

          final riskCounts = <String, int>{
            'අවදානම අඩු': 0,
            'මධ්යම': 0,
            'ඉහළ': 0,
          };

          for (final row in submissions) {
            final score = (row['part_one_score'] as int?) ?? 0;
            if (score == 0) {
              riskCounts['අවදානම අඩු'] = riskCounts['අවදානම අඩු']! + 1;
            } else if (score <= 75) {
              riskCounts['මධ්යම'] = riskCounts['මධ්යම']! + 1;
            } else {
              riskCounts['ඉහළ'] = riskCounts['ඉහළ']! + 1;
            }
          }

          final latestForTrend = submissions.reversed.take(7).toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _submissionsFuture = QuestionnaireDb.instance.fetchAllSubmissions();
              });
              await _submissionsFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summaryCard('සම්පූර්ණ පුරවීම්', total.toString(), Colors.teal),
                    _summaryCard('සාමාන්ය ලකුණු', averageScore.toStringAsFixed(1), Colors.blue),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'අවදානම් බෙදාහැරීම',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 230,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: [
                        PieChartSectionData(
                          value: riskCounts['අවදානම අඩු']!.toDouble(),
                          color: const Color(0xFF66BB6A),
                          title: 'අඩු\n${riskCounts['අවදානම අඩු']}',
                          radius: 80,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        PieChartSectionData(
                          value: riskCounts['මධ්යම']!.toDouble(),
                          color: const Color(0xFFFFCA28),
                          title: 'මධ්යම\n${riskCounts['මධ්යම']}',
                          radius: 80,
                          titleStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        PieChartSectionData(
                          value: riskCounts['ඉහළ']!.toDouble(),
                          color: const Color(0xFFEF5350),
                          title: 'ඉහළ\n${riskCounts['ඉහළ']}',
                          radius: 80,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'අවසන් පුරවීම් ලකුණු ප්රවණතාව',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: BarChart(
                    BarChartData(
                      maxY: 220,
                      barGroups: [
                        for (int i = 0; i < latestForTrend.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: ((latestForTrend[i]['part_one_score'] as int?) ?? 0).toDouble(),
                                width: 16,
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                      ],
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text('පුරවීම ${idx + 1}', style: const TextStyle(fontSize: 11)),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'නවතම දත්ත',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...submissions.take(10).map((row) {
                  final role = row['respondent_role'] as String? ?? '';
                  final respondent = row['respondent_name'] as String? ?? '';
                  final student = row['student_name'] as String? ?? '';
                  final score = row['part_one_score'] as int? ?? 0;
                  final date = _formatDate(row['created_at'] as String? ?? '');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('$student - ලකුණු: $score'),
                      subtitle: Text('පුරවූவர்: $respondent ($role)\n$date'),
                      isThreeLine: true,
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
