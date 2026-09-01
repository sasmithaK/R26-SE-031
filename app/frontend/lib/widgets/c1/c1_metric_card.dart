import 'package:flutter/material.dart';

class C1MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? status;
  final Color? color;

  const C1MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.status,
    this.color,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color ?? Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500])),
            ],
            if (status != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(status!, style: TextStyle(color: color ?? Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
