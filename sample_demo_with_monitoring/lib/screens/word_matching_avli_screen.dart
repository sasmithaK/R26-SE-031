import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/adaptive_state.dart';
import '../models/mbsv.dart';
import '../models/typography_config.dart';
import 'game_mode_overlay.dart';

class WordMatchingAVLIScreen extends StatefulWidget {
  const WordMatchingAVLIScreen({super.key});

  @override
  State<WordMatchingAVLIScreen> createState() => _WordMatchingAVLIScreenState();
}

class _WordMatchingAVLIScreenState extends State<WordMatchingAVLIScreen> {
  final String studentId = "DEMO_STUDENT_001";
  final List<Map<String, String>> wordPairs = [
    {'sinhala': 'කලාව', 'english': 'Art'},
    {'sinhala': 'ගඟ', 'english': 'River'},
    {'sinhala': 'මල්', 'english': 'Flowers'},
    {'sinhala': 'අහස', 'english': 'Sky'},
    {'sinhala': 'පොත', 'english': 'Book'},
  ];

  String? selectedSinhala;
  String? selectedEnglish;
  int matches = 0;
  DateTime? startTime;
  int hesitationCount = 0;
  int correctionCount = 0;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    // Initial call to set baseline typography
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAdaptation();
    });
  }

  void _triggerAdaptation() {
    final adaptiveState = Provider.of<AdaptiveState>(context, listen: false);
    
    // Simulate research-backed telemetry gathering
    final duration = DateTime.now().difference(startTime!).inMilliseconds;
    
    Map<String, dynamic> telemetry = {
      'hesitation_ms': duration > 2000 ? duration : 500,
      'correction_rate': correctionCount / (matches + 1),
      'response_latency': duration / (matches + 1),
      'touch_pressure': 0.5, // Mocked
      'swipe_velocity': 0.8, // Mocked
      'replay_count': 0,
      'hint_request_count': 0,
      'stylus_deviation': 0.1,
      'inter_tap_interval': 300,
      'read_aloud_pause_ms': 450,
      'syllable_rate': 3.2,
      'disfluency_count': 0,
    };

    adaptiveState.processInteraction(
      studentId: studentId,
      telemetry: telemetry,
      context: {
        'current_task': 'word_matching',
        'difficulty': 'medium',
        'session_time': 120,
      },
    );
  }

  void _handleMatch(String type, String value) {
    setState(() {
      if (type == 'sinhala') {
        if (selectedSinhala == value) {
          selectedSinhala = null; // Deselect
        } else {
          selectedSinhala = value;
        }
      } else {
        if (selectedEnglish == value) {
          selectedEnglish = null; // Deselect
        } else {
          selectedEnglish = value;
        }
      }

      // Check for match
      if (selectedSinhala != null && selectedEnglish != null) {
        final pair = wordPairs.firstWhere((p) => p['sinhala'] == selectedSinhala);
        if (pair['english'] == selectedEnglish) {
          matches++;
          selectedSinhala = null;
          selectedEnglish = null;
          
          final adaptiveState = Provider.of<AdaptiveState>(context, listen: false);
          adaptiveState.submitReward(
            studentId: studentId,
            armId: adaptiveState.currentArmId,
            reward: 1.0,
          );
          
          if (matches == wordPairs.length) {
             _showVictory();
          }
        } else {
          // Mismatch
          correctionCount++;
          selectedSinhala = null;
          selectedEnglish = null;
          _triggerAdaptation(); // Adapt on error
        }
      }
    });
  }

  void _showVictory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Well Done!"),
        content: const Text("You matched all the words."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Next Task"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adaptiveState = Provider.of<AdaptiveState>(context);
    final config = adaptiveState.currentConfig;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // 60% Game Area
              Expanded(
                flex: 6,
                child: _buildGameArea(),
              ),
              // Vertical Divider
              Container(width: 1, color: Colors.white10),
              // 40% Adaptive Log Panel
              Expanded(
                flex: 4,
                child: _buildLogPanel(),
              ),
            ],
          ),
          if (adaptiveState.gameModeTrigger)
            Positioned.fill(
              child: GameModeOverlay(
                onComplete: () {
                   adaptiveState.submitReward(
                    studentId: studentId,
                    armId: adaptiveState.currentArmId,
                    reward: 2.0, // Higher reward for completing mini-game
                  );
                  // We would normally tell the backend to deactivate gamification
                  // But for the demo, we'll just wait for the next typography update
                  // or force a refresh.
                  _triggerAdaptation();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    final adaptiveState = Provider.of<AdaptiveState>(context);
    final config = adaptiveState.currentConfig;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Word Matching Task",
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Match the Sinhala words with their English meanings.",
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          const SizedBox(height: 48),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildWordList('sinhala', config)),
                const SizedBox(width: 40),
                Expanded(child: _buildWordList('english', config)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(String type, TypographyConfig config) {
    final items = wordPairs.map((p) => p[type]!).toList()..shuffle();
    
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final val = items[index];
        final isSelected = (type == 'sinhala' ? selectedSinhala : selectedEnglish) == val;
        
        return GestureDetector(
          onTap: () => _handleMatch(type, val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.3) : const Color(0xFF161B2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.white10,
                width: 2,
              ),
              boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10)] : [],
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                style: _getAdaptiveStyle(config),
                child: Text(
                  val,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle _getAdaptiveStyle(TypographyConfig config) {
    // Robust Font Loading with Hex Color Support
    Color textColor;
    try {
      textColor = Color(int.parse(config.fontColor.replaceAll('#', '0xFF')));
      // If fontColor was default black but backgroundContrast is AAA, override for visibility
      if (config.fontColor == '#000000' && config.backgroundContrast == 'WCAG_AAA') {
        textColor = Colors.white;
      }
    } catch (_) {
      textColor = config.backgroundContrast == 'WCAG_AAA'
          ? Colors.white
          : const Color(0xFFE8E8E8);
    }

    try {
      return GoogleFonts.getFont(
        config.fontFamily,
        fontSize: config.fontSize,
        letterSpacing: config.letterSpacing,
        wordSpacing: config.wordSpacing,
        height: config.lineHeight,
        color: textColor,
      );
    } catch (e) {
      debugPrint("Font Error: ${config.fontFamily} failed, using system fallback. Error: $e");
      return TextStyle(
        fontSize: config.fontSize,
        letterSpacing: config.letterSpacing,
        wordSpacing: config.wordSpacing,
        height: config.lineHeight,
        color: textColor,
        fontFamily: 'sans-serif',
      );
    }
  }

  Widget _buildLogPanel() {
    final adaptiveState = Provider.of<AdaptiveState>(context);
    
    return Container(
      color: const Color(0xFF0F1322),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(),
          _buildMBSVDashboard(adaptiveState.currentMbsv),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text("ADAPTIVE DECISION LOG", style: TextStyle(fontSize: 12, color: Colors.white38, letterSpacing: 1.2)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: adaptiveState.logs.length,
              itemBuilder: (context, index) {
                final log = adaptiveState.logs[index];
                return _buildLogEntry(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F35),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Text(
            "AVLI MONITOR",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          const Badge(label: Text("LIVE"), backgroundColor: Colors.red),
        ],
      ),
    );
  }

  Widget _buildMBSVDashboard(MBSV mbsv) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMetricRow("Visual Strain", mbsv.visualStrainIndex, Colors.orange),
          const SizedBox(height: 12),
          _buildMetricRow("Engagement", mbsv.engagementIndex, Colors.green),
          const SizedBox(height: 12),
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
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            Text("${(value * 100).toInt()}%", style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(4),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    IconData icon;
    Color color;
    switch (log.type) {
      case 'telemetry': icon = Icons.sensors; color = Colors.blue; break;
      case 'mbsv': icon = Icons.psychology; color = Colors.purpleAccent; break;
      case 'typography': icon = Icons.text_fields; color = Colors.greenAccent; break;
      default: icon = Icons.info_outline; color = Colors.white54;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                ),
                Text(
                  DateFormat('HH:mm:ss.SSS').format(log.timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
