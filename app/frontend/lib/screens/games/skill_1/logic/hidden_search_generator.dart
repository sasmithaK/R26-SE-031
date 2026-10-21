import 'dart:math';

class HiddenSearchItem {
  final String id;
  final String imagePath;
  final bool isTarget;
  final bool isFlipped;
  final double?
  colorHue; // If null, original color. If double, applies a hue shift.

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
  final String? instruction;

  HiddenSearchRound({
    required this.targetPath,
    required this.targetSingular,
    required this.targetPlural,
    required this.targetCount,
    required this.items,
    this.instruction,
  });

  String get instructionText {
    if (instruction != null && instruction!.trim().isNotEmpty) {
      return instruction!;
    }
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

  static HiddenSearchGameData generateGame({int seed = 20261006}) {
    final random = Random(seed);
    final List<String> allPaths = _assetDictionary.keys.toList();
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
          final unusedSafePaths = safeLastTaskPaths
              .where((p) => !targetPaths.contains(p))
              .toList();
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
          targetCount = 1;
          distractorCount = 3;
          allowFlips = false;
          allowColors = false;
          break;
        case 1:
          targetCount = 2;
          distractorCount = 4;
          allowFlips = false;
          allowColors = false;
          break;
        case 2:
          targetCount = 3;
          distractorCount = 5;
          allowFlips = true;
          allowColors = false;
          break;
        case 3:
          targetCount = 3;
          distractorCount = 9;
          allowFlips = true;
          allowColors = true;
          break;
        case 4:
        default:
          targetCount = 4;
          distractorCount = 11;
          allowFlips = true;
          allowColors = true;
          break;
      }

      final List<HiddenSearchItem> items = [];

      // Add target items
      for (int t = 0; t < targetCount; t++) {
        items.add(
          HiddenSearchItem(
            id: 'target_${i}_$t',
            imagePath: targetPath,
            isTarget: true,
            isFlipped: false, // TARGETS MUST MATCH INSTRUCTION IMAGE EXACTLY
            colorHue: null,
          ),
        );
      }

      // Prepare distractors
      final List<String> availableDistractorPaths = allPaths
          .where((p) => p != targetPath)
          .toList();

      for (int d = 0; d < distractorCount; d++) {
        // Tricky variants are distractors that use the EXACT SAME image as the target.
        // To avoid impossible situations with symmetrical objects (like bells or balloons)
        // looking identical when flipped, we ONLY allow tricky variants if we can change their color.
        bool isTrickyVariant =
            allowColors &&
            random.nextDouble() < 0.35; // 35% chance in hard rounds

        String dPath = isTrickyVariant
            ? targetPath
            : availableDistractorPaths[random.nextInt(
                availableDistractorPaths.length,
              )];

        double? dColorHue;
        bool dFlipped = false;

        if (isTrickyVariant) {
          // Use distinct hue rotation angles to guarantee a completely different color
          final distinctRotations = [90.0, 150.0, 180.0, 210.0, 270.0];
          dColorHue =
              distinctRotations[random.nextInt(distinctRotations.length)];
          dFlipped = allowFlips ? random.nextBool() : false;
        } else {
          // Normal distractor (different object altogether)
          dFlipped = allowFlips ? random.nextBool() : false;
          // Optionally color shift normal distractors if allowed
          if (allowColors && random.nextDouble() < 0.3) {
            dColorHue =
                90.0 +
                random.nextDouble() *
                    180.0; // Random rotation between 90 and 270 degrees
          }
        }

        items.add(
          HiddenSearchItem(
            id: 'distractor_${i}_$d',
            imagePath: dPath,
            isTarget: false,
            isFlipped: dFlipped,
            colorHue: dColorHue,
          ),
        );
      }

      items.shuffle(random);

      rounds.add(
        HiddenSearchRound(
          targetPath: targetPath,
          targetSingular: targetInfo['singular']!,
          targetPlural: targetInfo['plural']!,
          targetCount: targetCount,
          items: items,
        ),
      );
    }

    return HiddenSearchGameData(rounds: rounds);
  }

  /// Builds the playable task from the same curriculum records used by the
  /// research item bank. The visual order is shuffled deterministically while
  /// the semantic target/distractor IDs stay stable across screen positions.
  static HiddenSearchGameData generateFromCurriculum(
    List<Map<String, dynamic>> curriculumRounds, {
    int seed = 20261006,
  }) {
    final rounds = <HiddenSearchRound>[];
    for (
      var roundIndex = 0;
      roundIndex < curriculumRounds.length;
      roundIndex++
    ) {
      final data = curriculumRounds[roundIndex];
      final targets = _stringList(data['targets']);
      final distractors = _stringList(data['distractors']);
      if (targets.isEmpty) continue;

      final targetCount = (data['target_count'] as num?)?.toInt() ?? 1;
      final items = <HiddenSearchItem>[];
      for (var index = 0; index < targetCount; index++) {
        items.add(
          HiddenSearchItem(
            id: 'T${index + 1}',
            imagePath: targets[index % targets.length],
            isTarget: true,
          ),
        );
      }
      for (var index = 0; index < distractors.length; index++) {
        items.add(
          HiddenSearchItem(
            id: 'D${index + 1}',
            imagePath: distractors[index],
            isTarget: false,
          ),
        );
      }
      items.shuffle(Random(seed + roundIndex));

      final targetPath = targets.first;
      final targetInfo = _assetDictionary[targetPath];
      final fallbackInstruction = data['instruction']?.toString();
      rounds.add(
        HiddenSearchRound(
          targetPath: targetPath,
          targetSingular:
              targetInfo?['singular'] ?? fallbackInstruction ?? 'පින්තූරය',
          targetPlural:
              targetInfo?['plural'] ?? fallbackInstruction ?? 'පින්තූර',
          targetCount: targetCount,
          items: items,
          instruction: fallbackInstruction,
        ),
      );
    }
    return HiddenSearchGameData(rounds: rounds);
  }

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) return const <String>[];
    return value.map((item) => item.toString()).toList();
  }
}
