import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/controllers/adaptive_task_coordinator.dart';
import 'package:sipsara_app/models/curriculum_models.dart';

void main() {
  final activity = ActivityNode.fromJson(<String, dynamic>{
    'id': 'act_1',
    'title': 'test',
    'template_type': 'test',
    'rounds': <Map<String, dynamic>>[
      <String, dynamic>{
        'item_id': 'S3A1R01',
        'options': <String>['core', 'x'],
        'adaptive_variants': <Map<String, dynamic>>[
          <String, dynamic>{
            'variant_id': 'V1',
            'item_id': 'S3A1R01V1',
            'item_role': 'REMEDIATION',
            'content': <String, dynamic>{
              'options': <String>['remediation', 'x'],
            },
          },
          <String, dynamic>{
            'variant_id': 'V2',
            'item_id': 'S3A1R01V2',
            'item_role': 'CONFIRMATION',
            'content': <String, dynamic>{
              'options': <String>['confirmation', 'x'],
            },
          },
        ],
      },
      <String, dynamic>{'item_id': 'S3A1R02'},
    ],
  })..skillId = 'skill_3';

  test('renders exact variant while retaining its core progress position', () {
    final coordinator = AdaptiveTaskCoordinator(activity: activity);
    final transition = coordinator.applyResult(<String, dynamic>{
      'next_action': <String, dynamic>{
        'next_item': 'S3A1R01V1',
        'next_phase': 'REMEDIATION',
        'next_activity': '3.1',
        'decision': 'REMEDIATION',
      },
    });
    expect(transition.roundIndex, 0);
    expect(transition.itemId, 'S3A1R01V1');
    expect(transition.roundData['options'], <String>['remediation', 'x']);
    expect(coordinator.progressIndex, 0);
  });

  test('confirmation uses V2 content and then advances to next core', () {
    final coordinator = AdaptiveTaskCoordinator(activity: activity);
    final confirmation = coordinator.applyResult(<String, dynamic>{
      'next_action': <String, dynamic>{
        'next_item': 'S3A1R01V2',
        'next_phase': 'CONFIRMATION',
        'next_activity': '3.1',
        'decision': 'CONFIRMATION',
      },
    });
    expect(confirmation.roundData['options'], <String>['confirmation', 'x']);
    final next = coordinator.applyResult(<String, dynamic>{
      'next_action': <String, dynamic>{
        'next_item': 'S3A1R02',
        'next_phase': 'CORE',
        'next_activity': '3.1',
        'decision': 'CONTINUE',
      },
    });
    expect(next.roundIndex, 1);
    expect(next.itemId, 'S3A1R02');
  });

  test(
    'terminate without completion evidence never fakes activity completion',
    () {
      final coordinator = AdaptiveTaskCoordinator(activity: activity);
      final transition = coordinator.applyResult(<String, dynamic>{
        'next_action': <String, dynamic>{
          'next_item': '',
          'next_phase': 'CORE',
          'next_activity': '3.1',
          'decision': 'TERMINATE',
        },
      });
      expect(transition.isComplete, isFalse);
      expect(transition.roundIndex, 1);
      expect(transition.itemId, 'S3A1R02');
      expect(
        transition.reasonCodes,
        contains('TERMINATE_IS_NOT_ACTIVITY_COMPLETE'),
      );
    },
  );
}
