import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const DashboardApp());
}

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backend Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String studentId = "STU_123";
  
  String monitoringOutput = "Waiting for data...";
  String interventionOutput = "Waiting for data...";
  String visualOutput = "Waiting for data...";

  void _runSimulation() async {
    setState(() {
      monitoringOutput = "Loading...";
      interventionOutput = "Loading...";
      visualOutput = "Loading...";
    });

    try {
      // 1. Simulate Telemetry (High Hesitation)
      final monRes = await ApiService.sendTelemetry(studentId, 4500, 80, 2.5);
      setState(() {
        monitoringOutput = "Cognitive Load: \${monRes['predicted_cognitive_load']}\\nIntervention Triggered: \${monRes['intervention_triggered']}";
      });

      // 2. Simulate Intervention Response based on high load
      int loadLevel = monRes['predicted_cognitive_load'] ?? 2;
      final intRes = await ApiService.triggerIntervention(studentId, loadLevel);
      setState(() {
        interventionOutput = "Weakest Skill: \${intRes['detected_weak_skill']}\\nIntervention: \${intRes['recommended_intervention']}\\nAction: \${intRes['ui_action']}";
      });

      // 3. Simulate Visual Service Layout fetch
      final visRes = await ApiService.getUILayout(studentId);
      final layout = visRes['recommended_layout'];
      setState(() {
        visualOutput = "Layout Action: \${layout['action_id']}\\nBionic Reading: \${layout['bionic_reading']}\\nHighlight Pilla: \${layout['highlight_pilla']}";
      });

    } catch (e) {
      setState(() {
        monitoringOutput = "Error: \$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services Dashboard (PoC)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _runSimulation,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
              child: const Text('Simulate Struggling Student Session', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            _buildOutputCard("1. Monitoring Service (LightGBM)", monitoringOutput, Colors.blue.shade100),
            _buildOutputCard("2. Intervention & Content Service", interventionOutput, Colors.orange.shade100),
            _buildOutputCard("3. Visual Service (RL Bandit)", visualOutput, Colors.green.shade100),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputCard(String title, String content, Color color) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
