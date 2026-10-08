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
        'is_anchor': true,
      };

      final resolved = CanonicalItemResolver.resolve(act, roundData, 0);

      expect(resolved.itemId, 'S2A1R01');
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

      expect(resolved.itemId, 'S0A1R01'); // canonical fallback
      expect(resolved.targets.length, 2);
      expect(resolved.distractors.length, 2);
    });

    test(
      'reads nested content, research metadata, and variant information',
      () {
        final act = ActivityNode.fromJson({
          'id': 'act_2',
          'title': 'test',
          'template_type': 'skill3_image_mcq',
          'research_metadata': {
            'knowledge_component_id': 'KC_WORD_RECOGNITION',
            'prompt_modality': 'visual',
            'response_modality': 'tap',
            'research_role': 'primary',
          },
          'rounds': const [],
        })..skillId = 'skill_3';

        final resolved = CanonicalItemResolver.resolve(act, {
          'item_id': 'S3_A2_R4V1',
          'difficulty_b': -0.5,
          'equivalent_group_id': 'S3A2R04',
          'allowed_scaffolds': ['REMOVE_OPTION', 'HIGHLIGHT_OPTION'],
          'content': {
            'options': ['අ', 'ආ', 'ඇ'],
            'correct_option': 'ආ',
          },
        }, 3);

        expect(
          act.researchMetadata?.knowledgeComponentId,
          'KC_WORD_RECOGNITION',
        );
        expect(resolved.itemId, 'S3A2R04V1');
        expect(resolved.targets, ['ආ']);
        expect(resolved.distractors, ['අ', 'ඇ']);
        expect(resolved.equivalentGroupId, 'S3A2R04');
        expect(resolved.itemRole, 'REMEDIATION');
        expect(resolved.responseLoadRelation, 'equivalent');
        expect(resolved.allowedScaffolds, contains('REMOVE_OPTION'));
      },
    );

    test('resolves exact equivalent variant metadata and content', () {
      final activity = ActivityNode(
        id: 'act_1',
        skillId: 'skill_1',
        title: 'Test',
        telemetryTags: const [],
        templateType: 'skill3_image_mcq',
        rounds: [
          {
            'item_id': 'S1A1R01',
            'difficulty_b': -1.0,
            'correctOption': 'core',
            'options': ['core', 'x'],
            'adaptive_variants': [
              {
                'variant_id': 'V1',
                'item_id': 'S1A1R01V1',
                'item_version': 2,
                'difficulty_b': -1.0,
                'content': {
                  'correctOption': 'variant',
                  'options': ['variant', 'y'],
                },
              },
            ],
          },
        ],
      );

      final item = CanonicalItemResolver.resolveByItemId(
        activity,
        'S1A1R01V1',
        0,
      );

      expect(item.itemId, 'S1A1R01V1');
      expect(item.itemVersion, 2);
      expect(item.difficultyB, -1.0);
      expect(item.targets, ['variant']);
      expect(item.distractors, ['y']);
      expect(item.itemRole, 'REMEDIATION');
    });

    test('variant metadata wins over stale research fields inside content', () {
      final activity = ActivityNode(
        id: 'act_3',
        skillId: 'skill_1',
        title: 'Sorting',
        telemetryTags: const [],
        templateType: 'visual_sorting_adventure',
        rounds: [
          {
            'item_id': 'S1A3R03',
            'difficulty_b': 0.0,
            'adaptive_variants': [
              {
                'item_id': 'S1A3R03V1',
                'item_version': 2,
                'difficulty_b': -0.5,
                'item_role': 'REMEDIATION',
                'equivalent_group_id': 'S1A3R03',
                'content': {
                  // Historical duplicated values must not replace the
                  // identity of the variant that is actually displayed.
                  'item_id': 'S1A3R03',
                  'difficulty_b': 0.0,
                  'categories': {
                    'animals': ['cat.png'],
                    'fruits': ['apple.png'],
                  },
                },
              },
            ],
          },
        ],
      );

      final item = CanonicalItemResolver.resolveByItemId(
        activity,
        'S1A3R03V1',
        0,
      );

      expect(item.itemId, 'S1A3R03V1');
      expect(item.itemVersion, 2);
      expect(item.difficultyB, -0.5);
      expect(item.itemRole, 'REMEDIATION');
      expect(item.equivalentGroupId, 'S1A3R03');
      expect(item.targets, ['cat.png', 'apple.png']);
    });

    test('resolves Skill 1 task-family targets for research telemetry', () {
      CanonicalResearchItem resolve(
        String templateType,
        Map<String, dynamic> data,
      ) => CanonicalItemResolver.resolve(
        ActivityNode(
          id: 'act_1',
          skillId: 'skill_1',
          title: 'Test',
          telemetryTags: const [],
          templateType: templateType,
          rounds: const [],
        ),
        <String, dynamic>{'item_id': 'S1A1R01', ...data},
        0,
      );

      expect(
        resolve('visual_odd_one_out', <String, dynamic>{
          'target_assets': <String>['bird.png', 'cat.png'],
        }).targets,
        <String>['bird.png', 'cat.png'],
      );
      expect(
        resolve('visual_sorting_adventure', <String, dynamic>{
          'categories': <String, dynamic>{
            'animals': <String>['bird.png'],
            'fruits': <String>['apple.png'],
          },
        }).targets,
        <String>['bird.png', 'apple.png'],
      );
      expect(
        resolve('visual_pattern_adventure', <String, dynamic>{
          'correct_answer': 'butterfly.png',
          'options': <String>['butterfly.png', 'cat.png'],
        }).targets,
        <String>['butterfly.png'],
      );
      expect(
        resolve('visual_memory_hats', <String, dynamic>{
          'target_asset': 'dog.png',
          'assets': <String>['dog.png', 'cow.png'],
        }).targets,
        <String>['dog.png'],
      );
    });
  });
}
