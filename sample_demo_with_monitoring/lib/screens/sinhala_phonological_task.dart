import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../services/adaptive_state.dart';
import '../models/mbsv.dart';

class SinhalaPhonologicalTask extends StatefulWidget {
  final VoidCallback? onComplete;

  const SinhalaPhonologicalTask({super.key, this.onComplete});

  @override
  State<SinhalaPhonologicalTask> createState() => _SinhalaPhonologicalTaskState();
}

class _SinhalaPhonologicalTaskState extends State<SinhalaPhonologicalTask> with TickerProviderStateMixin {
  final String studentId = "DEMO_STUDENT_001";

  // Task state
  int currentTaskIndex = 0;
  DateTime? taskStartTime;
  DateTime? firstInteractionTime;
  bool firstInteractionMade = false;

  // Feature tracking
  final List<Map<String, dynamic>> _touchEvents = [];
  int correctionCount = 0;
  int hintRequestCount = 0;
  int replayCount = 0;
  double maxTouchPressure = 0.5;
  List<double> swipeVelocities = [];
  List<double> tapIntervals = [];
  double stylusDeviation = 0.0;

  // Acoustic (mock)
  double mockReadAloudPause = 0.0;
  double mockSyllableRate = 0.0;
  int mockDisfluencyCount = 0;

  // Real-time display
  Map<String, double> currentFeatures = {};
  MBSV? currentMBSV;
  List<String> logs = [];

  late AnimationController _pulseController;

