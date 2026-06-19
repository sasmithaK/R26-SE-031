import 'package:flutter/material.dart';
import 'dart:ui'; // For PathMetrics
import 'package:audioplayers/audioplayers.dart';
import 'letter_bubble_game_alapilla.dart';

class AlapillaLearningScreen extends StatefulWidget {
  const AlapillaLearningScreen({super.key});

  @override
  State<AlapillaLearningScreen> createState() => _AlapillaLearningScreenState();
}

class _AlapillaLearningScreenState extends State<AlapillaLearningScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _canGoNext = true;

  void _nextPage() {
    if (_currentPage < 7) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LetterBubbleGameAlapilla()),
      );
    }
  }

  void _onInteractionComplete() {
    setState(() {
      _canGoNext = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ඇලපිල්ල (ා) ඉගෙන ගමු', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  _canGoNext = index < 2;
                });
              },
              children: [
                _buildTitlePage(),
                _buildIntroPage(),
                InteractiveTracingPage(
                  key: const ValueKey('trace1'),
                  onComplete: _onInteractionComplete,
                ),
                InteractiveTracingPage(
                  key: const ValueKey('trace2'),
                  onComplete: _onInteractionComplete,
                ),
                InteractiveTracingPage(
                  key: const ValueKey('trace3'),
                  onComplete: _onInteractionComplete,
                ),
                InteractiveMergePage(
                  key: const ValueKey('merge1'),
                  letter: 'ක',
                  result: 'කා',
                  onComplete: _onInteractionComplete,
                ),
                InteractiveMergePage(
                  key: const ValueKey('merge2'),
                  letter: 'ම',
                  result: 'මා',
                  onComplete: _onInteractionComplete,
                ),
                InteractiveMergePage(
                  key: const ValueKey('merge3'),
                  letter: 'ග',
                  result: 'ගා',
                  onComplete: _onInteractionComplete,
                ),
              ],
            ),
            
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  8,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: _currentPage >= index ? 30 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _currentPage >= index ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            
            if (_canGoNext && _currentPage <= 7)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, val, child) => Transform.scale(
                      scale: val,
                      child: child,
                    ),
                    child: InkWell(
                      onTap: _nextPage,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        width: 280,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                        ),
                        child: const Center(
                          child: Icon(Icons.arrow_forward_rounded, size: 50, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitlePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: -200, end: 0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, val, child) => Transform.translate(
              offset: Offset(0, val),
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueAccent, width: 4),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: const Text(
                'අපි ඉගෙන ගමු:\nඇලපිල්ල (ා)',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 50),
          const BouncingOrangeMonster(),
        ],
      ),
    );
  }

  Widget _buildIntroPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, val, child) => Transform.scale(scale: val, child: child),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                'අද අපි ඉගෙන ගන්නේ අකුරු වලට ඇලපිල්ල (ා) එකතු කළාම ශබ්දය වෙනස් වෙන හැටි.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blueAccent, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InteractiveTracingPage extends StatefulWidget {
  final VoidCallback onComplete;
  const InteractiveTracingPage({super.key, required this.onComplete});
  @override
  State<InteractiveTracingPage> createState() => _InteractiveTracingPageState();
}

