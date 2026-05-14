import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/adaptive_state.dart';
import '../models/mbsv.dart';
import '../models/typography_config.dart';
import '../widgets/skip_button.dart';
import 'letter_puzzle_game.dart';

class WordMatchingRound {
  final String targetWord;
  final String imagePath;
  final List<String> options;

  WordMatchingRound({
    required this.targetWord,
    required this.imagePath,
    required this.options,
  });
}

class WordMatchingTask extends StatefulWidget {
  final VoidCallback? onComplete;

  const WordMatchingTask({super.key, this.onComplete});

  @override
  State<WordMatchingTask> createState() => _WordMatchingTaskState();
}

class _WordMatchingTaskState extends State<WordMatchingTask> with TickerProviderStateMixin {
  final String studentId = "DEMO_STUDENT_001";
  late List<WordMatchingRound> rounds;
  int currentRoundIndex = 0;

  int selectedIndex = -1;
  bool? isCorrect;
  DateTime? startTime;
  int errorCount = 0;

  // Touch event tracking for Kalman filter feature in C1
  final List<Map<String, dynamic>> _touchEvents = [];

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    rounds = [
      WordMatchingRound(
        targetWord: 'ගහ',
        imagePath: 'assets/images/tree_character.png',
        options: ['මල', 'ගහ', 'කොළය', 'පලතුර'],
      ),
      WordMatchingRound(
        targetWord: 'ඇපල්',
        imagePath: 'assets/images/apple_character.png',
        options: ['කෙසෙල්', 'දොඩම්', 'ඇපල්', 'මිදි'],
      ),
      WordMatchingRound(
        targetWord: 'අලියා',
        imagePath: 'assets/images/elephant.png',
        options: ['කොටියා', 'අලියා', 'සිංහයා', 'වලසා'],
      ),
      WordMatchingRound(
        targetWord: 'බල්ලා',
        imagePath: 'assets/images/dog_character.png',
        options: ['පූසා', 'බල්ලා', 'හරකා', 'එළුවා'],
      ),
      WordMatchingRound(
        targetWord: 'පූසා',
        imagePath: 'assets/images/cat_character.png',
        options: ['මීයා', 'පූසා', 'සිංහයා', 'කොටියා'],
      ),
    ];

