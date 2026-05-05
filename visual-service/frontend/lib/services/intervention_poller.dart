import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// A mixin that any Flutter screen can add to automatically:
///   1. Poll the Visual Service every 10 seconds for pending interventions.
///   2. Show a non-intrusive snackbar or dialog when one arrives.
///   3. Fetch and apply the current layout preferences (font size, theme, spacing).
///
/// Usage:
///   class _MySreenState extends State<MyScreen> with InterventionPollerMixin { ... }
mixin InterventionPollerMixin<T extends StatefulWidget> on State<T> {
  final String _visualServiceBase = 'http://127.0.0.1:8004';

  Timer?           _pollTimer;
  Map<String, dynamic> currentLayout = {};

  // Override to provide the current student ID
  String get studentId => 'grade1_student_01';

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchLayout();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Layout Fetch ──────────────────────────────────────────────────────────
  /// Fetches the layout config (theme, font, spacing) for this student.
  Future<void> _fetchLayout() async {
    try {
      final resp = await http.post(
        Uri.parse('$_visualServiceBase/api/v1/ui/layout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'task_type': 'general'}),
      );
      if (resp.statusCode == 200 && mounted) {
        setState(() {
          currentLayout = jsonDecode(resp.body)['recommended_layout'] ?? {};
        });
      }
    } catch (_) {}
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkForIntervention();
    });
  }

  Future<void> _checkForIntervention() async {
    try {
      final resp = await http.get(
        Uri.parse('$_visualServiceBase/api/v1/intervention/status/$studentId'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['pending'] == true && mounted) {
          _applyIntervention(data['intervention_type'], data['ui_action']);
        }
      }
    } catch (_) {}
  }

  // ── Intervention Handler ──────────────────────────────────────────────────
  void _applyIntervention(String type, String action) {
    // Refresh layout after intervention
    _fetchLayout();

    if (type == 'Audio_Hint') {
      _showHintBanner(
        '💡 Audio Hint',
        'Listen carefully and try again!',
        Colors.blueAccent,
      );
    } else if (type == 'Syllable_Splitter') {
      _showHintBanner(
        '⏸️ Take a breath!',
        'Let\'s break this word into smaller pieces.',
        Colors.orangeAccent,
      );
    }
  }

  void _showHintBanner(String title, String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: color,
        content: Row(
          children: [
            const Icon(Icons.school, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  Text(message,  style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Layout Helpers ────────────────────────────────────────────────────────
  double get adaptiveCharSpacing =>
      (currentLayout['character_spacing'] as num?)?.toDouble() ?? 1.0;

  bool get highlightPilla =>
      currentLayout['highlight_pilla'] == true;

  bool get bionicReading =>
      currentLayout['bionic_reading'] == true;

  String get currentTheme =>
      currentLayout['theme'] ?? 'Daylight';

  Color get themeBackground {
    switch (currentTheme) {
      case 'High Contrast': return Colors.black;
      case 'Calm Blue':     return const Color(0xFFE3F2FD);
      default:              return const Color(0xFFFFFDE7); // Daylight
    }
  }

  Color get themeText {
    return currentTheme == 'High Contrast' ? Colors.white : Colors.black87;
  }
}
