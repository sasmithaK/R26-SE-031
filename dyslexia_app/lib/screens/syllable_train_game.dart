import 'dart:math';

import 'package:flutter/material.dart';

class SyllableTrainGame extends StatefulWidget {
  const SyllableTrainGame({super.key});

  @override
  State<SyllableTrainGame> createState() => _SyllableTrainGameState();
}

class _SyllableTrainGameState extends State<SyllableTrainGame>
    with TickerProviderStateMixin {
  late final AnimationController _trainBobController;
  late final AnimationController _cloudController;
  late final Animation<double> _trainBobAnimation;

  final Random _random = Random();
  final GlobalKey _trainKey = GlobalKey();

  final List<_TrainRound> _rounds = const [
    _TrainRound(
      word: 'මල',
      carriages: ['ම', 'ල'],
      trainColors: [Color(0xFFFF8A80), Color(0xFF80D8FF)],
    ),
    _TrainRound(
      word: 'ගස',
      carriages: ['ග', 'ස'],
      trainColors: [Color(0xFFA5D6A7), Color(0xFFFFCC80)],
    ),
    _TrainRound(
      word: 'ගෙය',
      carriages: ['ගෙ', 'ය'],
      trainColors: [Color(0xFFB39DDB), Color(0xFF81D4FA)],
    ),
    _TrainRound(
      word: 'අම්මා',
      carriages: ['අ', 'ම්', 'මා'],
      trainColors: [Color(0xFFFFAB91), Color(0xFFCE93D8), Color(0xFFFFAB91)],
    ),
    _TrainRound(
      word: 'පාසල',
      carriages: ['පා', 'ස', 'ල'],
      trainColors: [Color(0xFF80CBC4), Color(0xFFFFF59D), Color(0xFFFFAB91)],
    ),
  ];

  final List<String> _currentOrder = [];
  int _currentRoundIndex = 0;
  bool _isCelebrating = false;

  @override
  void initState() {
    super.initState();
    _trainBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _trainBobAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _trainBobController, curve: Curves.easeInOut),
    );

    _prepareRound();
  }

  @override
  void dispose() {
    _trainBobController.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  void _prepareRound() {
    final round = _rounds[_currentRoundIndex];
    final shuffled = List<String>.from(round.carriages)..shuffle(_random);
    _currentOrder
      ..clear()
      ..addAll(shuffled);
    _isCelebrating = false;
    setState(() {});
  }

  bool get _isCorrect {
    final round = _rounds[_currentRoundIndex];
    if (_currentOrder.length != round.carriages.length) return false;
    for (var i = 0; i < round.carriages.length; i++) {
      if (_currentOrder[i] != round.carriages[i]) return false;
    }
    return true;
  }

  void _swapCarriages(int fromIndex, int toIndex) {
    if (_isCelebrating || fromIndex == toIndex) return;

    setState(() {
      final item = _currentOrder.removeAt(fromIndex);
      _currentOrder.insert(toIndex, item);
    });

    if (_isCorrect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isCelebrating) {
          _showFireworkSuccess();
        }
      });
    }
  }

  void _checkWord() {
    if (_isCelebrating) return;

    if (_isCorrect) {
      _showFireworkSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('නැවත උත්සාහ කරන්න'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showFireworkSuccess() async {
    setState(() {
      _isCelebrating = true;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: _FireworksPopup(word: _rounds[_currentRoundIndex].word),
        );
      },
    );

    if (!mounted) return;

    if (_currentRoundIndex < _rounds.length - 1) {
      setState(() {
        _currentRoundIndex++;
      });
      _prepareRound();
    } else {
      _showFinishDialog();
    }
  }

  void _showFinishDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ගොඩක් හොඳයි!'),
        content: const Text('ඔබ සියලු වචන නිවැරදිව තැනුවා.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final round = _rounds[_currentRoundIndex];
    final progress = (_currentRoundIndex + 1) / _rounds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllable Train Game'),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlue.shade50, Colors.orange.shade50, Colors.green.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _trainBobAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _trainBobAnimation.value),
                              child: child,
                            );
                          },
                          child: const Icon(Icons.train_rounded, size: 56, color: Colors.red),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'කෝච්චිය එක අල්ලා වමට හෝ දකුණට අදින්න. වචනය හරිද බලන්න.',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'වටය ${_currentRoundIndex + 1} / ${_rounds.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.campaign_rounded, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            'හඬ අණ',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const Spacer(),
                          Text(
                            'Build: ${round.word}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green.shade800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'වචනය හදන්න: ${round.word}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 14),
                      _TrainTrack(
                        trainKey: _trainKey,
                        carriages: _currentOrder,
                        colors: round.trainColors,
                        onSwap: _swapCarriages,
                        isLocked: _isCelebrating,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.train_rounded, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              'කෝච්චිය එක දිගට ඇදලා හරි පිළිවෙලට තබන්න',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'නිවැරදි පිළිවෙලට තැනූ පසු Check Word ඔබන්න. හරි නම් fireworks පෙනේවි.',
                          style: TextStyle(fontSize: 15, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isCelebrating ? null : _checkWord,
                            icon: const Icon(Icons.verified_rounded),
                            label: const Text(
                              'Check Word',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainTrack extends StatelessWidget {
  const _TrainTrack({
    required this.trainKey,
    required this.carriages,
    required this.colors,
    required this.onSwap,
    required this.isLocked,
  });

  final GlobalKey trainKey;
  final List<String> carriages;
  final List<Color> colors;
  final void Function(int fromIndex, int toIndex) onSwap;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Stack(
        key: trainKey,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 92,
            child: CustomPaint(
              painter: _TrackPainter(),
            ),
          ),
          Positioned(
            left: 0,
            top: 28,
            child: _Locomotive(sway: isLocked ? 0 : 1),
          ),
          Positioned(
            left: 118,
            right: 0,
            top: 22,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(carriages.length, (index) {
                  final syllable = carriages[index];
                  final color = colors[index % colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _DraggableCarriage(
                      index: index,
                      syllable: syllable,
                      color: color,
                      isLocked: isLocked,
                      onSwap: onSwap,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableCarriage extends StatelessWidget {
  const _DraggableCarriage({
    required this.index,
    required this.syllable,
    required this.color,
    required this.isLocked,
    required this.onSwap,
  });

  final int index;
  final String syllable;
  final Color color;
  final bool isLocked;
  final void Function(int fromIndex, int toIndex) onSwap;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAccept: (fromIndex) => !isLocked && fromIndex != null && fromIndex != index,
      onAccept: (fromIndex) => onSwap(fromIndex, index),
      builder: (context, candidateData, rejectedData) {
        final hovered = candidateData.isNotEmpty;
        return Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.05,
              child: _CarriageBody(
                syllable: syllable,
                color: color,
                isHovered: true,
                isDragging: true,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: _CarriageBody(
              syllable: syllable,
              color: color,
              isHovered: hovered,
            ),
          ),
          onDragCompleted: () {},
          onDraggableCanceled: (_, __) {},
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: hovered ? 1.04 : 1.0,
            child: _CarriageBody(
              syllable: syllable,
              color: color,
              isHovered: hovered,
            ),
          ),
        );
      },
    );
  }
}

class _CarriageBody extends StatelessWidget {
  const _CarriageBody({
    required this.syllable,
    required this.color,
    this.isHovered = false,
    this.isDragging = false,
  });

  final String syllable;
  final Color color;
  final bool isHovered;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 108,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHovered ? Colors.black : Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDragging ? 0.2 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -6,
            left: 36,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            left: 16,
            child: _Wheel(color: Colors.brown.shade700),
          ),
          Positioned(
            bottom: -10,
            right: 16,
            child: _Wheel(color: Colors.brown.shade700),
          ),
          Center(
            child: Text(
              syllable,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          if (!isDragging)
            Positioned(
              top: 6,
              right: 8,
              child: Icon(Icons.open_with_rounded, size: 18, color: Colors.white.withOpacity(0.85)),
            ),
        ],
      ),
    );
  }
}

class _Locomotive extends StatelessWidget {
  const _Locomotive({required this.sway});

  final double sway;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      transform: Matrix4.translationValues(0, sway, 0),
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [Colors.red.shade500, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded, size: 16, color: Colors.red),
            ),
          ),
          Positioned(
            top: -18,
            left: 18,
            child: Row(
              children: const [
                _SmokePuff(size: 18, delay: 0),
                SizedBox(width: 8),
                _SmokePuff(size: 12, delay: 1),
                SizedBox(width: 8),
                _SmokePuff(size: 8, delay: 2),
              ],
            ),
          ),
          Positioned(
            top: 18,
            right: 12,
            child: Icon(Icons.train_rounded, size: 54, color: Colors.white.withOpacity(0.95)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Center(
              child: Container(
                width: 58,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'GO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _SmokePuff extends StatefulWidget {
  const _SmokePuff({required this.size, required this.delay});

  final double size;
  final int delay;

  @override
  State<_SmokePuff> createState() => _SmokePuffState();
}

class _SmokePuffState extends State<_SmokePuff> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900 + widget.delay * 150),
    )..repeat();
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
        final t = _controller.value;
        return Opacity(
          opacity: 1.0 - t,
          child: Transform.translate(
            offset: Offset(0, -14 * t),
            child: Transform.scale(
              scale: 0.8 + t,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final railPaint = Paint()
      ..color = Colors.brown.shade600
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final sleeperPaint = Paint()
      ..color = Colors.brown.shade300
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final y = size.height * 0.55;
    canvas.drawLine(Offset(95, y), Offset(size.width - 10, y), railPaint);
    canvas.drawLine(Offset(95, y + 20), Offset(size.width - 10, y + 20), railPaint);

    for (double x = 110; x < size.width - 10; x += 28) {
      canvas.drawLine(Offset(x, y - 8), Offset(x + 8, y + 28), sleeperPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FireworksPopup extends StatefulWidget {
  const _FireworksPopup({required this.word});

  final String word;

  @override
  State<_FireworksPopup> createState() => _FireworksPopupState();
}

class _FireworksPopupState extends State<_FireworksPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  final List<Color> _burstColors = const [
    Color(0xFFFF5252),
    Color(0xFFFFC107),
    Color(0xFF40C4FF),
    Color(0xFF69F0AE),
    Color(0xFFE040FB),
    Color(0xFFFFAB40),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(8, (index) {
                final angle = (pi / 4) * index;
                final distance = 60 + progress * 90;
                final dx = cos(angle) * distance;
                final dy = sin(angle) * distance;
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Opacity(
                    opacity: (1.0 - progress).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.star_rounded,
                      color: _burstColors[index % _burstColors.length],
                      size: 24 + (1 - progress) * 18,
                    ),
                  ),
                );
              }),
              Transform.scale(
                scale: 0.92 + progress * 0.08,
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.amber.shade300, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.celebration_rounded, size: 72, color: Colors.amber),
                      const SizedBox(height: 8),
                      const Text(
                        'ඔයාට පුළුවන්!',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.red),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.word} හරි!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrainRound {
  const _TrainRound({
    required this.word,
    required this.carriages,
    required this.trainColors,
  });

  final String word;
  final List<String> carriages;
  final List<Color> trainColors;
}
