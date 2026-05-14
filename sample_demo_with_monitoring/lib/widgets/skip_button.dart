import 'package:flutter/material.dart';

class SkipButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? label;
  final String? taskName;
  final VoidCallback? onSkipped;

  const SkipButton({
    super.key,
    this.onPressed,
    this.label,
    this.taskName,
    this.onSkipped,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback effectiveOnPressed = onSkipped ?? onPressed ?? () {};
    final String effectiveLabel = label ?? 'මගහරින්න';

    return TextButton(
      onPressed: effectiveOnPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.green[800],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green[200]!),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            effectiveLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.skip_next_rounded, size: 18),
        ],
      ),
    );
  }
}
