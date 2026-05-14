import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

// ── UCSC-validated high-confusion letter set (De Silva et al. 2025) ────────
// Selected through preliminary study with real Sinhala dyslexic primary students.
// Each target is paired with its empirically observed confusable letters.
// Reference: De Silva, D.G.D.H. et al. (2025) UCSC BSc FYP.
const Map<String, List<String>> _kUcscConfusion = {
  'ග': ['ල', 'ය'],   // Ga — confused with La, Ya
  'ල': ['ළ', 'ය'],   // La — confused with La-dot (ළ), Ya
  'ය': ['ග', 'ල'],   // Ya — confused with Ga, La
  'ට': ['ත', 'ද'],   // Ta — confused with Tha, Da
  'ක': ['ග', 'ඒ'],   // Ka — confused with Ga, E-vowel
  'ප': ['බ', 'ඵ'],   // Pa — confused with Ba, Pha
};

const List<String> _kUcscTargets = ['ග', 'ල', 'ය', 'ට', 'ක', 'ප'];

// Extra distractor pool (letters not in the UCSC confusion pairs above)
const List<String> _kDistractorPool = [
  'ච', 'ජ', 'ඩ', 'ණ', 'ත', 'ද', 'ධ', 'න', 'ම', 'ව', 'ස', 'හ', 'ළ',
];

class LetterPuzzleGame extends StatefulWidget {
  final VoidCallback onComplete;
  final int difficulty; // 1–5 from C2 game_difficulty

  const LetterPuzzleGame({
    super.key,
    required this.onComplete,
    this.difficulty = 2,
  });

  @override
  State<LetterPuzzleGame> createState() => _LetterPuzzleGameState();
}

class _LetterPuzzleGameState extends State<LetterPuzzleGame>
    with SingleTickerProviderStateMixin {
  late String _targetLetter;
  late List<String> _tiles;
  String? _selectedLetter;
  bool? _isCorrect;
  int _round = 1;
  int _correctCount = 0;
  late AnimationController _shakeController;

  // Total rounds scales with difficulty (UCSC: more rounds = more practice)
  int get _totalRounds => 3 + widget.difficulty;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _newRound();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _newRound() {
    final rng = Random();

    // Pick a random UCSC target letter
    _targetLetter = _kUcscTargets[rng.nextInt(_kUcscTargets.length)];

    // Tile count increases with difficulty: 4 (d1) → 8 (d5)
    final tileCount = (3 + widget.difficulty).clamp(4, 8);

    // Always include: target + its 2 known confusables
    final confusables = List<String>.from(_kUcscConfusion[_targetLetter]!);

    // Fill remaining slots with random distractors not already in the set
    final used = {_targetLetter, ...confusables};
    final distractors = _kDistractorPool
        .where((l) => !used.contains(l))
        .toList()
      ..shuffle(rng);

    final tiles = [_targetLetter, ...confusables];
    for (final d in distractors) {
      if (tiles.length >= tileCount) break;
      tiles.add(d);
    }
    tiles.shuffle(rng);

    setState(() {
      _tiles = tiles;
      _selectedLetter = null;
      _isCorrect = null;
    });
  }

  void _handleSelect(String letter) {
    if (_isCorrect == true) return;
    final correct = letter == _targetLetter;
    setState(() {
      _selectedLetter = letter;
      _isCorrect = correct;
    });

    if (correct) {
      _correctCount++;
      if (_round < _totalRounds) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() => _round++);
          _newRound();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 900), widget.onComplete);
      }
    } else {
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = _round > 1
        ? (_correctCount / (_round - 1) * 100).toStringAsFixed(0)
        : '–';

    return Container(
      color: Colors.black.withOpacity(0.93),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.extension_rounded,
                    size: 36, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Text(
                  'Letter Recognition',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // UCSC badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '📚 De Silva et al. (2025) · UCSC confusion pairs',
                style: GoogleFonts.inconsolata(
                    fontSize: 10, color: Colors.orange.shade200),
              ),
            ),
            const SizedBox(height: 24),

            // Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Round $_round / $_totalRounds',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: Colors.white54)),
                const SizedBox(width: 20),
                Text('Accuracy: $accuracy%',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: Colors.greenAccent.shade200)),
                const SizedBox(width: 20),
                Text('Difficulty: ${widget.difficulty}/5',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: Colors.amber.shade300)),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 260,
              child: LinearProgressIndicator(
                value: (_round - 1) / _totalRounds,
                backgroundColor: Colors.white12,
                color: Colors.orangeAccent,
                minHeight: 3,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 28),

            // Instruction
            Text(
              'අකුර තෝරන්න',
              style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Find the letter: $_targetLetter',
              style: GoogleFonts.outfit(fontSize: 18, color: Colors.white70),
            ),
            // Confusable hint (shown after wrong attempt)
            if (_isCorrect == false)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Hint: look carefully at letters similar to "$_targetLetter"',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: Colors.amber.shade300),
                ),
              ),
            const SizedBox(height: 36),

            // Tiles
            AnimatedBuilder(
              animation: _shakeController,
              builder: (_, child) {
                final shake =
                    sin(_shakeController.value * pi * 6) * 6;
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: child,
                );
              },
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _tiles.map((l) => _buildTile(l)).toList(),
              ),
            ),

            if (_isCorrect == true) ...[
              const SizedBox(height: 28),
              Text(
                _round < _totalRounds ? '✅ Correct! Next...' : '🎉 Well done!',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold),
              ),
            ] else if (_isCorrect == false) ...[
              const SizedBox(height: 28),
              Text(
                'නැවත උත්සාහ කරන්න  (Try again!)',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTile(String letter) {
    final isSelected = _selectedLetter == letter;
    final isTarget = letter == _targetLetter;
    final confusables = _kUcscConfusion[_targetLetter] ?? [];
    final isConfusable = confusables.contains(letter);

    Color borderColor = Colors.white24;
    if (isSelected) {
      borderColor = _isCorrect == true ? Colors.greenAccent : Colors.redAccent;
    } else if (_isCorrect == true && isTarget) {
      borderColor = Colors.greenAccent;
    }

    // Subtle confusable indicator only after wrong attempt
    Color bgColor = Colors.white.withOpacity(0.05);
    if (isSelected && _isCorrect == false && isConfusable) {
      bgColor = Colors.amber.withOpacity(0.08);
    }

    return GestureDetector(
      onTap: () => _handleSelect(letter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: isSelected
              ? borderColor.withOpacity(0.12)
              : bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: isSelected
              ? [BoxShadow(color: borderColor.withOpacity(0.3), blurRadius: 12)]
              : [],
        ),
        child: Center(
          child: Text(
            letter,
            style: GoogleFonts.notoSansSinhala(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: isSelected ? borderColor : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