class _InteractiveTracingPageState extends State<InteractiveTracingPage> {
  List<Offset?> _points = [];
  bool _isCompleted = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Path _getAlapillaPath(Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    double w = 120;
    double h = 260;
    double left = centerX - w / 2;
    double right = centerX + w / 2;
    double top = centerY - h / 2;
    double bottom = centerY + h / 2;

    Path path = Path();
    path.moveTo(left, top + h * 0.15);
    path.quadraticBezierTo(centerX, top - h * 0.05, right, top + h * 0.15);
    path.lineTo(right, bottom - h * 0.15);
    path.quadraticBezierTo(centerX, bottom + h * 0.05, left, bottom - h * 0.15);
    return path;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isCompleted) return;
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    setState(() {
      _points.add(renderBox.globalToLocal(details.globalPosition));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isCompleted) return;
    _points.add(null);
    
    List<Offset> drawnPoints = _points.whereType<Offset>().toList();
    if (drawnPoints.length < 10) {
      setState(() { _points.clear(); });
      return;
    }

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Path guidePath = _getAlapillaPath(renderBox.size);

    List<Offset> pathPoints = [];
    for (PathMetric measurePath in guidePath.computeMetrics()) {
      double distance = 0;
      while (distance < measurePath.length) {
        Tangent? tangent = measurePath.getTangentForOffset(distance);
        if (tangent != null) {
          pathPoints.add(tangent.position);
        }
        distance += 10;
      }
    }

    if (pathPoints.isEmpty) {
      setState(() { _points.clear(); });
      return;
    }

    Offset guideStart = pathPoints.first;
    Offset guideEnd = pathPoints.last;

    Offset drawnStart = drawnPoints.first;
    Offset drawnEnd = drawnPoints.last;

    double tolerance = 65.0; // Margin of error for kids
    if ((drawnStart - guideStart).distance > tolerance || 
        (drawnEnd - guideEnd).distance > tolerance) {
      setState(() { _points.clear(); });
      return;
    }

    bool isValid = true;
    for (Offset p in drawnPoints) {
      double minD = double.infinity;
      for (Offset gp in pathPoints) {
        double d = (p - gp).distanceSquared;
        if (d < minD) minD = d;
      }
      if (minD > (tolerance * tolerance)) {
        isValid = false;
        break;
      }
    }

    setState(() {
      if (isValid) {
        _isCompleted = true;
        _audioPlayer.play(AssetSource('correct.mp3'));
        widget.onComplete();
      } else {
        _points.clear(); 
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, 
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                _isCompleted ? 'නියමයි!' : 'ඇලපිල්ල (ා) අඳිමු!',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                painter: _TracingPainter(
                  points: _points, 
                  showGuide: !_isCompleted,
                  pathBuilder: _getAlapillaPath,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TracingPainter extends CustomPainter {
  final List<Offset?> points;
  final bool showGuide;
  final Path Function(Size) pathBuilder;

  _TracingPainter({required this.points, required this.showGuide, required this.pathBuilder});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    if (showGuide) {
      Path guidePath = pathBuilder(size);
      
      Paint dotPaint = Paint()
        ..color = Colors.grey.withOpacity(0.6)
        ..style = PaintingStyle.fill;
        
      for (PathMetric measurePath in guidePath.computeMetrics()) {
        double distance = 0;
        while (distance < measurePath.length) {
          Tangent? tangent = measurePath.getTangentForOffset(distance);
          if (tangent != null) {
            canvas.drawCircle(tangent.position, 8, dotPaint);
          }
          distance += 35; // Spacing between dots
        }
      }
      
      // Start dot
      Paint startDotPaint = Paint()..color = Colors.redAccent;
      canvas.drawCircle(Offset(centerX - 60, centerY - 130 * 0.7), 18, startDotPaint);
    }

    final Paint paint = Paint()
      ..color = Colors.blueAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 24.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) => true;
}

class AlapillaPainter extends CustomPainter {
  final Color color;
  AlapillaPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width;
    double h = size.height;
    double left = 0;
    double right = w;
    double top = 0;
    double bottom = h;

    Path path = Path();
    path.moveTo(left, top + h * 0.15);
    path.quadraticBezierTo(w * 0.5, top - h * 0.05, right, top + h * 0.15);
    path.lineTo(right, bottom - h * 0.15);
    path.quadraticBezierTo(w * 0.5, bottom + h * 0.05, left, bottom - h * 0.15);

    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AlapillaPainter oldDelegate) => oldDelegate.color != color;
}

class InteractiveMergePage extends StatefulWidget {
  final String letter;
  final String result;
  final VoidCallback onComplete;

  const InteractiveMergePage({
    super.key,
    required this.letter,
    required this.result,
    required this.onComplete,
  });

  @override
  State<InteractiveMergePage> createState() => _InteractiveMergePageState();
}

class _InteractiveMergePageState extends State<InteractiveMergePage> {
  int step = 0;

  void _tapLetter() {
    if (step == 0) {
      setState(() { step = 1; });
    }
  }

  void _tapPillama() {
    if (step == 1) {
      setState(() { step = 2; });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() { step = 3; });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() { step = 4; });
            widget.onComplete();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                step == 0 ? 'අකුර ඔබන්න!' : (step == 1 ? 'ඇලපිල්ල ඔබන්න!' : 'නියමයි!'),
                key: ValueKey(step),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
          ),
        ),

        if (step >= 3)
          Align(
            alignment: Alignment.center,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, val, child) => Transform.scale(scale: val, child: child),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.result, style: const TextStyle(fontSize: 160, fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
            ),
          ),

        if (step < 3)
          AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInBack,
            alignment: step == 2 ? Alignment.center : const Alignment(-0.5, 0),
            child: GestureDetector(
              onTap: _tapLetter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    if (step == 0) const BoxShadow(color: Colors.greenAccent, blurRadius: 30, spreadRadius: 10)
                  ],
                ),
                child: Text(widget.letter, style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            ),
          ),

        if (step == 1)
          const Align(
            alignment: Alignment.center,
            child: Text('+', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

        if (step >= 1 && step < 3)
          TweenAnimationBuilder<double>(
            tween: step == 1 ? Tween(begin: 1.5, end: 0.5) : Tween(begin: 0.5, end: 0.5), 
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, val, child) {
              final alignX = step == 2 ? 0.0 : val;
              return AnimatedAlign(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInBack,
                alignment: Alignment(alignX, 0),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _tapPillama,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    if (step == 1) const BoxShadow(color: Colors.redAccent, blurRadius: 30, spreadRadius: 10)
                  ],
                ),
                child: SizedBox(
                  width: 60,
                  height: 130,
                  child: CustomPaint(
                    painter: AlapillaPainter(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BouncingOrangeMonster extends StatefulWidget {
  const BouncingOrangeMonster({super.key});

  @override
  State<BouncingOrangeMonster> createState() => _BouncingOrangeMonsterState();
}

class _BouncingOrangeMonsterState extends State<BouncingOrangeMonster> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -15 * _controller.value),
          child: SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _OrangeMonsterPainter(
                breathing: _controller.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrangeMonsterPainter extends CustomPainter {
  final double breathing;

  _OrangeMonsterPainter({required this.breathing});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double scale = 1.0 + (breathing * 0.05);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black87
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(w * 0.5, h * 0.55);
    canvas.scale(scale);

    final Alignment lightSource = const Alignment(-0.3, -0.4);

    fillPaint.color = const Color(0xFF6D3010);
    _drawFoot(canvas, const Offset(-25, 65), fillPaint);
    _drawFoot(canvas, const Offset(25, 65), fillPaint);

    _drawAntenna(canvas, const Offset(-15, -50), const Offset(-40, -80), fillPaint, strokePaint);
    _drawAntenna(canvas, const Offset(15, -50), const Offset(40, -80), fillPaint, strokePaint);

    final Path bodyPath = Path();
    bodyPath.moveTo(0, -55); 
    bodyPath.quadraticBezierTo(45, -55, 55, -25);
    bodyPath.lineTo(75, -40);
    bodyPath.lineTo(65, -10);
    bodyPath.quadraticBezierTo(75, 35, 60, 55);
    bodyPath.quadraticBezierTo(30, 65, 0, 65); 
    bodyPath.quadraticBezierTo(-30, 65, -60, 55);
    bodyPath.quadraticBezierTo(-75, 35, -65, -10);
    bodyPath.lineTo(-75, -40);
    bodyPath.lineTo(-55, -25);
    bodyPath.quadraticBezierTo(-45, -55, 0, -55);

    fillPaint.shader = RadialGradient(
      colors: const [Color(0xFFFFB74D), Color(0xFFFF8F00), Color(0xFFE65100), Color(0xFFBF360C)],
      stops: const [0.0, 0.4, 0.8, 1.0],
      center: lightSource,
      radius: 1.2,
    ).createShader(bodyPath.getBounds());

    canvas.drawShadow(bodyPath, Colors.black45, 8.0, true);
    canvas.drawPath(bodyPath, fillPaint);
    fillPaint.shader = null; 

    fillPaint.color = Colors.black.withOpacity(0.15);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -5), width: 74, height: 80), fillPaint);
    fillPaint.color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -7), width: 70, height: 76), fillPaint);
    fillPaint.color = const Color(0xFF1A1A1A);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -7), width: 35, height: 45), fillPaint);
    fillPaint.color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: const Offset(5, -15), width: 12, height: 18), fillPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-7, -1), width: 5, height: 7), fillPaint);

    final Path mouth = Path();
    strokePaint.strokeWidth = 2.5;
    strokePaint.color = const Color(0xFF4E1600);
    mouth.moveTo(-20, 35);
    mouth.quadraticBezierTo(0, 50, 20, 35);
    mouth.close();
    fillPaint.color = const Color(0xFF4E1600);
    canvas.drawPath(mouth, fillPaint);
    canvas.drawPath(mouth, strokePaint);

    _drawHand(canvas, const Offset(-45, 25), fillPaint, lightSource);
    _drawHand(canvas, const Offset(45, 25), fillPaint, lightSource);

    canvas.restore();
  }

  void _drawFoot(Canvas canvas, Offset center, Paint paint) {
    final Path foot = Path();
    foot.moveTo(center.dx - 14, center.dy - 8);
    foot.lineTo(center.dx + 14, center.dy - 8);
    foot.lineTo(center.dx + 16, center.dy + 8);
    foot.quadraticBezierTo(center.dx + 10, center.dy + 12, center.dx + 5, center.dy + 8);
    foot.quadraticBezierTo(center.dx + 0, center.dy + 12, center.dx - 5, center.dy + 8);
    foot.quadraticBezierTo(center.dx - 10, center.dy + 12, center.dx - 16, center.dy + 8);
    foot.close();
    canvas.drawPath(foot, paint);
  }

  void _drawAntenna(Canvas canvas, Offset base, Offset tip, Paint fillPaint, Paint strokePaint) {
    final Path stem = Path();
    stem.moveTo(base.dx, base.dy);
    stem.quadraticBezierTo(base.dx, tip.dy + 15, tip.dx, tip.dy);
    strokePaint.color = Colors.black87;
    strokePaint.strokeWidth = 3.0;
    canvas.drawPath(stem, strokePaint);
    fillPaint.shader = RadialGradient(
      colors: const [Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFFF57F17)],
      stops: const [0.0, 0.5, 1.0],
      center: const Alignment(-0.3, -0.3),
      radius: 0.8,
    ).createShader(Rect.fromCenter(center: tip, width: 20, height: 20));
    canvas.drawCircle(tip, 10, fillPaint);
    fillPaint.shader = null;
  }

  void _drawHand(Canvas canvas, Offset pos, Paint fillPaint, Alignment lightSource) {
    fillPaint.shader = RadialGradient(
      colors: const [Color(0xFFFFB74D), Color(0xFFFF8F00), Color(0xFFE65100)],
      center: lightSource,
      radius: 0.8,
    ).createShader(Rect.fromCenter(center: pos, width: 25, height: 25));
    final Path hand = Path();
    hand.moveTo(pos.dx - 8, pos.dy - 4);
    hand.quadraticBezierTo(pos.dx, pos.dy - 12, pos.dx + 8, pos.dy - 4);
    hand.quadraticBezierTo(pos.dx + 12, pos.dy + 4, pos.dx + 4, pos.dy + 10);
    hand.quadraticBezierTo(pos.dx, pos.dy + 12, pos.dx - 4, pos.dy + 10);
    hand.quadraticBezierTo(pos.dx - 12, pos.dy + 4, pos.dx - 8, pos.dy - 4);
    canvas.drawPath(hand, fillPaint);
    fillPaint.shader = null;
  }

  @override
  bool shouldRepaint(covariant _OrangeMonsterPainter oldDelegate) => oldDelegate.breathing != breathing;
}
