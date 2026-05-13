import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'word_matching_task.dart';
import 'word_matching_avli_screen.dart';
import 'letter_puzzle_game.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'R26-SE-031 Research Demo',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.indigoAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Demo Navigation',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dyslexia Research System',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.home_rounded,
              title: 'Dashboard',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.image_search_rounded,
              title: 'Word Matching Task',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WordMatchingTask()));
              },
            ),
            _buildDrawerItem(
              icon: Icons.compare_arrows_rounded,
              title: 'AVLI Evaluation',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WordMatchingAVLIScreen()));
              },
            ),
            _buildDrawerItem(
              icon: Icons.extension_rounded,
              title: 'Letter Puzzle Game',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: LetterPuzzleGame(onComplete: () => Navigator.pop(context)),
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _buildDrawerItem(
              icon: Icons.settings_input_component_rounded,
              title: 'System Settings',
              onTap: () {},
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildSectionTitle('Cognitive Learning Tasks'),
            const SizedBox(height: 16),
            _buildActivityCard(
              context,
              title: 'Word Matching (Task)',
              description: 'Research task for Sinhala word-image association with real-time typography adaptation.',
              icon: Icons.image_search_rounded,
              color: Colors.blueAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WordMatchingTask()),
              ),
            ),
            const SizedBox(height: 16),
            _buildActivityCard(
              context,
              title: 'AVLI Matching (Evaluation)',
              description: 'Cross-linguistic Sinhala to English pairing for advanced pedagogical observation.',
              icon: Icons.compare_arrows_rounded,
              color: Colors.indigoAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WordMatchingAVLIScreen()),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Gamified Recovery'),
            const SizedBox(height: 16),
            _buildActivityCard(
              context,
              title: 'Letter Puzzle Game',
              description: 'Engagement recovery mini-game designed to reduce cognitive load and visual strain.',
              icon: Icons.extension_rounded,
              color: Colors.orangeAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: LetterPuzzleGame(onComplete: () => Navigator.pop(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to the Demo Dashboard',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a module to begin the research session. All interactions are monitored by C1 and C2 microservices.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black45,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black12, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }
}