  final tasks = [
    {
      'type': 'syllable_tapping',
      'word': 'ශිෂ්‍ය', // Student
      'syllables': ['ශි', 'ෂ්‍ය'],
      'instruction': '🎯 ඔබ අසන සෙම එක එක වචන කොටස ගණන් කරන්න'
    },
    {
      'type': 'word_reading',
      'word': 'පනත',
      'sentence': 'එය පනතට අනුව සිදු විය.',
      'instruction': '📖 වචනය ඉඩ ඉඩ කරමින් කියවන්න'
    },
    {
      'type': 'letter_tracing',
      'letter': 'අ',
      'instruction': '✏️ අක්ෂරය අනුගමනය කරන්න'
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    taskStartTime = DateTime.now();
    _addLog('🚀 කර්තව්‍ය ආරම්භ කරන ලදී');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAdaptation();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _recordTouchAt(Offset position, {double pressure = 0.5}) {
    if (!firstInteractionMade) {
      firstInteractionTime = DateTime.now();
      firstInteractionMade = true;
    }

    _touchEvents.add({
      'x': position.dx,
      'y': position.dy,
      'pressure': pressure,
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
    });

    maxTouchPressure = pressure > maxTouchPressure ? pressure : maxTouchPressure;

    if (_touchEvents.length > 1) {
      double dist = (_touchEvents.last['x'] - _touchEvents[_touchEvents.length - 2]['x']).abs();
      int timeDiff = _touchEvents.last['timestamp_ms'] - _touchEvents[_touchEvents.length - 2]['timestamp_ms'];
      if (timeDiff > 0) {
        swipeVelocities.add(dist / timeDiff);
      }
      tapIntervals.add(timeDiff.toDouble());
    }
  }

  void _addLog(String message) {
    setState(() {
      logs.add('[${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}] $message');
      if (logs.length > 15) logs.removeAt(0);
    });
  }

  void _recordCorrection() {
    correctionCount++;
    _addLog('❌ නිවැරදි කිරීම # $correctionCount');
  }

  void _recordHintRequest() {
    hintRequestCount++;
    _addLog('💡 ඉඟිය ඉල්ලා ගත්තේ # $hintRequestCount');
  }

  void _recordReplay() {
    replayCount++;
    _addLog('🔊 ශබ්දය නැවත වාදනය කරන ලදී # $replayCount');
  }

  void _updateMockAcousticFeatures() {
    // Simulate acoustic features based on task difficulty
    mockReadAloudPause = 200 + (currentTaskIndex * 100).toDouble();
    mockSyllableRate = 4.5 - (currentTaskIndex * 0.3);
    mockDisfluencyCount = currentTaskIndex;
  }

  Future<void> _triggerAdaptation() async {
    if (!firstInteractionMade) {
      _addLog('⏳ එක්ක ඉඩ ගිණුම් නිතර කිරීම බලා ගෙන ඉන්න...');
      return;
    }

    _updateMockAcousticFeatures();

    double hesitationMs = firstInteractionTime != null
        ? taskStartTime!.difference(firstInteractionTime!).inMilliseconds.toDouble()
        : 0.0;

    double responseLatency = taskStartTime!.difference(DateTime.now()).inMilliseconds.abs().toDouble();

    double correctionRate = _touchEvents.isNotEmpty
        ? correctionCount / _touchEvents.length
        : 0.0;

    double swipeVel = swipeVelocities.isNotEmpty
        ? swipeVelocities.reduce((a, b) => a + b) / swipeVelocities.length
        : 50.0;

    double interTapStd = 0.0;
    if (tapIntervals.isNotEmpty) {
      double mean = tapIntervals.reduce((a, b) => a + b) / tapIntervals.length;
      double variance = tapIntervals.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / tapIntervals.length;
      interTapStd = variance.isNaN ? 0.0 : variance.sqrt();
    }

    final telemetry = {
      'student_id': studentId,
      'session_id': 'DEMO_SESSION',
      'task_id': 'sinhala_phonological_${DateTime.now().millisecondsSinceEpoch}',
      'event_type': 'TASK_COMPLETE',
      'response_latency': responseLatency.clamp(0, 10000),
      'hesitation_ms': hesitationMs.clamp(0, 5000),
      'correction_rate': correctionRate.clamp(0, 1),
      'touch_pressure': maxTouchPressure,
      'swipe_velocity': swipeVel.clamp(0, 500),
      'replay_count': replayCount,
      'hint_request_count': hintRequestCount,
      'stylus_deviation': stylusDeviation,
      'inter_tap_interval': interTapStd,
      'read_aloud_pause_ms': mockReadAloudPause,
      'syllable_rate': mockSyllableRate,
      'disfluency_count': mockDisfluencyCount,
      'touch_events': _touchEvents,
      'current_content_text': tasks[currentTaskIndex]['word'] ?? '',
    };

    currentFeatures = {
      'hesitation_ms': hesitationMs,
      'correction_rate': correctionRate,
      'response_latency': responseLatency,
      'touch_pressure': maxTouchPressure,
      'swipe_velocity': swipeVel,
      'replay_count': replayCount.toDouble(),
      'hint_request_count': hintRequestCount.toDouble(),
      'stylus_deviation': stylusDeviation,
      'inter_tap_interval': interTapStd,
      'read_aloud_pause_ms': mockReadAloudPause,
      'syllable_rate': mockSyllableRate,
      'disfluency_count': mockDisfluencyCount.toDouble(),
    };

    _addLog('📊 C1 බනින්න... (MBSV ගණනය කිරීම)');

    final adaptiveState = Provider.of<AdaptiveState>(context, listen: false);
    final mbsv = await adaptiveState.sendTelemetry(telemetry);

    setState(() {
      currentMBSV = mbsv;
    });

    _addLog('✅ MBSV ලබා ගත්තේ!');
    _addLog('📈 සිතින්න: CLI=${mbsv.cognitiveLoadIndex.toStringAsFixed(2)} | PSI=${mbsv.phonologicalStrainIndex.toStringAsFixed(2)}');
  }

  void _nextTask() {
    if (currentTaskIndex < tasks.length - 1) {
      setState(() {
        currentTaskIndex++;
        _touchEvents.clear();
        correctionCount = 0;
        hintRequestCount = 0;
        replayCount = 0;
        maxTouchPressure = 0.5;
        swipeVelocities.clear();
        tapIntervals.clear();
        stylusDeviation = 0.0;
        taskStartTime = DateTime.now();
        firstInteractionMade = false;
      });
      _addLog('➡️ අදාල කර්තව්‍ය ශ්‍රේණිය ${currentTaskIndex + 1}/${tasks.length}');
    } else {
      _addLog('🎉 සියලු කර්තව්‍ය සම්පූර්ණ!');
      if (widget.onComplete != null) widget.onComplete!();
    }
  }

  Color _getHealthColor(double value, {bool inverse = false}) {
    if (inverse) {
      if (value > 0.7) return Colors.green;
      if (value > 0.4) return Colors.orange;
      return Colors.red;
    } else {
      if (value < 0.4) return Colors.green;
      if (value < 0.7) return Colors.orange;
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = tasks[currentTaskIndex];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Left: Task Area (70%)
          Expanded(
            flex: 7,
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  color: Colors.blue[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🇱🇰 සිංහල ශබ්ද-අක්ෂර සම්බන්ධතා කර්තව්‍ය',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'කර්තව්‍ය ${currentTaskIndex + 1} / ${tasks.length}: ${task['type'] == 'syllable_tapping' ? '🎯 වචන කොටස ගණනය කිරීම' : task['type'] == 'word_reading' ? '📖 වචනය කියවීම' : '✏️ අක්ෂර අනුගමනය කිරීම'}',
                        style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),

                // Task Content
                Expanded(
                  child: Listener(
                    onPointerDown: (e) => _recordTouchAt(e.localPosition, pressure: e.pressure),
                    onPointerMove: (e) => _recordTouchAt(e.localPosition, pressure: e.pressure),
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Main content based on task type
                          if (task['type'] == 'syllable_tapping')
                            _buildSyllableTappingTask(task)
                          else if (task['type'] == 'word_reading')
                            _buildWordReadingTask(task)
                          else if (task['type'] == 'letter_tracing')
                            _buildLetterTracingTask(task),

                          SizedBox(height: 40),

                          // Control buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _recordHintRequest,
                                icon: Text('💡'),
                                label: Text('ඉඟිය'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: _recordReplay,
                                icon: Text('🔊'),
                                label: Text('නැවත වාදනය'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: _recordCorrection,
                                icon: Text('❌'),
                                label: Text('නිවැරදි කිරීම'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 30),

                          // Submit & Next
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _triggerAdaptation,
                                icon: Text('📊'),
                                label: Text('C1 වලින් ගණනය කරන්න'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                ),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: _nextTask,
                                icon: Text('➡️'),
                                label: Text('ඉදිරි කර්තව්‍ය'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right: Monitoring Panel (30%)
          Container(
            width: MediaQuery.of(context).size.width * 0.3,
            color: Colors.grey[900],
            child: Column(
              children: [
                // MBSV Display
                Container(
                  padding: EdgeInsets.all(15),
                  color: Colors.blue[800],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 MBSV ස්ථිතිය',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 12),
                      if (currentMBSV != null)
                        ...[
                          _buildMBSVIndicator('🧠 සිතින්න', currentMBSV!.cognitiveLoadIndex),
                          _buildMBSVIndicator('🗣️ ශබ්දය', currentMBSV!.phonologicalStrainIndex),
                          _buildMBSVIndicator('👁️ දැකීම', currentMBSV!.visualStrainIndex),
                          _buildMBSVIndicator('😴 තෙහෙට්ටුව', currentMBSV!.sessionFatigueIndex),
                          _buildMBSVIndicator('😊 සබඳතාව', currentMBSV!.engagementIndex),
                        ]
                      else
                        Text(
                          '⏳ බලා ගෙන ඉන්න...',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),

                // Raw Features
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚙️ ඉහත දේ ගුණ',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10),
                          ..._buildFeaturesList(),
                          SizedBox(height: 20),
                          Text(
                            '📝 ලඹන්න',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: ListView(
                              children: logs.map((log) => Text(
                                log,
                                style: GoogleFonts.inconsolata(
                                  fontSize: 10,
                                  color: Colors.green[300],
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeaturesList() {
    return currentFeatures.entries.map((e) {
      String label = e.key;
      double value = e.value;
      Color color = Colors.grey[400]!;

      if (label.contains('pressure') || label.contains('velocity')) {
        color = _getHealthColor(value / 100);
      } else if (label.contains('rate') || label.contains('syllable')) {
        color = _getHealthColor(value / 5, inverse: true);
      } else {
        color = _getHealthColor(value / 1000);
      }

      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inconsolata(fontSize: 10, color: Colors.white70),
            ),
            Text(
              value.toStringAsFixed(1),
              style: GoogleFonts.inconsolata(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMBSVIndicator(String label, double value) {
    Color barColor = _getHealthColor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.white)),
            Text(
              value.toStringAsFixed(2),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSyllableTappingTask(Map task) {
    return Column(
      children: [
        Text(
          task['instruction'],
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 30),
        Text(
          task['word'],
          style: GoogleFonts.outfit(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < (task['syllables'] as List).length; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: GestureDetector(
                  onTap: () => _recordTouchAt(Offset(100 * (i + 1).toDouble(), 100)),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      border: Border.all(color: Colors.blue[800]!, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      task['syllables'][i],
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordReadingTask(Map task) {
    return Column(
      children: [
        Text(
          task['instruction'],
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 30),
        Container(
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.yellow[50],
            border: Border.all(color: Colors.orange[300]!, width: 2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            task['sentence'],
            style: GoogleFonts.outfit(fontSize: 20, color: Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red[100],
            border: Border.all(color: Colors.red[400]!, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            task['word'],
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red[900]),
          ),
        ),
      ],
    );
  }

  Widget _buildLetterTracingTask(Map task) {
    return Column(
      children: [
        Text(
          task['instruction'],
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 40),
        CustomPaint(
          size: Size(300, 300),
          painter: LetterTraceCanvas(
            letter: task['letter'],
            onPaint: (deviation) {
              setState(() => stylusDeviation = deviation);
            },
          ),
        ),
      ],
    );
  }
}

class LetterTraceCanvas extends CustomPainter {
  final String letter;
  final Function(double) onPaint;

  LetterTraceCanvas({required this.letter, required this.onPaint});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
      paint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: GoogleFonts.outfit(fontSize: 120, color: Colors.grey[600]),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    onPaint(5.0);
  }

  @override
  bool shouldRepaint(LetterTraceCanvas oldDelegate) => false;
}
