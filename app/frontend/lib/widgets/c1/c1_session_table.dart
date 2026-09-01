import 'package:flutter/material.dart';
import '../../models/c1/c1_session_summary.dart';

class C1SessionTable extends StatelessWidget {
  final List<C1SessionSummary> sessions;
  final Function(String) onSessionTapped;

  const C1SessionTable({
    super.key,
    required this.sessions,
    required this.onSessionTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Session')),
            DataColumn(label: Text('Accuracy')),
            DataColumn(label: Text('Median Time')),
            DataColumn(label: Text('Hesitation')),
            DataColumn(label: Text('Fatigue')),
          ],
          rows: sessions.map((s) => DataRow(
            onSelectChanged: (_) => onSessionTapped(s.sessionId),
            cells: [
              DataCell(Text('S${s.sessionIndex}')),
              DataCell(Text('${(s.accuracy * 100).toStringAsFixed(0)}%')),
              DataCell(Text('${(s.medianLatencyMs / 1000).toStringAsFixed(1)}s')),
              DataCell(Text('${(s.hesitationRate * 100).toStringAsFixed(0)}%')),
              DataCell(Text(s.fatigueScore.toStringAsFixed(2))),
            ],
          )).toList(),
        ),
      ),
    );
  }
}
