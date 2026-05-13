import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/adaptive_state.dart';

class ABTestingRunner extends StatelessWidget {
  const ABTestingRunner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AdaptiveState>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("A/B Evaluation Runner", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 48),
            Text(
              "Select Evaluation Branch",
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildBranchCard(
                    context,
                    title: "Baseline (Fixed UI)",
                    description: "Standard typography without real-time adaptation. Used as a control group.",
                    icon: Icons.lock_outline,
                    color: Colors.blue,
                    isSelected: state.evaluationMode == EvaluationMode.fixed,
                    onTap: () => state.setEvaluationMode(EvaluationMode.fixed),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildBranchCard(
                    context,
                    title: "Research (Adaptive UI)",
                    description: "Full LinUCB-driven adaptation based on MBSV telemetry vectors.",
                    icon: Icons.auto_awesome,
                    color: Colors.indigo,
                    isSelected: state.evaluationMode == EvaluationMode.adaptive,
                    onTap: () => state.setEvaluationMode(EvaluationMode.adaptive),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: SizedBox(
                width: 300,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/word_matching'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("START EVALUATION TASK", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Colors.amber, size: 32),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Research Protocol",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Text(
                  "This runner enables researchers to compare student performance between the standard UI and the AI-driven adaptive interface.",
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 24),
            Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(color: Colors.black45)),
            const SizedBox(height: 24),
            if (isSelected)
              Row(
                children: [
                  Icon(Icons.check_circle, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text("ACTIVE BRANCH", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
