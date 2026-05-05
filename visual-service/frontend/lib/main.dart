import 'package:flutter/material.dart';
import 'screens/spatial_awareness.dart';
import 'screens/sound_catcher.dart';
import 'screens/syllable_challenge.dart';
import 'screens/gamified_onboarding.dart';

void main() {
  runApp(const StudentApp());
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Dyslexia Platform - Student',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        fontFamily: 'Inter', // Fallback font, assuming Sinhala handles itself
      ),
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (context) => GamifiedOnboardingScreen(),
        '/': (context) => const StudentHomeScreen(),
      },
    );
  }
}

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text("මගේ ක්‍රීඩා (My Games)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "ක්‍රීඩාවක් තෝරන්න",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 40),
              
              _buildStageButton(
                context, 
                "Stage 1: Where is the Lion?", 
                "Spatial & Directional", 
                Colors.orangeAccent, 
                Icons.games, 
                SpatialAwarenessGame()
              ),
              const SizedBox(height: 20),
              
              _buildStageButton(
                context, 
                "Stage 2: Sound Catcher", 
                "Phoneme Isolation", 
                Colors.blueAccent, 
                Icons.hearing, 
                SoundCatcherGame()
              ),
              const SizedBox(height: 20),
              
              _buildStageButton(
                context, 
                "Stage 3: Hear & Tap", 
                "Grapheme-Phoneme Mapping", 
                Colors.purpleAccent, 
                Icons.touch_app, 
                SyllableChallengeGame()
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageButton(BuildContext context, String title, String subtitle, Color color, IconData icon, Widget targetScreen) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: color.withOpacity(0.3), width: 2),
        ),
        elevation: 2,
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen));
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.black54)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
