import 'dart:math';
import '../models/pattern_round.dart';

class PatternGenerator {
  static const List<String> allAssets = [
    'fruits_food/mango.png',
    'fruits_food/watermelon.png',
    'fruits_food/orange.png',
    'fruits_food/grapes.png',
    'fruits_food/apple.png',
    'fruits_food/ice_cream.png',
    'fruits_food/banana.png',
    'everyday_objects/spoon.png',
    'everyday_objects/flag.png',
    'everyday_objects/bell.png',
    'everyday_objects/hat.png',
    'everyday_objects/book.png',
    'everyday_objects/key.png',
    'everyday_objects/candle.png',
    'everyday_objects/umbrella.png',
    'everyday_objects/shoe.png',
    'everyday_objects/comb.png',
    'everyday_objects/balloon.png',
    'everyday_objects/chair.png',
    'everyday_objects/clock.png',
    'everyday_objects/pencil.png',
    'everyday_objects/cylinder.png',
    'everyday_objects/necklace.png',
    'everyday_objects/teacup.png',
    'everyday_objects/bucket.png',
    'everyday_objects/kite.png',
    'everyday_objects/oil_lamp.png',
    'flowers/nil_manel.png',
    'flowers/nelum.png',
    'flowers/flower_05.png',
    'animals/dog.png',
    'animals/rabbit.png',
    'animals/turtle.png',
    'animals/elephant.png',
    'animals/bird.png',
    'animals/cow.png',
    'animals/butterfly.png',
    'animals/cat.png',
    'animals/frog.png',
    'animals/fish.png',
    'animals/snail.png',
    'vehicles/boat.png',
    'vehicles/train.png',
    'vehicles/van.png',
    'vehicles/airplane.png',
    'vehicles/bicycle.png',
  ];

  static List<PatternRound> generateRounds() {
    final rng = Random();
    
    // We shuffle the allAssets list and pick distinct items for each round
    // to ensure variety across rounds.
    
    return [
      _generateRound1(rng),
      _generateRound2(rng),
      _generateRound3(rng),
      _generateRound4(rng),
      _generateRound5(rng),
    ];
  }

  static PatternRound _generateRound1(Random rng) {
    // Round 1 (Very Easy): A B A ? (2 choices)
    final assets = List<String>.from(allAssets);
    final A = assets[0];
    final B = assets[1];
    
    List<String?> sequence = [A, B, A, null]; // length 4
    final correctAnswer = B;
    
    final distractors = [assets[2]]; // Only 1 distractor for 2 total choices
    List<String> options = [correctAnswer, ...distractors]..shuffle(rng);
    
    return PatternRound(
      sequence: sequence,
      missingIndex: 3,
      correctAnswer: correctAnswer,
      options: options,
      difficulty: 1,
    );
  }

  static PatternRound _generateRound2(Random rng) {
    // Round 2 (Easy): A A B ? (3 choices)
    final assets = List<String>.from(allAssets);
    final A = assets[0];
    final B = assets[1];
    
    List<String?> sequence = [A, A, B, null]; // length 4
    final correctAnswer = B; // Pattern: A A B B
    
    final distractors = [assets[2], assets[3]];
    List<String> options = [correctAnswer, ...distractors]..shuffle(rng);
    
    return PatternRound(
      sequence: sequence,
      missingIndex: 3,
      correctAnswer: correctAnswer,
      options: options,
      difficulty: 2,
    );
  }

  static PatternRound _generateRound3(Random rng) {
    // Round 3 (Medium): A B C A ? (3 choices)
    final assets = List<String>.from(allAssets);
    final A = assets[0];
    final B = assets[1];
    final C = assets[2];
    
    List<String?> sequence = [A, B, C, A, null]; // Length 5
    final correctAnswer = B;
    
    final distractors = [assets[3], assets[4]];
    List<String> options = [correctAnswer, ...distractors]..shuffle(rng);
    
    return PatternRound(
      sequence: sequence,
      missingIndex: 4,
      correctAnswer: correctAnswer,
      options: options,
      difficulty: 3,
    );
  }

  static PatternRound _generateRound4(Random rng) {
    // Round 4 (Hard): A B C D A ? (4 choices)
    final assets = List<String>.from(allAssets);
    final A = assets[0];
    final B = assets[1];
    final C = assets[2];
    final D = assets[3];
    
    List<String?> sequence = [A, B, C, D, A, null]; // Length 6
    final correctAnswer = B; // since A B C D A B
    
    final distractors = [assets[4], assets[5], assets[6]];
    List<String> options = [correctAnswer, ...distractors]..shuffle(rng);
    
    return PatternRound(
      sequence: sequence,
      missingIndex: 5,
      correctAnswer: correctAnswer,
      options: options,
      difficulty: 4,
    );
  }

  static PatternRound _generateRound5(Random rng) {
    // Round 5 (Challenge): A B B C A B ? (4 choices)
    final assets = List<String>.from(allAssets);
    final A = assets[0];
    final B = assets[1];
    final C = assets[2];
    
    // Pattern: A B B C | A B B C
    List<String?> sequence = [A, B, B, C, A, B, null]; // Length 7
    final correctAnswer = B;
    
    final distractors = [assets[3], assets[4], assets[5]];
    List<String> options = [correctAnswer, ...distractors]..shuffle(rng);
    
    return PatternRound(
      sequence: sequence,
      missingIndex: 6,
      correctAnswer: correctAnswer,
      options: options,
      difficulty: 5,
    );
  }
}
