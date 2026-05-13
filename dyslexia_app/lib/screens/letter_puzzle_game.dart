import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LetterPuzzleGame extends StatefulWidget {
  final VoidCallback onComplete;

  const LetterPuzzleGame({super.key, required this.onComplete});

  @override
  State<LetterPuzzleGame> createState() => _LetterPuzzleGameState();
}

class _LetterPuzzleGameState extends State<LetterPuzzleGame> {
  final List<String> letters = ['ක', 'ග', 'ච', 'ට', 'ප'];
  String? targetLetter;
  String? selectedLetter;
  bool? isCorrect;

  @override
  void initState() {
    super.initState();
    letters.shuffle();
    targetLetter = letters[0];
    letters.shuffle();
  }

  void _handleSelect(String letter) {
    if (isCorrect == true) return;
    setState(() {
      selectedLetter = letter;
      isCorrect = letter == targetLetter;
    });

    if (isCorrect == true) {
      Future.delayed(const Duration(milliseconds: 1000), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.extension_rounded, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              "අකුර තෝරන්න (Select the letter)",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Find the letter: $targetLetter",
              style: GoogleFonts.outfit(fontSize: 20, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: letters.map((l) => _buildLetterCard(l)).toList(),
            ),
            if (isCorrect == false) ...[
              const SizedBox(height: 32),
              Text(
                "නැවත උත්සාහ කරන්න (Try again!)",
                style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLetterCard(String letter) {
    bool isSelected = selectedLetter == letter;
    Color borderColor = Colors.white24;
    if (isSelected) {
      borderColor = isCorrect == true ? Colors.green : Colors.red;
    }

    return GestureDetector(
      onTap: () => _handleSelect(letter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? borderColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: Text(
            letter,
            style: GoogleFonts.notoSansSinhala(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isSelected ? borderColor : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
