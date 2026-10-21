import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A vibrant gradient button with press animation for kid-friendly UI.
/// Dyslexia-accessible: calm blue gradient, sentence case, 18pt+ text.
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final LinearGradient? gradient;
  final double width;
  final double height;
  final IconData? icon;
  final Color? textColor;
  final Color? iconColor;
  final FontWeight? fontWeight;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradient,
    this.width = double.infinity,
    this.height = 56,
    this.icon,
    this.textColor,
    this.iconColor,
    this.fontWeight,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.gradient ?? AppColors.blueButtonGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.calmBlueDark.withValues(alpha: 0.35),
                blurRadius: 15,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: widget.iconColor ?? Colors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                widget.text,
                style: AppTypography.button(
                  fontSize: 18,
                  fontWeight: widget.fontWeight ?? FontWeight.w700,
                  color: widget.textColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined button variant for secondary actions.
class OutlinedGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const OutlinedGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  State<OutlinedGradientButton> createState() => _OutlinedGradientButtonState();
}

class _OutlinedGradientButtonState extends State<OutlinedGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.calmBlue.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              widget.text,
              style: AppTypography.button(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.calmBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
