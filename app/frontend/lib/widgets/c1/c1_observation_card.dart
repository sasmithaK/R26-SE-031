import 'package:flutter/material.dart';

class C1ObservationCard extends StatelessWidget {
  final List<String> observations;
  final List<String> recommendedPractice;

  const C1ObservationCard({
    super.key,
    required this.observations,
    required this.recommendedPractice,
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
            const Text('Learning Observation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...observations.map((obs) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(obs, style: const TextStyle(fontSize: 14))),
                ],
              ),
            )),
            if (recommendedPractice.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Recommended practice:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...recommendedPractice.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rec, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              )),
            ]
          ],
        ),
      ),
    );
  }
}
