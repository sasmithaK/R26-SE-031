import 'package:flutter/material.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final int colorIndex = args != null && args['preferredColorIndex'] is int ? args['preferredColorIndex'] as int : 0;
    final double fontSize = args != null && args['preferredFontSize'] is double ? args['preferredFontSize'] as double : 20.0;

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
    final accent = palette[(colorIndex.clamp(0, palette.length - 1))]['accent']!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, accent.withValues(alpha: 0.2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('මගේ වැඩ', style: TextStyle(fontSize: fontSize + 12, fontWeight: FontWeight.w900)),
          backgroundColor: Colors.transparent,
          foregroundColor: accent.computeLuminance() > 0.5 ? Colors.brown.shade900 : Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 6),
                        boxShadow: [
                          BoxShadow(color: accent.withValues(alpha: 0.4), offset: const Offset(0, 8), blurRadius: 0),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/student_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.child_care, size: 50),
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
                            Shadow(color: Colors.white, blurRadius: 5, offset: Offset(2, 2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: ListView(
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
