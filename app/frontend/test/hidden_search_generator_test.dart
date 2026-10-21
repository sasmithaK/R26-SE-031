import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/screens/games/skill_1/logic/hidden_search_generator.dart';

void main() {
  test('hidden search uses curriculum rounds and stable semantic IDs', () {
    final game = HiddenSearchGenerator.generateFromCurriculum([
      {
        'targets': ['animals/dog.png'],
        'target_count': 2,
        'distractors': ['animals/cat.png', 'animals/cow.png'],
        'instruction': 'බල්ලා සොයන්න!',
      },
    ]);

    expect(game.rounds, hasLength(1));
    expect(game.rounds.single.items, hasLength(4));
    expect(
      game.rounds.single.items
          .where((item) => item.isTarget)
          .map((item) => item.id),
      containsAll(<String>['T1', 'T2']),
    );
    expect(
      game.rounds.single.items
          .where((item) => !item.isTarget)
          .map((item) => item.id),
      containsAll(<String>['D1', 'D2']),
    );
  });

  test('Skill 1 Activity 1 curriculum supplies all five tracked tasks', () {
    final decoded = jsonDecode(
      File('assets/data/curriculum/skill_1.json').readAsStringSync(),
    ) as List<dynamic>;
    final skill = decoded.single as Map<String, dynamic>;
    final activities = skill['activities'] as List<dynamic>;
    final activity = activities.firstWhere(
      (entry) => (entry as Map<String, dynamic>)['id'] == 'act_1',
    ) as Map<String, dynamic>;
    final rounds = (activity['rounds'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    final game = HiddenSearchGenerator.generateFromCurriculum(rounds);

    expect(game.rounds, hasLength(5));
    expect(
      game.rounds.map((round) => round.items.length),
      orderedEquals(<int>[4, 7, 9, 12, 15]),
    );
  });
}
