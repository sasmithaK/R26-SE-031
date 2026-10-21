import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/services/progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'parent practice uses the generic confirmation as each playable round',
    () {
      final activity =
          ActivityNode.fromJson(<String, dynamic>{
              'id': 'act_1',
              'title': 'Test activity',
              'template_type': 'skill2_mcq',
              'rounds': <Map<String, dynamic>>[
                <String, dynamic>{
                  'item_id': 'S2A1R01',
                  'item_role': 'CORE',
                  'options': <String>['core', 'other'],
                  'correct_index': 0,
                  'adaptive_variants': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'item_id': 'S2A1R01V1',
                      'item_role': 'REMEDIATION',
                      'content': <String, dynamic>{
                        'options': <String>['remediation', 'other'],
                        'correct_index': 0,
                      },
                    },
                    <String, dynamic>{
                      'item_id': 'S2A1R01V2',
                      'item_role': 'CONFIRMATION',
                      'response_load_relation': 'equivalent',
                      'content': <String, dynamic>{
                        'options': <String>['fresh', 'different'],
                        'correct_index': 0,
                      },
                    },
                    <String, dynamic>{
                      'item_id': 'S2A1R01V4',
                      'item_role': 'CONFIRMATION',
                      'targeted_practice': true,
                      'content': <String, dynamic>{
                        'options': <String>['targeted', 'different'],
                        'correct_index': 0,
                      },
                    },
                  ],
                },
              ],
            })
            ..skillId = 'skill_2'
            ..skillTitle = 'Skill 2';

      final practice = activity.asParentPractice();
      final round = practice.rounds.single;

      expect(practice.isParentPractice, isTrue);
      expect(practice.id, 'parent_practice_act_1');
      expect(practice.skillId, 'skill_2');
      expect(round['item_id'], 'S2A1R01V2');
      expect(round['item_role'], 'PARENT_PRACTICE');
      expect(round['options'], <String>['fresh', 'different']);
      expect(round['practice_origin_item_id'], 'S2A1R01');
      expect(round['practice_source_item_id'], 'S2A1R01V2');
      expect(round.containsKey('adaptive_variants'), isFalse);

      // The normal activity remains intact.
      expect(activity.rounds.single['item_id'], 'S2A1R01');
      expect(activity.rounds.single['adaptive_variants'], isNotNull);
    },
  );

  test(
    'parent practice safely falls back when a future round has no variant',
    () {
      final activity = ActivityNode.fromJson(<String, dynamic>{
        'id': 'act_1',
        'title': 'Future activity',
        'template_type': 'skill2_mcq',
        'rounds': <Map<String, dynamic>>[
          <String, dynamic>{
            'item_id': 'S5A1R01',
            'item_role': 'CORE',
            'options': <String>['one', 'two'],
            'correct_index': 0,
          },
        ],
      });

      final round = activity.asParentPractice().rounds.single;

      expect(round['item_id'], 'S5A1R01');
      expect(round['item_role'], 'PARENT_PRACTICE');
      expect(round['options'], <String>['one', 'two']);
    },
  );

  test('parent practice saves only its own resumable checkpoint', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final progress = ProgressService();
    await progress.init();
    await progress.setCurrentStudentId('practice_test_student');

    await progress.saveActivityScore('skill_2', 'parent_practice_act_3', 100);
    await progress.saveActivityState('skill_2', 'parent_practice_act_3', 4);
    await progress.markActivityCompleted('skill_2', 'parent_practice_act_3');

    expect(progress.getActivityScore('skill_2', 'parent_practice_act_3'), 0);
    expect(progress.getActivityState('skill_2', 'parent_practice_act_3'), 4);
    expect(
      progress.isActivityCompleted('skill_2', 'parent_practice_act_3'),
      isFalse,
    );

    await progress.clearActivityState('skill_2', 'parent_practice_act_3');
    expect(progress.getActivityState('skill_2', 'parent_practice_act_3'), 0);
  });
}
