import 'package:flutter/material.dart';

class PatternAnswerToken extends StatefulWidget {
  final String imagePath;
  final VoidCallback onTap;
  final GlobalKey? tokenKey;
  final Animation<double>? shakeAnimation;
  final bool isHidden; // Used when the token is "flying" to the train

  const PatternAnswerToken({
    Key? key,
    required this.imagePath,
    required this.onTap,
    this.tokenKey,
    this.shakeAnimation,
    this.isHidden = false,
  }) : super(key: key);

  @override
  _PatternAnswerTokenState createState() => _PatternAnswerTokenState();
}

class _PatternAnswerTokenState extends State<PatternAnswerToken>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isHidden) {
      return Opacity(
        opacity: 0.0,
        child: _buildTokenContent(),
      );
    }

    Widget tokenWidget = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: _buildTokenContent(),
      ),
    );

    if (widget.shakeAnimation != null) {
      return AnimatedBuilder(
        animation: widget.shakeAnimation!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(widget.shakeAnimation!.value, 0),
            child: child,
          );
        },
        child: tokenWidget,
      );
    }

    return tokenWidget;
  }

  Widget _buildTokenContent() {
    return AnimatedBuilder(
      animation: widget.shakeAnimation ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        bool isShaking = false;
        if (widget.shakeAnimation != null && widget.shakeAnimation!.isAnimating) {
            isShaking = true;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          key: widget.tokenKey,
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: isShaking ? const Color(0xFFE87C6D).withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isShaking 
                  ? const Color(0xFFE87C6D)
                  : const Color(0xFFC4A484).withValues(alpha: 0.6), // Crate wood color border
              width: isShaking ? 4.0 : 3.0,
            ),
            boxShadow: [
              if (isShaking)
                BoxShadow(
                  color: const Color(0xFFE87C6D).withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/activity_icons/${widget.imagePath}',
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => const Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }
}
