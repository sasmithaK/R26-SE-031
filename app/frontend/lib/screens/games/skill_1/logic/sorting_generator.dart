import 'dart:math';
import '../models/sorting_round.dart';

/// Generates 5 randomized sorting rounds with progressive difficulty.
class SortingGenerator {
  static final Random _rng = Random();

  // ── Category definitions using real asset paths ──

  static const Map<String, List<String>> _categoryAssets = {
    'animals': [
      'animals/fish.png',
      'animals/rabbit.png',
      'animals/dog.png',
      'animals/bird.png',
      'animals/cat.png',
      'animals/butterfly.png',
      'animals/cow.png',
      'animals/elephant.png',
      'animals/frog.png',
      'animals/snail.png',
      'animals/turtle.png',
    ],
    'fruits': [
      'fruits_food/apple.png',
      'fruits_food/banana.png',
      'fruits_food/grapes.png',
      'fruits_food/mango.png',
      'fruits_food/orange.png',
      'fruits_food/watermelon.png',
    ],
    'vehicles': [
      'vehicles/airplane.png',
      'vehicles/bicycle.png',
      'vehicles/boat.png',
      'vehicles/train.png',
      'vehicles/van.png',
    ],
    'flowers': [
      'flowers/nil_manel.png',
      'flowers/nelum.png',
      'flowers/araliya.png',
      'flowers/wada_mal.png',
      'flowers/flower_05.png',
    ],
  };

  static const Map<String, String> _categoryLabels = {
    'animals': 'සතුන්',
    'fruits': 'පලතුරු',
    'vehicles': 'වාහන',
    'flowers': 'මල්',
  };

  static const Map<String, String> _categoryIcons = {
    'animals': 'animals/elephant.png',
    'fruits': 'fruits_food/apple.png',
    'vehicles': 'vehicles/van.png',
    'flowers': 'flowers/nelum.png',
  };

  /// Generates 5 progressive sorting rounds.
  static List<SortingRound> generateRounds() {
    // We have 5 categories with enough items. Pick combinations for each round.
    // Shuffle the category pool to keep things fresh each session.
    final allCategoryKeys = _categoryAssets.keys.toList();

    // Ensure we always have usable combinations by picking from shuffled pool:
    // Round 1: 2 categories, 4 objects (2 each)
    // Round 2: 2 categories, 6 objects (3 each)
    // Round 3: 3 categories, 6 objects (2 each)
    // Round 4: 3 categories, 9 objects (3 each)
    // Round 5: 3 categories, 10 objects (3-4 each)

    final rounds = <SortingRound>[];

    // Pick categories for rounds — rotate through shuffled pool
    // Round 1: 2 categories, 3 objects total (2 for first, 1 for second)
    // Round 2: 2 categories, 4 objects total (2 each)
    // Round 3: 2 categories, 6 objects total (3 each)
    // Round 4: 3 categories, 6 objects total (2 each)
    // Round 5: 3 categories, 9 objects total (3 each)
    
    final r1Cats = _pickCategories(allCategoryKeys, 2, exclude: []);
    final r2Cats = _pickCategories(allCategoryKeys, 2, exclude: r1Cats);
    final r3Cats = _pickCategories(allCategoryKeys, 2, exclude: r2Cats);
    final r4Cats = _pickCategories(allCategoryKeys, 3, exclude: []);
    final r5Cats = _pickCategories(allCategoryKeys, 3, exclude: r4Cats.isNotEmpty ? [r4Cats[0]] : []);

    rounds.add(_buildRound(r1Cats, objectsPerCategory: [2, 1], difficulty: 1));
    rounds.add(_buildRound(r2Cats, objectsPerCategory: 2, difficulty: 2));
    rounds.add(_buildRound(r3Cats, objectsPerCategory: 3, difficulty: 3));
    rounds.add(_buildRound(r4Cats, objectsPerCategory: 2, difficulty: 4));
    rounds.add(_buildRound(r5Cats, objectsPerCategory: 3, difficulty: 5));

    return rounds;
  }

  /// Pick [count] categories, trying to exclude [exclude] for variety.
  static List<String> _pickCategories(
    List<String> pool,
    int count, {
    List<String> exclude = const [],
  }) {
    // Prefer categories not in exclude list
    final preferred = pool.where((c) => !exclude.contains(c)).toList();
    final fallback = pool.where((c) => exclude.contains(c)).toList();

    final result = <String>[];
    for (final c in preferred) {
      if (result.length >= count) break;
      result.add(c);
    }
    // Fill remaining from fallback if needed
    for (final c in fallback) {
      if (result.length >= count) break;
      if (!result.contains(c)) result.add(c);
    }
    return result;
  }

  /// Build a round from selected categories.
  /// [objectsPerCategory] can be int (uniform) or List<int> (per-category).
  static SortingRound _buildRound(
    List<String> categoryKeys, {
    dynamic objectsPerCategory = 2,
    required int difficulty,
  }) {
    final categories = <String, List<String>>{};
    final categoryIcons = <String, String>{};
    final categoryLabels = <String, String>{};
    final allObjects = <String>[];
    final objectToCategory = <String, String>{};

    for (int i = 0; i < categoryKeys.length; i++) {
      final key = categoryKeys[i];
      final available = List<String>.from(_categoryAssets[key]!);

      int count;
      if (objectsPerCategory is List<int>) {
        count = i < objectsPerCategory.length ? objectsPerCategory[i] : 2;
      } else {
        count = objectsPerCategory as int;
      }

      // Take up to [count] items from the shuffled available list
      final selected = available.take(count.clamp(1, available.length)).toList();
      categories[key] = selected;
      categoryIcons[key] = _categoryIcons[key]!;
      categoryLabels[key] = _categoryLabels[key]!;

      for (final obj in selected) {
        allObjects.add(obj);
        objectToCategory[obj] = key;
      }
    }

    allObjects.shuffle(_rng);

    return SortingRound(
      categories: categories,
      categoryIcons: categoryIcons,
      categoryLabels: categoryLabels,
      objects: allObjects,
      objectToCategory: objectToCategory,
      difficulty: difficulty,
    );
  }
}
