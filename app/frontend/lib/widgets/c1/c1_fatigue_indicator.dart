import 'package:flutter/material.dart';

class C1FatigueIndicator extends StatelessWidget {
  final double score;
  final String state;

  const C1FatigueIndicator({
    super.key,
    required this.score,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    Color indicatorColor = Colors.green;
    if (score > 0.4) indicatorColor = Colors.orange;
    if (score > 0.7) indicatorColor = Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fatigue Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(score.toStringAsFixed(2), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: indicatorColor)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: indicatorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(state, style: TextStyle(color: indicatorColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
