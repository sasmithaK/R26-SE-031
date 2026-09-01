import 'package:flutter/material.dart';

class C1PatternCard extends StatelessWidget {
  final String pattern;
  final double probability;
  final String confidence;
  final Map<String, double> contributions;

  const C1PatternCard({
    super.key,
    required this.pattern,
    required this.probability,
    required this.confidence,
    this.contributions = const {},
  });

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
            const Text('Observed Learning Pattern', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(pattern.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Probability: ${probability.toStringAsFixed(0)}%'),
                Text('Confidence: $confidence'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: probability / 100,
                minHeight: 12,
                backgroundColor: Colors.indigo.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
              ),
            ),
            if (contributions.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Why did the system identify this pattern?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...contributions.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key),
                    Text((e.value > 0 ? '+' : '') + e.value.toStringAsFixed(2), style: TextStyle(color: e.value > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList(),
            ]
          ],
        ),
      ),
    );
  }
}
