import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated speech bubble with typewriter text effect.
/// Dyslexia-accessible: mint green bg, dark grey text, enhanced spacing.
class SpeechBubble extends StatefulWidget {
  final String text;
  final double maxWidth;
  final Duration delay;

  const SpeechBubble({
    super.key,
    required this.text,
    this.maxWidth = 300,
    this.delay = const Duration(milliseconds: 400),
  });

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _typeController;
  late Animation<double> _scaleAnimation;
  Timer? _delayTimer;

  // Break text into grapheme clusters to safely handle all characters
  late List<String> _characters;

  @override
  void initState() {
    super.initState();

    _characters = widget.text.characters.toList();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _typeController = AnimationController(
      duration: Duration(milliseconds: _characters.length * 45),
      vsync: this,
    );

    _delayTimer = Timer(widget.delay, () {
      if (mounted) {
        _scaleController.forward().then((_) {
          if (mounted) _typeController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _scaleController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.mintBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gentleGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gentleGreen.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _typeController,
              builder: (context, child) {
                final charCount = (_typeController.value * _characters.length)
                    .round();
                final displayText = _characters.take(charCount).join();
                return Text(
                  displayText,
                  style: AppTypography.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBrown,
                  ),
                  textAlign: TextAlign.left,
                );
              },
            ),
          ),
          // Triangle tail pointing down
          CustomPaint(size: const Size(24, 14), painter: _BubbleTailPainter()),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gentleGreen.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);

    // Fill the inside with mintBg
    final fillPaint = Paint()
      ..color = AppColors.mintBg
      ..style = PaintingStyle.fill;

    final fillPath = Path()
      ..moveTo(1.5, 0)
      ..lineTo(size.width / 2, size.height - 2)
      ..lineTo(size.width - 1.5, 0)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