    startTime = DateTime.now();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAdaptation(initial: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerAdaptation({bool initial = false}) {
    if (!mounted) return;

    final adaptiveState = Provider.of<AdaptiveState>(context, listen: false);
    final duration = DateTime.now().difference(startTime!).inMilliseconds;
    final currentWord = rounds[currentRoundIndex].targetWord;

    // Snapshot captured touch events for Kalman filter; clear for next round
    final touchSnapshot = List<Map<String, dynamic>>.from(_touchEvents);
    if (!initial) _touchEvents.clear();

    Map<String, dynamic> telemetry = {
      'hesitation_ms': initial ? 0 : (duration > 3000 ? duration : 800),
      'correction_rate': initial ? 0.0 : errorCount / rounds[currentRoundIndex].options.length,
      'response_latency': duration,
      'touch_pressure': 0.45,
      'swipe_velocity': 0.12,
      'replay_count': 0,
      'hint_request_count': 0,
      'stylus_deviation': 0.02,
      'inter_tap_interval': initial ? 0 : 450,
      'read_aloud_pause_ms': 550,
      'syllable_rate': 3.1,
      'disfluency_count': errorCount,
      // Actual touch coordinates → Kalman filter in C1
      'touch_events': touchSnapshot,
    };

    adaptiveState.processInteraction(
      studentId: studentId,
      telemetry: telemetry,
      context: {
        'session_id': 'DEMO_SESSION',   // must match reward submission session_id
        'session_number': 1,
        'child_age_years': 7,
        'current_task': 'word_matching',
        'target': currentWord,
        // Sinhala text fed to C2 SOVCM for per-character visual complexity scoring
        'current_content_text': currentWord,
        'phase': initial ? 'calibration' : 'active',
        'total_rounds': rounds.length,
        'current_round': currentRoundIndex + 1,
      },
    );
  }

  void _recordTouchAt(Offset position) {
    _touchEvents.add({
      'x': position.dx,
      'y': position.dy,
      'pressure': 0.5,
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
    });
    // Keep last 30 events to avoid unbounded growth between telemetry sends
    if (_touchEvents.length > 30) _touchEvents.removeAt(0);
  }

  void _handleOptionSelect(int index) {
    if (isCorrect == true) return;

    setState(() {
      selectedIndex = index;
      String option = rounds[currentRoundIndex].options[index];
      
      if (option == rounds[currentRoundIndex].targetWord) {
        isCorrect = true;
        final adaptiveState = Provider.of<AdaptiveState>(context, listen: false);
        adaptiveState.submitReward(
          studentId: studentId,
          armId: adaptiveState.currentArmId,
          reward: 1.0,
        );
        _triggerAdaptation();
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (currentRoundIndex < rounds.length - 1) {
            setState(() {
              currentRoundIndex++;
              selectedIndex = -1;
              isCorrect = null;
              errorCount = 0;
              startTime = DateTime.now();
            });
            _triggerAdaptation(initial: true);
          } else {
            if (widget.onComplete != null) {
              widget.onComplete!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        });
      } else {
        isCorrect = false;
        errorCount++;
        _triggerAdaptation();
      }
    });
  }

  void _skipAndContinue() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptiveState = Provider.of<AdaptiveState>(context);
    final config = adaptiveState.currentConfig;

    Color bgColor = Colors.white;
    if (config.backgroundContrast == 'WCAG_AAA' || config.backgroundContrast == 'HIGH') {
      bgColor = const Color(0xFFFFFDE7);
    } else if (config.backgroundContrast == 'LOW') {
      bgColor = const Color(0xFFF0F4FF);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Row(
            children: [
              // 60% Task Area
              Expanded(
                flex: 6,
                child: _buildTaskArea(config),
              ),
              Container(width: 1, color: Colors.grey[100]),
              // 40% Monitoring Panel
              Expanded(
                flex: 4,
                child: _buildMonitoringPanel(adaptiveState),
              ),
            ],
          ),
          // Gamification Overlay
          if (adaptiveState.gameModeTrigger)
            LetterPuzzleGame(
              onComplete: () {
                adaptiveState.resetGameTrigger();
                setState(() {
                  startTime = DateTime.now();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskArea(TypographyConfig config) {
    final round = rounds[currentRoundIndex];

    return Listener(
      onPointerDown: (e) => _recordTouchAt(e.localPosition),
      onPointerMove: (e) => _recordTouchAt(e.localPosition),
      child: _buildTaskContent(round, config),
    );
  }

  Widget _buildTaskContent(WordMatchingRound round, TypographyConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "වචනය තෝරන්න",
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    "Select the matching word (${currentRoundIndex + 1}/${rounds.length})",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              SkipButton(onPressed: _skipAndContinue),
            ],
          ),
          
          const Spacer(),
          
          ScaleTransition(
            scale: _animation,
            child: Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  round.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 60),
          
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: List.generate(round.options.length, (index) => _buildOptionCard(index, config)),
          ),
          
          const Spacer(),
          
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: isCorrect != null ? 1.0 : 0.0,
            child: _buildFeedbackWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackWidget() {
    bool success = isCorrect == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: success ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: success ? Colors.green[100]! : Colors.red[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            success ? Icons.stars_rounded : Icons.info_outline_rounded,
            color: success ? Colors.green : Colors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            success ? "මරු! (Excellent!)" : "නැවත උත්සාහ කරන්න (Try Again)",
            style: GoogleFonts.outfit(
              color: success ? Colors.green[800] : Colors.red[800],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, TypographyConfig config) {
    bool isSelected = selectedIndex == index;
    final round = rounds[currentRoundIndex];
    String option = round.options[index];
    
    Color borderColor = Colors.grey[200]!;
    if (isSelected) {
      if (isCorrect == true && option == round.targetWord) borderColor = Colors.green;
      else if (isCorrect == false) borderColor = Colors.red;
    }

    return GestureDetector(
      onTap: () => _handleOptionSelect(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        decoration: BoxDecoration(
          color: isSelected && isCorrect == true && option == round.targetWord 
              ? Colors.green[50] 
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(
              color: isSelected ? borderColor.withOpacity(0.2) : Colors.black.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          style: _getAdaptiveStyle(config, isSelected),
          child: Transform.translate(
            offset: Offset(0, config.diacriticOffset),
            child: Text(option),
          ),
        ),
      ),
    );
  }

  TextStyle _getAdaptiveStyle(TypographyConfig config, bool isSelected) {
    Color textColor = Colors.black87;
    
    if (config.backgroundContrast == 'HIGH' || config.backgroundContrast == 'WCAG_AAA') {
      textColor = Colors.black;
    } else if (config.backgroundContrast == 'LOW') {
      textColor = Colors.grey[800]!;
    }

    const String fallbackFont = 'Noto Sans Sinhala';

    try {
      return GoogleFonts.getFont(
        config.fontFamily,
        fontSize: config.fontSize + 4,
        letterSpacing: config.letterSpacing,
        wordSpacing: config.wordSpacing,
        height: config.lineHeight,
        color: textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      );
    } catch (e) {
      return GoogleFonts.notoSansSinhala(
        fontSize: config.fontSize + 4,
        letterSpacing: config.letterSpacing,
        wordSpacing: config.wordSpacing,
        height: config.lineHeight,
        color: textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      );
    }
  }

  Widget _buildMonitoringPanel(AdaptiveState state) {
    return Container(
      color: const Color(0xFFFBFBFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(state),
          _buildMBSVDashboard(state.currentMbsv),
          _buildRewardHistory(state.rewardHistory),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Text(
              "GRANULAR TELEMETRY & ADAPTATION LOG",
              style: TextStyle(
                fontSize: 11,
                color: Colors.black45,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: state.logs.length,
              separatorBuilder: (_, __) => Divider(color: Colors.grey[100], height: 1),
              itemBuilder: (context, index) {
                final log = state.logs[state.logs.length - 1 - index];
                return _buildLogEntry(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(AdaptiveState state) {
    bool isAdaptive = state.evaluationMode == EvaluationMode.adaptive;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.indigo, size: 28),
              const SizedBox(width: 12),
              Text(
                "PEDAGOGICAL MONITOR",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeToggleBtn(
                    label: "FIXED",
                    isActive: !isAdaptive,
                    onTap: () => state.setEvaluationMode(EvaluationMode.fixed),
                  ),
                ),
                Expanded(
                  child: _buildModeToggleBtn(
                    label: "ADAPTIVE",
                    isActive: isAdaptive,
                    onTap: () => state.setEvaluationMode(EvaluationMode.adaptive),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text(
            "SYNCED",
            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggleBtn({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive ? [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ] : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.indigo : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardHistory(List<double> rewards) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "REWARD PROGRESS (LinUCB Optimization)",
            style: TextStyle(
              fontSize: 10,
              color: Colors.black38,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rewards.isEmpty 
                ? [Expanded(child: Text("Waiting for task completion...", style: TextStyle(fontSize: 10, color: Colors.black26)))]
                : rewards.map((r) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 40 * r.clamp(0.1, 1.0),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMBSVDashboard(MBSV mbsv) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMetricRow("Visual Strain", mbsv.visualStrainIndex, Colors.orange),
          const SizedBox(height: 18),
          _buildMetricRow("Engagement", mbsv.engagementIndex, Colors.green),
          const SizedBox(height: 18),
          _buildMetricRow("Cognitive Load", mbsv.cognitiveLoadIndex, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
            Text(
              "${(value * 100).toInt()}%",
              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    IconData icon;
    Color color;
    switch (log.type) {
      case 'telemetry':
        icon = Icons.bolt_rounded;
        color = Colors.blue;
        break;
      case 'mbsv':
        icon = Icons.psychology_alt_rounded;
        color = Colors.purple;
        break;
      case 'typography':
        icon = Icons.format_paint_rounded;
        color = Colors.green;
        break;
      case 'system':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = Colors.grey;
    }
  
    bool isParameterLog = log.message.trim().startsWith('>');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isParameterLog ? Colors.indigo[50] : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isParameterLog ? Icons.tune_rounded : icon, 
              size: 16, 
              color: isParameterLog ? Colors.indigo : color
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: GoogleFonts.inter(
                    fontSize: isParameterLog ? 13 : 12, 
                    color: isParameterLog ? Colors.indigo[900] : Colors.black87, 
                    fontWeight: isParameterLog ? FontWeight.w800 : (log.type == 'telemetry' ? FontWeight.w400 : FontWeight.w600),
                    letterSpacing: isParameterLog ? 0.5 : 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm:ss.SSS').format(log.timestamp),
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, color: Colors.black26),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
