import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dyslexia_app/widgets/skip_button.dart';
import 'package:dyslexia_app/utils/visual_training_loop.dart';
import 'package:dyslexia_app/services/visual_service.dart';
import 'package:dyslexia_app/models/visual_config.dart';

class DrawingInterpretationGame extends StatefulWidget {
  const DrawingInterpretationGame({super.key});

  @override
  State<DrawingInterpretationGame> createState() =>
      _DrawingInterpretationGameState();
}

class _DrawingInterpretationGameState extends State<DrawingInterpretationGame>
    with TickerProviderStateMixin {
  late AnimationController _owlAnimationController;
  late AnimationController _celebrationController;
  late Animation<double> _owlAnimation;

  final List<Map<String, String>> _sentences = [
    {'sinhala': 'මල් පිපීලා තියෙනවා.'},
    {'sinhala': 'ඉර එළිය තියෙනවා'},
    {'sinhala': 'කුරුල්ලෝ පියාඹනවා.'},
    {'sinhala': 'අම්මා බත් උයනවා.'},
    {'sinhala': 'තාත්තා වැඩට යනවා'},
  ];

  int _currentSentenceIndex = 0;
  final List<DrawingPoint> _drawingPoints = [];
  final GlobalKey _canvasKey = GlobalKey();
  Color _selectedColor = Colors.black;
  double _strokeWidth = 4;
  bool _isEraser = false;

  final VisualTrainingLoop _trainingLoop = VisualTrainingLoop();
  TypographyConfig? _typographyConfig;

  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _owlAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _owlAnimation =
        Tween<double>(begin: -3.0, end: 3.0).animate(_owlAnimationController);

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _prepareRound();
  }

  Future<void> _prepareRound() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'student_demo';
    final sessionId = 'sess_drawing_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Fetch Adaptive Typography and Init MAB
    final adaptiveData = await VisualService.getAdaptiveTypography(
      'drawing_interpretation',
      sessionId: sessionId,
    );

    if (adaptiveData != null && mounted) {
      final response = adaptiveData['response'] as TypographyResponse;
      final visualStrain = adaptiveData['visualStrain'] as double;

      setState(() {
        _typographyConfig = response.config;
      });

      // Start MAB Training Level
      _trainingLoop.startLevel(
        armId: response.armSelected,
        visualStrainBefore: visualStrain,
        sessionId: sessionId,
        studentId: studentId,
      );
    }
  }

  // Deprecated in favor of unified logic in _prepareRound

  @override
  void dispose() {
    _owlAnimationController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  void _nextSentence() async {
    await _trainingLoop.endLevel(accuracyDelta: 1.0);

    if (_currentSentenceIndex < _sentences.length - 1) {
      setState(() {
        _currentSentenceIndex++;
        _drawingPoints.clear();
        _isEraser = false;
      });
      _celebrate();
      _prepareRound(); // Start next round tracking
    } else {
      _showCompletionDialog();
    }
  }

  void _celebrate() {
    _celebrationController.forward().then((_) {
      _celebrationController.reverse();
    });
  }

  void _clearCanvas() {
    setState(() {
      _drawingPoints.clear();
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wow! ඔබ හොඳින් සටන් කෙරුවා!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Text('ඔබ සියලු චිතර අඳින්න අවසර දුන්න. ඔබ ශ්‍රේෂ්ඨ කලාකරයෙක්!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Home'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSentence = _sentences[_currentSentenceIndex];
    final progress = (_currentSentenceIndex + 1) / _sentences.length;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'චිතර අඳින්න හා තේරුම් ගන්න',
            style: TextStyle(
              fontSize: _typographyConfig?.fontSize ?? 18,
              letterSpacing: _typographyConfig?.letterSpacing,
            ),
          ),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            SkipButton(taskName: 'drawing_interpretation', onSkipped: _nextSentence),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.green.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              // Progress bar and sentence
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_currentSentenceIndex + 1}/${_sentences.length} වැකි',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Sentence card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Owl mascot
                          AnimatedBuilder(
                            animation: _owlAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _owlAnimation.value),
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/images/welcome_owl.png',
                              width: 60,
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.school, size: 60),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Text(
                                    'තේරුම් ගන්න!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    currentSentence['sinhala']!,
                                    style: TextStyle(
                                      fontSize: _typographyConfig?.fontSize ?? 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: _typographyConfig?.letterSpacing,
                                      height: _typographyConfig?.lineHeight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Canvas
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onPanDown: (details) => _onPanDown(details),
                      onPanUpdate: (details) => _onPanUpdate(details),
                      onPanEnd: (details) => _onPanEnd(),
                      child: Container(
                        key: _canvasKey,
                        child: CustomPaint(
                          painter: DrawingPainter(_drawingPoints),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tools
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Colors
                    ..._colors.map((color) {
                      final isSelected =
                          _selectedColor == color && !_isEraser;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                              _isEraser = false;
                              _strokeWidth = 4;
                            });
                          },
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 150),
                            scale: isSelected ? 1.2 : 1.0,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white,
                                      size: 24)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    // Eraser
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEraser = true;
                          _strokeWidth = 15;
                        });
                      },
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: _isEraser ? 1.2 : 1.0,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isEraser
                                  ? Colors.black
                                  : Colors.grey.shade300,
                              width: _isEraser ? 3 : 1,
                            ),
                            boxShadow: _isEraser
                                ? [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(Icons.cleaning_services,
                              size: 24,
                              color: _isEraser ? Colors.black : Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Clear
                    GestureDetector(
                      onTap: _clearCanvas,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red.shade300,
                            width: 2,
                          ),
                        ),
                        child: Icon(Icons.delete_outline,
                            size: 24, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Next button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _nextSentence,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _currentSentenceIndex == _sentences.length - 1
                        ? 'අවසන් කරන්න'
                        : 'ඉදිරියට යන්න',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPanDown(DragDownDetails details) {
    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _drawingPoints.add(
        DrawingPoint(
          offset: localPosition,
          paint: Paint()
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = _strokeWidth
            ..color = _isEraser ? Colors.white : _selectedColor,
        ),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _drawingPoints.add(
        DrawingPoint(
          offset: localPosition,
          paint: Paint()
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = _strokeWidth
            ..color = _isEraser ? Colors.white : _selectedColor,
        ),
      );
    });
  }

  void _onPanEnd() {
    setState(() {
      _drawingPoints.add(DrawingPoint(offset: Offset.zero, paint: null));
    });
  }
}

class DrawingPoint {
  final Offset offset;
  final Paint? paint;

  DrawingPoint({required this.offset, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].paint != null && points[i + 1].paint != null) {
        if (points[i].offset != Offset.zero && points[i + 1].offset != Offset.zero) {
          canvas.drawLine(
            points[i].offset,
            points[i + 1].offset,
            points[i].paint!,
          );
        }
      } else if (points[i].paint != null && points[i].offset != Offset.zero) {
        canvas.drawCircle(points[i].offset, points[i].paint!.strokeWidth / 2,
            points[i].paint!);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
