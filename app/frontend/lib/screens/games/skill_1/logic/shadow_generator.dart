import 'dart:math';
import '../models/shadow_round.dart';

/// Generates 5 randomized shadow matching rounds with progressive difficulty.
class ShadowGenerator {
  static final Random _rng = Random();

  // ── Asset definitions ──
  // We use visually distinct shapes to avoid ambiguity.
  static const List<String> _distinctAssets = [
    'animals/bird.png',
    'animals/butterfly.png',
    'animals/cat.png',
    'animals/cow.png',
    'animals/dog.png',
    'animals/elephant.png',
    'animals/fish.png',
    'animals/frog.png',
    'animals/rabbit.png',
    'animals/snail.png',
    'animals/turtle.png',
    'flowers/nil_manel.png',
    'flowers/nelum.png',
    'flowers/araliya.png',
    'flowers/wada_mal.png',
    'flowers/flower_05.png',
    'fruits_food/apple.png',
    'fruits_food/banana.png',
    'fruits_food/grapes.png',
    'fruits_food/ice_cream.png',
    'fruits_food/mango.png',
    'fruits_food/orange.png',
    'fruits_food/watermelon.png',
    'vehicles/airplane.png',
    'vehicles/bicycle.png',
    'vehicles/boat.png',
    'vehicles/train.png',
    'vehicles/van.png',
  ];

  /// Generates 5 progressive shadow matching rounds.
  static List<ShadowRound> generateRounds() {
    final rounds = <ShadowRound>[];
    
    // Level 1: Very Easy - 2 shadows, 2 objects (visually very different)
    rounds.add(_buildRound(count: 2, difficulty: 1));
    
    // Level 2: Easy - 3 shadows, 3 objects
    rounds.add(_buildRound(count: 3, difficulty: 2));
    
    // Level 3: Medium - 4 shadows, 4 objects
    rounds.add(_buildRound(count: 4, difficulty: 3));
    
    // Level 4: Hard - 5 shadows, 5 objects
    rounds.add(_buildRound(count: 5, difficulty: 4));
    
    // Level 5: Challenge - 6 shadows, 6 objects
    rounds.add(_buildRound(count: 6, difficulty: 5));

    return rounds;
  }

  static ShadowRound _buildRound({required int count, required int difficulty}) {
    // Shuffle the available distinct assets to ensure fresh gameplay
    final available = List<String>.from(_distinctAssets)..shuffle(_rng);
    
    // Take exactly [count] items
    final selected = available.take(count).toList();
    
    return ShadowRound(
      targetAssets: selected,
      difficulty: difficulty,
    );
  }
}
