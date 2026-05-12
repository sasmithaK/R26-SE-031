import 'package:flutter/material.dart';
import '../services/skip_service.dart';

class SkipButton extends StatefulWidget {
  final String taskName;
  final String? taskId;
  final VoidCallback? onSkipped;

  const SkipButton({super.key, required this.taskName, this.taskId, this.onSkipped});

  @override
  State<SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<SkipButton> {
  bool _processing = false;
  late final String _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = 'session_${widget.taskName}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _onSkipPressed() async {
    if (_processing) return;
    setState(() => _processing = true);
    final id = widget.taskId ?? 'skip_${widget.taskName}_${DateTime.now().millisecondsSinceEpoch}';
    final ok = await SkipService.recordSkip(
      taskId: id,
      taskName: widget.taskName,
      sessionId: _sessionId,
    );
    if (!mounted) return;
    setState(() => _processing = false);
    widget.onSkipped?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Skipped — recorded' : 'Skip recorded locally (failed to send)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Skip (ඉල්ලා ප්‍රශ්නයට)',
      icon: _processing ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(Icons.skip_next_rounded),
      onPressed: _onSkipPressed,
    );
  }
}
