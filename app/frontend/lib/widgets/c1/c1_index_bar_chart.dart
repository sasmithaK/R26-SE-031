import 'package:flutter/material.dart';

class C1IndexBarChart extends StatelessWidget {
  final double visualProcessing;
  final double phonological;
  final double motor;
  final double attention;

  const C1IndexBarChart({
    super.key,
    required this.visualProcessing,
    required this.phonological,
    required this.motor,
    required this.attention,
  });

  Widget _buildBar(BuildContext context, String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 12,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Learner Indices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildBar(context, 'Visual Processing', visualProcessing, Colors.blue),
            _buildBar(context, 'Phonological Tasks', phonological, Colors.purple),
            _buildBar(context, 'Motor Interaction', motor, Colors.orange),
            _buildBar(context, 'Attention Stability', attention, Colors.green),
          ],
        ),
      ),
    );
  }
}
