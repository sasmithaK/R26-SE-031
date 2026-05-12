import 'dart:math';

import 'package:flutter/material.dart';
import 'package:dyslexia_app/widgets/skip_button.dart';
import 'package:dyslexia_app/services/difficulty_profile_service.dart';

class FireflyTrackingGame extends StatefulWidget {
  const FireflyTrackingGame({super.key});

  @override
  State<FireflyTrackingGame> createState() => _FireflyTrackingGameState();
}

class _FireflyTrackingGameState extends State<FireflyTrackingGame>
    with TickerProviderStateMixin {
  late final AnimationController _skyController;
  late final AnimationController _glowController;
  late final AnimationController _celebrationController;

  final Random _random = Random();
  final List<_FireflyItem> _fireflies = [];
  late List<String> _sequenceLetters;

  int _nextExpectedIndex = 0;
  int _correctTaps = 0;
  int _wrongTaps = 0;
  bool _isComplete = false;
  bool _showHintPulse = true;

  @override
  void initState() {
    super.initState();
    _sequenceLetters = const ['අ', 'ක', 'ග', 'ත', 'ප']
        .take(
          DifficultyProfileService.countForLevel(
            DifficultyProfileService.cachedStartingGameLevel,
            3,
            5,
          ),
        )
        .toList();

    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _buildFireflies();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showHintPulse = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _skyController.dispose();
    _glowController.dispose();
    _celebrationController.dispose();
    for (final firefly in _fireflies) {
      firefly.controller.dispose();
    }
    super.dispose();
  }

  void _buildFireflies() {
    for (final firefly in _fireflies) {
      firefly.controller.dispose();
    }
    _fireflies.clear();

    final yPositions = <double>[120, 210, 155, 280, 95];
    final durations = <int>[11, 12, 10, 13, 11];

    for (var i = 0; i < _sequenceLetters.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: durations[i]),
      )..repeat();

      _fireflies.add(
        _FireflyItem(
          index: i,
          y: yPositions[i],
          controller: controller,
          startDelay: i * 250,
          wiggleSeed: _random.nextDouble() * pi,
        ),
      );
    }
  }

  void _resetGame() {
    setState(() {
      _nextExpectedIndex = 0;
      _correctTaps = 0;
      _wrongTaps = 0;
      _isComplete = false;
      _showHintPulse = true;
    });
    _buildFireflies();
    _glowController.reset();
    _glowController.repeat(reverse: true);
    _celebrationController.reset();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showHintPulse = false;
        });
      }
    });
  }

  void _handleTap(int index) {
    if (_isComplete) return;

    if (index == _nextExpectedIndex) {
      setState(() {
        _correctTaps++;
        _nextExpectedIndex++;
        if (_nextExpectedIndex >= _fireflies.length) {
          _isComplete = true;
          _celebrationController.forward(from: 0);
        }
      });

      if (_isComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('සුපිරි! ඔබ ගිගුරුම් පිළිවෙලට තට්ටු කළා.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _wrongTaps++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('මුලින්ම "${_sequenceLetters[0]}" තෝරන්න. පසුව ${_sequenceLetters[1]}, ${_sequenceLetters[2]}, ${_sequenceLetters[3]}, ${_sequenceLetters[4]}.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _skipCurrentStep() {
    if (_isComplete) return;
    _handleTap(_nextExpectedIndex);
  }

  double _fireflyX(double progress, double screenWidth, int index) {
    final delay = index * 0.1;
    final eased = ((progress + delay) % 1.0);
    return -70 + (screenWidth + 140) * eased;
  }

  double _fireflyWiggle(double progress, double seed) {
    return sin((progress * 2 * pi * 1.4) + seed) * 9;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1D2147),
      floatingActionButton: SkipButton(taskName: 'firefly_tracking', onSkipped: _skipCurrentStep),
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _skyController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _FireflySkyPainter(_skyController.value),
                );
              },
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firefly Tracking Game',
                              style: TextStyle(
                                color: Colors.amber.shade100,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'ළමා හිතකාමී, පැහැදිලි, වම් සිට දකුණට බලන්න',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'අකුරු පිළිවෙළට ගිගුරුම් අල්ලන්න',
                          style: TextStyle(
                            color: Colors.amber.shade100,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _sequenceLetters.join(' → '),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildStatChip('හරි', _correctTaps.toString(), Colors.lightGreenAccent),
                            const SizedBox(width: 10),
                            _buildStatChip('වැරදි', _wrongTaps.toString(), Colors.orangeAccent),
                            const SizedBox(width: 10),
                            _buildStatChip('ඊළඟ', _sequenceLetters[_nextExpectedIndex.clamp(0, 4)], Colors.cyanAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2A2F5D).withValues(alpha: 0.95),
                                    const Color(0xFF1B1F42).withValues(alpha: 0.98),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.amber.shade100.withValues(alpha: 0.5), width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        height: 140,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF3F7D3B).withValues(alpha: 0.95),
                                              const Color(0xFF245F2C).withValues(alpha: 0.98),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 102,
                                      child: Text(
                                        'අලෝකය අනුගමනය කරමින් හරි පිළිවෙළ තෝරන්න',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.amber.shade100,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          shadows: const [
                                            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    ...List.generate(_fireflies.length, (index) {
                                      final firefly = _fireflies[index];
                                      return AnimatedBuilder(
                                        animation: Listenable.merge([firefly.controller, _glowController]),
                                        builder: (context, child) {
                                          final progress = ((firefly.controller.value * 1000) + firefly.startDelay) % 1000 / 1000.0;
                                          final x = _fireflyX(progress, constraints.maxWidth, index);
                                          final wiggle = _fireflyWiggle(progress, firefly.wiggleSeed);
                                          final isExpected = index == _nextExpectedIndex && !_isComplete;
                                          final isTapped = index < _nextExpectedIndex;
                                          final pulse = _showHintPulse && isExpected ? 1 + (_glowController.value * 0.08) : 1.0;

                                          return Positioned(
                                            left: x,
                                            top: firefly.y + wiggle,
                                            child: GestureDetector(
                                              onTap: () => _handleTap(index),
                                              child: Transform.scale(
                                                scale: pulse,
                                                child: SizedBox(
                                                  width: 96,
                                                  height: 110,
                                                  child: GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTapDown: (_) => _handleTap(index),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Container(
                                                          width: 66,
                                                          height: 66,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: isTapped ? const Color(0xFF8BC34A).withValues(alpha: 0.55) : const Color(0xFFFFE082).withValues(alpha: 0.35),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: isExpected
                                                                    ? const Color(0xFFFFF176).withValues(alpha: 0.95)
                                                                    : Colors.amber.withValues(alpha: 0.45),
                                                                blurRadius: isExpected ? 22 : 14,
                                                                spreadRadius: isExpected ? 4 : 1,
                                                              ),
                                                            ],
                                                            border: Border.all(
                                                              color: isExpected ? Colors.white : Colors.amber.shade100,
                                                              width: 2,
                                                            ),
                                                          ),
                                                          child: Stack(
                                                            alignment: Alignment.center,
                                                            children: [
                                                              Container(
                                                                width: 40,
                                                                height: 24,
                                                                decoration: BoxDecoration(
                                                                  color: isTapped ? Colors.lightGreenAccent.shade100 : Colors.amber.shade200,
                                                                  borderRadius: BorderRadius.circular(20),
                                                                ),
                                                              ),
                                                              Positioned(
                                                                left: 13,
                                                                top: 11,
                                                                child: Container(
                                                                  width: 12,
                                                                  height: 12,
                                                                  decoration: const BoxDecoration(
                                                                    color: Colors.white,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                ),
                                                              ),
                                                              Positioned(
                                                                right: 13,
                                                                top: 11,
                                                                child: Container(
                                                                  width: 12,
                                                                  height: 12,
                                                                  decoration: const BoxDecoration(
                                                                    color: Colors.white,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                ),
                                                              ),
                                                              Positioned(
                                                                top: 9,
                                                                child: Container(
                                                                  width: 9,
                                                                  height: 34,
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.green.shade900.withValues(alpha: 0.9),
                                                                    borderRadius: BorderRadius.circular(99),
                                                                  ),
                                                                ),
                                                              ),
                                                              Positioned(
                                                                left: 4,
                                                                right: 4,
                                                                bottom: 5,
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    _tinyWing(rotate: -0.35),
                                                                    const SizedBox(width: 3),
                                                                    _tinyWing(rotate: 0.35),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        AnimatedContainer(
                                                          duration: const Duration(milliseconds: 250),
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: isTapped
                                                                ? Colors.white.withValues(alpha: 0.2)
                                                                : isExpected
                                                                    ? Colors.deepOrangeAccent.withValues(alpha: 0.9)
                                                                    : Colors.indigoAccent.withValues(alpha: 0.75),
                                                            borderRadius: BorderRadius.circular(999),
                                                            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                                                          ),
                                                          child: Text(
                                                            _sequenceLetters[index],
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.w900,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }),
                                    Positioned(
                                      left: 18,
                                      right: 18,
                                      top: 14,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildCloud(offset: 0.0, scale: 1.0),
                                          _buildCloud(offset: 0.35, scale: 0.8),
                                        ],
                                      ),
                                    ),
                                    if (_showHintPulse)
                                      Positioned(
                                        left: 16,
                                        right: 16,
                                        bottom: 165,
                                        child: Center(
                                          child: AnimatedBuilder(
                                            animation: _glowController,
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale: 1 + (_glowController.value * 0.05),
                                                child: child,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade200.withValues(alpha: 0.95),
                                                borderRadius: BorderRadius.circular(999),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.amber.shade100.withValues(alpha: 0.55),
                                                    blurRadius: 16,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '${_sequenceLetters[0]} කියලා තට්ටු කරන්න',
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_isComplete)
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.black.withValues(alpha: 0.45),
                                          child: Center(
                                            child: ScaleTransition(
                                              scale: CurvedAnimation(
                                                parent: _celebrationController,
                                                curve: Curves.elasticOut,
                                              ),
                                              child: Container(
                                                margin: const EdgeInsets.all(24),
                                                padding: const EdgeInsets.all(22),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF8E1),
                                                  borderRadius: BorderRadius.circular(28),
                                                  border: Border.all(color: Colors.amber.shade300, width: 4),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.amber.shade200.withValues(alpha: 0.55),
                                                      blurRadius: 20,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.celebration_rounded, size: 64, color: Colors.orange.shade600),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'සුපිරි!',
                                                      style: TextStyle(
                                                        fontSize: 32,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.green.shade700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                      'ඔබ ගිගුරුම් නිවැරදි පිළිවෙළට තෝරා ගත්තා.',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        _buildResultBadge('හරි', _correctTaps.toString(), Colors.green),
                                                        const SizedBox(width: 10),
                                                        _buildResultBadge('වැරදි', _wrongTaps.toString(), Colors.red),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 18),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.orange.shade400,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                      ),
                                                      onPressed: _resetGame,
                                                      child: const Text(
                                                        'නැවත ක්‍රීඩා කරන්න',
                                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloud({required double offset, required double scale}) {
    return Opacity(
      opacity: 0.9,
      child: Transform.translate(
        offset: Offset(sin((_skyController.value * 2 * pi) + offset) * 14, 0),
        child: Transform.scale(
          scale: scale,
          child: Icon(Icons.cloud, color: Colors.white.withValues(alpha: 0.7), size: 44),
        ),
      ),
    );
  }

  Widget _tinyWing({required double rotate}) {
    return Transform.rotate(
      angle: rotate,
      child: Container(
        width: 8,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _FireflyItem {
  final int index;
  final double y;
  final AnimationController controller;
  final int startDelay;
  final double wiggleSeed;

  _FireflyItem({
    required this.index,
    required this.y,
    required this.controller,
    required this.startDelay,
    required this.wiggleSeed,
  });
}

class _FireflySkyPainter extends CustomPainter {
  final double progress;

  _FireflySkyPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final skyPaint = Paint()..color = const Color(0xFF1D2147);
    canvas.drawRect(Offset.zero & size, skyPaint);

    final moonPaint = Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: 0.65);
    canvas.drawCircle(Offset(size.width * 0.82, 84), 28, moonPaint);

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final glowPaint = Paint()..color = Colors.amber.shade100.withValues(alpha: 0.25);

    for (var i = 0; i < 36; i++) {
      final x = (size.width * ((i * 0.173) % 1.0) + (progress * 40 * (i.isEven ? 1 : -1))) % size.width;
      final y = 34 + ((i * 41) % (size.height * 0.55));
      final radius = 1.3 + (i % 3) * 0.4;
      canvas.drawCircle(Offset(x, y), radius + 1.5, glowPaint);
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }

    final hillPaint = Paint()..color = const Color(0xFF294A38).withValues(alpha: 0.45);
    final hillPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.64, size.width * 0.4, size.height * 0.74)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.86, size.width * 0.84, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.95, size.height * 0.67, size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);
  }

  @override
  bool shouldRepaint(covariant _FireflySkyPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
