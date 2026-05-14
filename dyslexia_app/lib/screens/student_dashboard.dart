// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../utils/logger.dart';
// import '../services/task_score_service.dart';
// import '../services/visual_service.dart';
// import '../models/visual_config.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

// class _StudentDashboardState extends State<StudentDashboard> {
//   TypographyConfig _config = TypographyConfig();
//   bool _isLoading = true;
//   late String studentId;
//   late String sessionId;
class _StudentScoreItem {
  final String taskName;
  final double score;
  final double? maxScore;
  final String level;

  const _StudentScoreItem({
    required this.taskName,
    required this.score,
    required this.maxScore,
    required this.level,
  });
}

class _StudentDashboardState extends State<StudentDashboard> {
  static const String _scoresBaseUrl =
      'http://127.0.0.1:5001/api/v1/scores/task';

  late Future<List<_StudentScoreItem>> _scoresFuture;
  int _savedColorIndex = 0;
  double _savedFontSize = 20.0;
  String _savedTier = 'Tier 1';
  int _savedTotalScore = 0;
  bool _savedIsNewStudent = false;

  // Typography configuration with defaults
  final Map<String, dynamic> _config = {
    'fontFamily': 'Roboto',
    'fontSize': 20.0,
  };

  @override
  void initState() {
    super.initState();
  //   sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
  //   _initializeDashboard();
  // }

  // Future<void> _initializeDashboard() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   studentId = prefs.getString('student_id') ?? 'student_demo';
    
  //   await _fetchAdaptiveUI();
    
  //   if (mounted) {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  // Future<void> _fetchAdaptiveUI() async {
  //   try {
  //     // 1. Get latest behavioral state (MBSV) from C1
  //     final mbsvData = await TaskScoreService.getLatestMBSV(studentId);
      
  //     double visualStrain = 0.5;
  //     double engagement = 0.5;
  //     double phonologicalStrain = 0.5;

  //     if (mbsvData != null && mbsvData['mbsv'] != null) {
  //       final m = mbsvData['mbsv'];
  //       visualStrain = (m['visual_strain_index'] as num).toDouble();
  //       engagement = (m['engagement_index'] as num).toDouble();
  //       phonologicalStrain = (m['phonological_strain_index'] as num).toDouble();
  //     }

  //     // 2. Get adaptive typography from C2 based on MBSV
  //     final typographyResponse = await VisualService.getTypographyConfig(
  //       studentId: studentId,
  //       sessionId: sessionId,
  //       visualStrain: visualStrain,
  //       engagement: engagement,
  //       phonologicalStrain: phonologicalStrain,
  //     );

  //     if (typographyResponse != null) {
  //       setState(() {
  //         _config = typographyResponse.config;
  //       });
  //     }
  //   } catch (e, stackTrace) {
  //     AppLogger.error('Error in adaptive UI loop', error: e, stackTrace: stackTrace, tag: 'StudentDashboard');
  //   }
  // }

  // @override
  // Widget build(BuildContext context) {
  //   if (_isLoading) {
  //     return const Scaffold(body: Center(child: CircularProgressIndicator()));
  //   }

  //   final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  //   final int colorIndex = args != null && args['preferredColorIndex'] is int ? args['preferredColorIndex'] as int : 0;
    
  //   // Override manual fontSize with adaptive one from C2
  //   final double fontSize = _config.fontSize;
    _scoresFuture = _loadStudentScores();
    _startAutoRefresh();
    _loadSavedDashboardState();
  }

