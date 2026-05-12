import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/reading_theme.dart';

/// A friendly animated owl mascot that guides children through activities.
/// Bounces gently, shows speech-bubble messages, and reacts to taps.
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    this.message,
    this.size = 80,
    this.onTap,
  });

  final String? message;
  final double size;
  final VoidCallback? onTap;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          _SpeechBubble(text: widget.message!),
          const SizedBox(height: 6),
        ],
        AnimatedBuilder(
          animation: _bounce,
          builder: (_, child) {
            return Transform.translate(
              offset: Offset(0, -_bounce.value),
              child: child,
            );
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: _OwlBody(size: widget.size),
          ),
        ),
      ],
    );
  }
}

/// The owl face built from Flutter shapes — no image assets needed.
class _OwlBody extends StatelessWidget {
  const _OwlBody({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // body circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFFCC80), Color(0xFFEF6C00)],
                center: Alignment(0, -0.3),
                radius: 0.85,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF6C00).withOpacity(.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          // left eye
          Positioned(
            top: size * 0.22,
            left: size * 0.18,
            child: _Eye(radius: size * 0.16),
          ),
          // right eye
          Positioned(
            top: size * 0.22,
            right: size * 0.18,
            child: _Eye(radius: size * 0.16),
          ),
          // beak
          Positioned(
            top: size * 0.50,
            child: CustomPaint(
              size: Size(size * 0.22, size * 0.14),
              painter: _BeakPainter(),
            ),
          ),
          // left ear tuft
          Positioned(
            top: size * 0.03,
            left: size * 0.14,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: size * 0.12,
                height: size * 0.20,
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(size * 0.06),
                ),
              ),
            ),
          ),
          // right ear tuft
          Positioned(
            top: size * 0.03,
            right: size * 0.14,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(
                width: size * 0.12,
                height: size * 0.20,
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(size * 0.06),
                ),
              ),
            ),
          ),
          // belly
          Positioned(
            bottom: size * 0.10,
            child: Container(
              width: size * 0.44,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(size * 0.22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Container(
          width: radius * 1.0,
          height: radius * 1.0,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF1A1A1A),
          ),
          child: Align(
            alignment: const Alignment(-0.35, -0.35),
            child: Container(
              width: radius * 0.35,
              height: radius * 0.35,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeakPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF8F00);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF6C00).withOpacity(.40), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5D4037),
          height: 1.35,
        ),
      ),
    );
  }
}

/// Small inline mascot face for cards/buttons (no animation, just the face).
class MascotMini extends StatelessWidget {
  const MascotMini({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return _OwlBody(size: size);
  }
}
