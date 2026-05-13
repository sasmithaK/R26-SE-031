import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameModeOverlay extends StatelessWidget {
  final VoidCallback onComplete;

  const GameModeOverlay({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videogame_asset, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              "ENGAGEMENT RECOVERY MODE",
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text(
              "Complete this quick puzzle to continue!",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            // Placeholder for a mini-game
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   _buildPuzzleChar("ක"),
                   const SizedBox(width: 20),
                   const Icon(Icons.arrow_forward, color: Colors.white38),
                   const SizedBox(width: 20),
                   _buildPuzzleChar("?"),
                ],
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              ),
              child: const Text("MATCH & CONTINUE"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleChar(String char) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          char,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