  Future<void> _loadSavedDashboardState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      _savedColorIndex = prefs.getInt('preferred_color_index') ?? 0;
      _savedFontSize = prefs.getDouble('preferred_font_size') ?? 20.0;
      _savedTier = prefs.getString('student_tier') ?? 'Tier 1';
      _savedTotalScore = prefs.getInt('student_total_score') ?? 0;
      _savedIsNewStudent = prefs.getBool('student_is_new') ?? false;
    });
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _scoresFuture = _loadStudentScores();
        });
        _startAutoRefresh();
      }
    });
  }

  Future<List<_StudentScoreItem>> _loadStudentScores() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id');
    if (studentId == null || studentId.isEmpty) {
      return const [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_scoresBaseUrl/$studentId'),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final scores = decoded['scores'] as List? ?? [];

      // Group scores by task name and get the latest/highest score for each task
      final Map<String, _StudentScoreItem> taskScoresMap = {};

      for (final item in scores) {
        final taskName = item['task_name']?.toString() ?? 'Task';
        final score = (item['score'] as num?)?.toDouble() ?? 0;
        final maxScore = (item['max_score'] as num?)?.toDouble();
        final level = _scoreLevel(score, maxScore);

        // Keep only the latest/highest score for each task
        if (!taskScoresMap.containsKey(taskName) ||
            score > taskScoresMap[taskName]!.score) {
          taskScoresMap[taskName] = _StudentScoreItem(
            taskName: taskName,
            score: score,
            maxScore: maxScore,
            level: level,
          );
        }
      }

      return taskScoresMap.values.toList();
    } catch (_) {
      return const [];
    }
  }

  String _scoreLevel(double score, double? maxScore) {
    if (maxScore == null || maxScore <= 0) {
      if (score >= 75) return 'හොඳ';
      if (score >= 40) return 'සාමාන්‍ය';
      return 'අඩු';
    }

    final percentage = (score / maxScore) * 100;
    if (percentage >= 75) return 'හොඳ';
    if (percentage >= 40) return 'සාමාන්‍ය';
    return 'අඩු';
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final int colorIndex = args != null && args['preferredColorIndex'] is int
      ? args['preferredColorIndex'] as int
      : _savedColorIndex;
    final double fontSize = args != null && args['preferredFontSize'] is double
      ? args['preferredFontSize'] as double
      : _savedFontSize;

    final List<Map<String, Color>> palette = [
      {'bg': const Color(0xFFFFFFFF), 'accent': const Color(0xFFE0E0E0)},
      {'bg': const Color(0xFFE3F2FD), 'accent': const Color(0xFF90CAF9)},
      {'bg': const Color(0xFFFFFDE7), 'accent': const Color(0xFFFFF176)},
      {'bg': const Color(0xFFE8F5E9), 'accent': const Color(0xFFA5D6A7)},
      {'bg': const Color(0xFFFCE4EC), 'accent': const Color(0xFFF48FB1)},
      {'bg': const Color(0xFFF3E5F5), 'accent': const Color(0xFFCE93D8)},
      {'bg': const Color(0xFFE1F5FE), 'accent': const Color(0xFF81D4FA)},
    ];

    final bg = palette[(colorIndex.clamp(0, palette.length - 1))]['bg']!;
    final accent =
        palette[(colorIndex.clamp(0, palette.length - 1))]['accent']!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, accent.withValues(alpha: 0.2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              // 'මගේ වැඩ', 
              // style: TextStyle(
              //   fontSize: fontSize + 12, 
              //   fontWeight: FontWeight.w900,
              //   letterSpacing: _config.letterSpacing,
              //   fontFamily: _config.fontFamily,
              // )
              'මගේ වැඩ',
              style: TextStyle(
                fontSize: fontSize + 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: accent.computeLuminance() > 0.5
                ? Colors.brown.shade900
                : Colors.white,
            elevation: 0,
            centerTitle: true,
            bottom: TabBar(
              labelColor: accent,
              unselectedLabelColor: accent.withValues(alpha: 0.7),
              indicatorColor: accent,
              tabs: const [
                Tab(text: 'Home'),
                Tab(text: 'Games'),
              ],
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: TabBarView(
                children: [
                  _buildHomeTab(context, fontSize, accent),
                  _buildGamesTab(context, fontSize),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, double fontSize, Color accent) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _scoresFuture = _loadStudentScores();
        });
        await _scoresFuture;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
        //     Container(
        //       width: 100,
        //       height: 100,
        //       decoration: BoxDecoration(
        //         shape: BoxShape.circle,
        //         border: Border.all(color: Colors.white, width: 6),
        //         boxShadow: [
        //           BoxShadow(color: accent.withValues(alpha: 0.4), offset: const Offset(0, 8), blurRadius: 0),
        //         ],
        //       ),
        //       child: ClipOval(
        //         child: Image.asset(
        //           'assets/images/student_icon.png',
        //           fit: BoxFit.cover,
        //           errorBuilder: (context, error, stackTrace) => const Icon(Icons.child_care, size: 50),
        //         ),
        //       ),
        //     ),
        //     const SizedBox(width: 20),
        //     Expanded(
        //       child: Text(
        //         'ක්‍රීඩා කරමු!',
        //         style: TextStyle(
        //           fontSize: fontSize + 20,
        //           fontWeight: FontWeight.w900,
        //           color: accent,
        //           letterSpacing: _config.letterSpacing,
        //           fontFamily: _config.fontFamily,
        //           shadows: const [
        //             Shadow(color: Colors.white, blurRadius: 5, offset: Offset(2, 2)),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
        // const SizedBox(height: 40),
        // Expanded(
        //   child: Builder(builder: (context) {
        //     final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        //     final bool isNew = args != null && args['isNewStudent'] == true;
        //     if (isNew) {
        //       final tier = args['tier'] as String? ?? 'Tier 1';
        //       final score = args['totalScore'] as int? ?? 0;
        //       return ListView(
        //         physics: const BouncingScrollPhysics(),
        //         children: [
        //           Container(
        //             padding: const EdgeInsets.all(16),
        //             decoration: BoxDecoration(
        //               color: Colors.white,
        //               borderRadius: BorderRadius.circular(20),
        //               boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 12)],
        //             ),
        //             child: Column(
        //               crossAxisAlignment: CrossAxisAlignment.start,
        //               children: [
        //                 Text(
        //                   'Initial assessment', 
        //                   style: TextStyle(
        //                     fontSize: fontSize + 4, 
        //                     fontWeight: FontWeight.w900, 
        //                     color: accent,
        //                     fontFamily: _config.fontFamily,
        //                   )
        //                 ),
        //                 const SizedBox(height: 8),
        //                 Text('Tier: $tier', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700)),
        //                 const SizedBox(height: 4),
        //                 Text('Risk score: $score', style: TextStyle(fontSize: fontSize - 2)),
            Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        offset: const Offset(0, 8),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/student_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.child_care, size: 50),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'ක්‍රීඩා කරමු!',
                    style: TextStyle(
                      fontSize: fontSize + 20,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      shadows: const [
                        Shadow(
                          color: Colors.white,
                          blurRadius: 5,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Builder(
              builder: (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                final bool isNew = args != null
                    ? args['isNewStudent'] == true
                    : _savedIsNewStudent;
                if (isNew) {
                  final tier = args != null
                      ? args['tier'] as String? ?? _savedTier
                      : _savedTier;
                  final score = args != null
                      ? args['totalScore'] as int? ?? _savedTotalScore
                      : _savedTotalScore;
                  return ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.12),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Initial assessment',
                              style: TextStyle(
                                fontSize: fontSize + 4,
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tier: $tier',
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Risk score: $score',
                              style: TextStyle(fontSize: fontSize - 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildScoreCard(fontSize, accent),
                      const SizedBox(height: 24),
                      _buildGameCard(
                        context,
                        title: 'අකුරු හඳුනාගනිමු',
                        icon: Icons.sort_by_alpha_rounded,
                        color: Colors.blue.shade400,
                        route: '/letter_id',
                        fontSize: fontSize,
                      ),
                      const SizedBox(height: 24),
                      _buildGameCard(
                        context,
                        title: 'අපි කියවමු',
                        icon: Icons.menu_book_rounded,
                        color: Colors.teal.shade400,
                        route: '/reading_fluency',
                        fontSize: fontSize,
                      ),
                      const SizedBox(height: 24),
                      _buildGameCard(
                        context,
                        title: 'කතාව කියවමු',
                        icon: Icons.chrome_reader_mode_rounded,
                        color: Colors.indigo.shade400,
                        route: '/story_reading',
                        fontSize: fontSize,
                      ),
                      const SizedBox(height: 24),
                      _buildGameCard(
                        context,
                        title: 'කියවීමේ වටහා ගැනීම',
                        icon: Icons.image_search_rounded,
                        color: Colors.orange.shade400,
                        route: '/reading_comprehension',
                        fontSize: fontSize,
                      ),
                    ],
                  );
                }

                // Default full dashboard for returning students
                return ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    _buildScoreCard(fontSize, accent),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'අකුරු හඳුනාගනිමු',
                      icon: Icons.sort_by_alpha_rounded,
                      color: Colors.blue.shade400,
                      route: '/letter_id',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'වචන ගලපමු',
                      icon: Icons.extension_rounded,
                      color: Colors.green.shade400,
                      route: '/word_matching',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'රූපයක් අඳිමු',
                      icon: Icons.brush_rounded,
                      color: Colors.purple.shade400,
                      route: '/draw_a_man',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'කතා සකස් කරමු',
                      icon: Icons.auto_stories_rounded,
                      color: Colors.deepOrange.shade300,
                      route: '/story_sequencing',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'චිතර අඳින්න',
                      icon: Icons.brush_rounded,
                      color: Colors.cyan.shade400,
                      route: '/drawing_interpretation',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'සදම් රේල්ලුව',
                      icon: Icons.train_rounded,
                      color: Colors.red.shade400,
                      route: '/syllable_train',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'ගිගුරුම් අනුපිළිවෙල',
                      icon: Icons.bug_report_rounded,
                      color: Colors.amber.shade600,
                      route: '/firefly_tracking',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'අපි කියවමු',
                      icon: Icons.menu_book_rounded,
                      color: Colors.teal.shade400,
                      route: '/reading_fluency',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'කියවීමේ වටහා ගැනීම',
                      icon: Icons.image_search_rounded,
                      color: Colors.orange.shade400,
                      route: '/reading_comprehension',
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 24),
                    _buildGameCard(
                      context,
                      title: 'කතාව කියවමු',
                      icon: Icons.chrome_reader_mode_rounded,
                      color: Colors.indigo.shade400,
                      route: '/story_reading',
                      fontSize: fontSize,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(double fontSize, Color accent) {
    return FutureBuilder<List<_StudentScoreItem>>(
      future: _scoresFuture,
      builder: (context, snapshot) {
        final scores = snapshot.data ?? const [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 12),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task scores',
                style: TextStyle(
                  fontSize: fontSize + 4,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (scores.isEmpty)
                Text(
                  'No task scores yet.',
                  style: TextStyle(fontSize: fontSize - 2),
                )
              else
                Column(
                  children: scores.map((item) {
                    final badgeColor = item.level == 'හොඳ'
                        ? Colors.green
                        : item.level == 'සාමාන්‍ය'
                        ? Colors.orange
                        : Colors.red;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.taskName,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.maxScore == null
                                        ? 'Score: ${item.score.toStringAsFixed(0)}'
                                        : 'Score: ${item.score.toStringAsFixed(0)} / ${item.maxScore!.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: fontSize - 4),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.shade100,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.level,
                                style: TextStyle(
                                  fontSize: fontSize - 4,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGamesTab(BuildContext context, double fontSize) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _buildGameCard(
          context,
          title: 'අකුරු හඳුනාගනිමු',
          icon: Icons.sort_by_alpha_rounded,
          color: Colors.blue.shade400,
          route: '/letter_id',
          fontSize: fontSize,
        ),
        const SizedBox(height: 24),
        _buildGameCard(
          context,
          title: 'ගිගුරුම් අනුපිළිවෙල',
          icon: Icons.bug_report_rounded,
          color: Colors.amber.shade600,
          route: '/firefly_tracking',
          fontSize: fontSize,
        ),
        const SizedBox(height: 24),
        _buildGameCard(
          context,
          title: 'චිතර අඳින්න',
          icon: Icons.brush_rounded,
          color: Colors.cyan.shade400,
          route: '/drawing_interpretation',
          fontSize: fontSize,
        ),
        const SizedBox(height: 24),
        _buildGameCard(
          context,
          title: 'කතා සකස් කරමු',
          icon: Icons.auto_stories_rounded,
          color: Colors.deepOrange.shade300,
          route: '/story_sequencing',
          fontSize: fontSize,
        ),
        const SizedBox(height: 24),
        _buildGameCard(
          context,
          title: 'සදම් රේල්ලුව',
          icon: Icons.train_rounded,
          color: Colors.red.shade400,
          route: '/syllable_train',
          fontSize: fontSize,
        ),
      ],
    );
  }

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
    required double fontSize,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: 6),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              offset: const Offset(0, 10),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(icon, size: 100, color: color.withValues(alpha: 0.1)),
            ),
            Row(
              children: [
                Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, size: 60, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize + 8,
                          fontWeight: FontWeight.w900,
                          color: color,
                          fontFamily: _config['fontFamily'] as String?,
                        ),
                      ),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 50, color: color),
                const SizedBox(width: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
