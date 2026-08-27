import 'package:flutter/material.dart';

class PatternCarriage extends StatelessWidget {
  final String? imagePath;
  final Color accentColor;
  final bool isMissing;
  final bool isCorrectRevealed;
  final GlobalKey? carriageKey;
  final Animation<double>? bounceAnimation;

  const PatternCarriage({
    Key? key,
    this.imagePath,
    required this.accentColor,
    this.isMissing = false,
    this.isCorrectRevealed = false,
    this.carriageKey,
    this.bounceAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget carriageBody = SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Roof
          Container(
            width: 62,
            height: 10,
            decoration: BoxDecoration(
              color: isCorrectRevealed ? const Color(0xFF6DBE6D) : accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
          ),
          // Body
          Container(
            key: carriageKey,
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isCorrectRevealed 
                  ? const Color(0xFF6DBE6D).withValues(alpha: 0.15) 
                  : (isMissing ? Colors.white.withValues(alpha: 0.9) : Colors.white),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border.all(
                color: isCorrectRevealed 
                    ? const Color(0xFF6DBE6D) 
                    : (isMissing ? Colors.grey.withValues(alpha: 0.5) : accentColor.withValues(alpha: 0.4)),
                width: isCorrectRevealed ? 4.0 : (isMissing ? 2 : 1.5),
                style: BorderStyle.solid,
              ),
              boxShadow: [
                if (isCorrectRevealed)
                  BoxShadow(
                    color: const Color(0xFF6DBE6D).withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                else if (!isMissing)
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: _buildContent(),
          ),
          const SizedBox(height: 4),
          // Wheels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildWheel(16),
              _buildWheel(16),
            ],
          ),
        ],
      ),
    );

    if (bounceAnimation != null) {
      return AnimatedBuilder(
        animation: bounceAnimation!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -10 * bounceAnimation!.value),
            child: child,
          );
        },
        child: carriageBody,
      );
    }

    return carriageBody;
  }

  Widget _buildContent() {
    if (isMissing) {
      if (imagePath == null || imagePath!.isEmpty) {
        return const Center(
          child: Text(
            '?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        );
      }
    }
    
    if (imagePath == null || imagePath!.isEmpty) {
      return const SizedBox();
    }

    return Image.asset(
      'assets/images/activity_icons/$imagePath',
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => const Icon(
        Icons.image_outlined,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  Widget _buildWheel(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF333333), // dark grey/black
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
