import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class DrawAManTest extends StatefulWidget {
  const DrawAManTest({super.key});

  @override
  State<DrawAManTest> createState() => _DrawAManTestState();
}

class _DrawAManTestState extends State<DrawAManTest> with SingleTickerProviderStateMixin {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 6,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -5.0, end: 5.0).animate(_animController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3E5F5), // Solid playful purple
        image: DecorationImage(
          image: AssetImage('assets/images/student_icon.png'),
          opacity: 0.05,
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('රූපයක් අඳිමු', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), // Draw a picture
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.purple.shade900,
        ),
        body: SafeArea(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _animation.value * 2), // Bigger bounce
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/images/student_icon.png', // Huge Character Picture
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.brush_rounded, size: 180, color: Colors.purple),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'මිනිසෙක් අඳින්න', // Draw a man
                style: TextStyle(
                  fontSize: 34, 
                  fontWeight: FontWeight.w900, 
                  color: Colors.purple,
                  shadows: [
                    Shadow(color: Colors.white, blurRadius: 5, offset: Offset(2, 2))
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.purpleAccent, width: 8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          offset: const Offset(0, 12),
                          blurRadius: 0,
                        )
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Signature(
                      controller: _controller,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToolButton(
                      icon: Icons.clear_rounded,
                      color: Colors.red,
                      onTap: () => _controller.clear(),
                    ),
                    _buildToolButton(
                      icon: Icons.check_circle_rounded,
                      color: Colors.green,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('නියමයි! (Great!)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: StadiumBorder(),
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              offset: const Offset(0, 8),
              blurRadius: 0,
            )
          ],
        ),
        child: Icon(icon, size: 45, color: Colors.white),
      ),
    );
  }
}
