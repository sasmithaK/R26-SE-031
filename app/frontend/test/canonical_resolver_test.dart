import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/models/curriculum_models.dart';

void main() {
  group('CanonicalItemResolver Tests', () {
    test('Resolves MCQ template correctly', () {
      final act = ActivityNode(
        id: 'a1',
        title: 'test',
        telemetryTags: [],
        templateType: 'skill2_mcq',
        rounds: [],
      );

      final roundData = {
        'options': ['A', 'B', 'C'],
        'correctOption': 'B',
        'item_id': 'S2_A1_R01',
        'difficulty_b': 1.0,
        'is_anchor': true
      };

      final resolved = CanonicalItemResolver.resolve(act, roundData, 0);

      expect(resolved.itemId, 'S2_A1_R01');
      expect(resolved.difficultyB, 1.0);
      expect(resolved.isAnchor, true);
      expect(resolved.targets.length, 1);
      expect(resolved.targets.first, 'B');
      expect(resolved.distractors.length, 2);
      expect(resolved.distractors.contains('A'), true);
      expect(resolved.distractors.contains('C'), true);
      expect(resolved.distractors.contains('B'), false);
    });

    test('Resolves Hidden Search template correctly', () {
      final act = ActivityNode(
        id: 'a1',
        title: 'test',
        telemetryTags: [],
        templateType: 'visual_hidden_search',
        rounds: [],
      );

      final roundData = {
        'targets': ['Apple', 'Banana'],
        'distractors': ['Carrot', 'Dog'],
      };

      final resolved = CanonicalItemResolver.resolve(act, roundData, 0);

      expect(resolved.itemId, 'a1_R1'); // fallback
      expect(resolved.targets.length, 2);
      expect(resolved.distractors.length, 2);
    });
  });
}
