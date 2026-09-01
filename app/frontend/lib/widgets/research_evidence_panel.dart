import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

String metricText(dynamic value, {String suffix = '', double scale = 1, int decimals = 2}) {
  if (value is! num || !value.isFinite) return 'Unavailable';
  return '${(value * scale).toStringAsFixed(decimals)}$suffix';
}

class DashboardSection extends StatelessWidget {
  final Map<String, dynamic>? data;
  final Widget child;
  final VoidCallback onRetry;
  const DashboardSection({super.key, required this.data, required this.child, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    if (data?['_error'] != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 36), const SizedBox(height: 12),
        Text(data!['_error'].toString(), textAlign: TextAlign.center),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ])));
    }
    return Column(children: [
      Expanded(child: child),
    ]);
  }
}

class ResearchEvidencePanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool simplified;
  const ResearchEvidencePanel({super.key, required this.data, this.simplified = false});
  @override
  Widget build(BuildContext context) {
    final components = data['components'] as List? ?? [];
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('PP2 Research Evidence', style: AppTypography.heading(fontSize: 22)),
      const SizedBox(height: 12),
      const Text('Objective alignment • Baseline comparison • Measured claims • Limitations'),
      if (data['evaluation_id'] != null) Text('Evaluation: ${data['evaluation_id']}'),
      if (data['sample_count'] != null) Text('Synthetic samples: ${data['sample_count']} | Split: ${data['split_description']}'),
      if (components.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(data['message']?.toString() ?? 'No evaluation has been imported.')),
      ...components.map((raw) {
        final c = Map<String, dynamic>.from(raw as Map);
        final comparisons = c['comparisons'] as List? ?? [];
        return Card(margin: const EdgeInsets.symmetric(vertical: 10), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${c['component']} — ${c['objective']}', style: AppTypography.heading(fontSize: 17)),
          const SizedBox(height: 8), Text('Evidence: ${c['evidence_type']}'),
          Text('Input: ${c['input_summary']}'),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
            DataColumn(label: Text('Method')), DataColumn(label: Text('Metric')), DataColumn(label: Text('Value')), DataColumn(label: Text('N')),
          ], rows: comparisons.map((r) => DataRow(cells: [
            DataCell(Text('${r['method']}')), DataCell(Text('${r['metric']}')), DataCell(Text(metricText(r['value'], decimals: 4))), DataCell(Text('${r['n']}')),
          ])).toList())),
          const SizedBox(height: 10), Text('Supported claim: ${c['claim']}'),
          Text('Limitation: ${c['limitation']}', style: const TextStyle(fontStyle: FontStyle.italic)),
          if (!simplified && c['artifacts'] != null) Text('Artifacts: ${c['artifacts']}'),
        ])));
      }),
      const SizedBox(height: 16),
      const Text('After PP2: evaluate with consented Grade 1 participants and teacher/therapist references. Synthetic performance does not establish clinical validity, age norms, or learning benefit.'),
    ]);
  }
}
