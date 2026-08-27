import 'dart:math';

class HiddenSearchItem {
  final String id;
  final String imagePath;
  final bool isTarget;
  final bool isFlipped;
  final double? colorHue; // If null, original color. If double, applies a hue shift.

  HiddenSearchItem({
    required this.id,
    required this.imagePath,
    required this.isTarget,
    this.isFlipped = false,
    this.colorHue,
  });
}

class HiddenSearchRound {
  final String targetPath;
  final String targetSingular;
  final String targetPlural;
  final int targetCount;
  final List<HiddenSearchItem> items;

  HiddenSearchRound({
    required this.targetPath,
    required this.targetSingular,
    required this.targetPlural,
    required this.targetCount,
    required this.items,
  });

  String get instructionText {
    if (targetCount == 1) {
      return '$targetSingular සොයන්න!';
    } else {
      return '$targetPlural $targetCount ක් සොයන්න!';
    }
  }
}

class HiddenSearchGameData {
  final List<HiddenSearchRound> rounds;
  HiddenSearchGameData({required this.rounds});
}

class HiddenSearchGenerator {
  static final _random = Random();

  // Full asset dictionary with singular and plural Sinhala names
  static const Map<String, Map<String, String>> _assetDictionary = {
    'vehicles/van.png': {'singular': 'වෑන් රථය', 'plural': 'වෑන් රථ'},
    'vehicles/train.png': {'singular': 'දුම්රිය', 'plural': 'දුම්රිය'},
    'vehicles/airplane.png': {'singular': 'ගුවන් යානය', 'plural': 'ගුවන් යානා'},
    'vehicles/bicycle.png': {'singular': 'බයිසිකලය', 'plural': 'බයිසිකල්'},
    'vehicles/boat.png': {'singular': 'බෝට්ටුව', 'plural': 'බෝට්ටු'},
    'everyday_objects/shoe.png': {'singular': 'සපත්තුව', 'plural': 'සපත්තු'},
    'everyday_objects/key.png': {'singular': 'යතුර', 'plural': 'යතුරු'},
    'everyday_objects/clock.png': {'singular': 'ඔරලෝසුව', 'plural': 'ඔරලෝසු'},
    'everyday_objects/balloon.png': {'singular': 'බැලුනය', 'plural': 'බැලුන්'},
    'everyday_objects/bell.png': {'singular': 'සීනුව', 'plural': 'සීනු'},
    'everyday_objects/book.png': {'singular': 'පොත', 'plural': 'පොත්'},
  };

  static HiddenSearchGameData generateGame() {
    final List<String> allPaths = _assetDictionary.keys.toList()..shuffle(_random);
    final List<String> targetPaths = allPaths.take(5).toList();
    
    // Only these objects are simple enough to be used as targets in the colored-distractor tasks (rounds 4 and 5)
    final List<String> safeLastTaskPaths = [
      'everyday_objects/bell.png',
      'vehicles/van.png',
      'vehicles/train.png',
      'everyday_objects/clock.png',
      'everyday_objects/key.png',
      'everyday_objects/book.png',
      'vehicles/airplane.png',
    ];

    for (int i = 3; i < 5; i++) {
      if (!safeLastTaskPaths.contains(targetPaths[i])) {
        // Find a safe path from the remaining unused paths (or from the first 3 rounds if necessary)
        bool swapped = false;
        
        // Try to swap with something in the first 3 rounds
        for (int j = 0; j < 3; j++) {
          if (safeLastTaskPaths.contains(targetPaths[j])) {
            final temp = targetPaths[i];
            targetPaths[i] = targetPaths[j];
            targetPaths[j] = temp;
            swapped = true;
            break;
          }
        }
        
        // If couldn't swap internally, grab from unused paths
        if (!swapped) {
          final unusedSafePaths = safeLastTaskPaths.where((p) => !targetPaths.contains(p)).toList()..shuffle(_random);
          if (unusedSafePaths.isNotEmpty) {
            targetPaths[i] = unusedSafePaths.first;
          }
        }
      }
    }
    
    final List<HiddenSearchRound> rounds = [];

    for (int i = 0; i < 5; i++) {
      final targetPath = targetPaths[i];
      final targetInfo = _assetDictionary[targetPath]!;
      
      // Progressive difficulty
      int targetCount;
      int distractorCount;
      bool allowFlips;
      bool allowColors;

      switch (i) {
        case 0:
          targetCount = 1; distractorCount = 3; allowFlips = false; allowColors = false; break;
        case 1:
          targetCount = 2; distractorCount = 4; allowFlips = false; allowColors = false; break;
        case 2:
          targetCount = 3; distractorCount = 5; allowFlips = true; allowColors = false; break;
        case 3:
          targetCount = 3; distractorCount = 9; allowFlips = true; allowColors = true; break;
        case 4:
        default:
          targetCount = 4; distractorCount = 11; allowFlips = true; allowColors = true; break;
      }

      final List<HiddenSearchItem> items = [];

      // Add target items
      for (int t = 0; t < targetCount; t++) {
        items.add(HiddenSearchItem(
          id: 'target_${i}_$t',
          imagePath: targetPath,
          isTarget: true,
          isFlipped: false, // TARGETS MUST MATCH INSTRUCTION IMAGE EXACTLY
          colorHue: null,
        ));
      }

      // Prepare distractors
      final List<String> availableDistractorPaths = allPaths.where((p) => p != targetPath).toList();
      
      for (int d = 0; d < distractorCount; d++) {
        // Tricky variants are distractors that use the EXACT SAME image as the target.
        // To avoid impossible situations with symmetrical objects (like bells or balloons)
        // looking identical when flipped, we ONLY allow tricky variants if we can change their color.
        bool isTrickyVariant = allowColors && _random.nextDouble() < 0.35; // 35% chance in hard rounds
        
        String dPath = isTrickyVariant ? targetPath : availableDistractorPaths[_random.nextInt(availableDistractorPaths.length)];
        
        double? dColorHue;
        bool dFlipped = false;
        
        if (isTrickyVariant) {
          // Use distinct hue rotation angles to guarantee a completely different color
          final distinctRotations = [90.0, 150.0, 180.0, 210.0, 270.0];
          dColorHue = distinctRotations[_random.nextInt(distinctRotations.length)];
          dFlipped = allowFlips ? _random.nextBool() : false;
        } else {
          // Normal distractor (different object altogether)
          dFlipped = allowFlips ? _random.nextBool() : false;
          // Optionally color shift normal distractors if allowed
          if (allowColors && _random.nextDouble() < 0.3) {
            dColorHue = 90.0 + _random.nextDouble() * 180.0; // Random rotation between 90 and 270 degrees
          }
        }

        items.add(HiddenSearchItem(
          id: 'distractor_${i}_$d',
          imagePath: dPath,
          isTarget: false,
          isFlipped: dFlipped,
          colorHue: dColorHue,
        ));
      }

      items.shuffle(_random);

      rounds.add(HiddenSearchRound(
        targetPath: targetPath,
        targetSingular: targetInfo['singular']!,
        targetPlural: targetInfo['plural']!,
        targetCount: targetCount,
        items: items,
      ));
    }

    return HiddenSearchGameData(rounds: rounds);
  }
}