import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sipsara_app/adaptive/controllers/adaptive_task_coordinator.dart';
import 'package:sipsara_app/models/curriculum_models.dart';

void main() {
  late SkillDetail skill;

  setUpAll(() {
    final decoded = json.decode(
      File('assets/data/curriculum/skill_1.json').readAsStringSync(),
    );
    skill = SkillDetail.fromJson(decoded, 'skill_1', 'Skill 1');
    for (final activity in skill.activities) {
      activity.skillId = skill.id;
    }
  });

  test(
    'every Skill 1 core keeps local exact-target remediation and confirmation',
    () {
      var targetedCount = 0;

      for (final activity in skill.activities) {
        final coordinator = AdaptiveTaskCoordinator(activity: activity);
        for (
          var roundIndex = 0;
          roundIndex < activity.rounds.length;
          roundIndex++
        ) {
          final core = activity.rounds[roundIndex];
          final coreId = core['item_id'].toString();
          final coreResearch = CanonicalItemResolver.resolveByItemId(
            activity,
            coreId,
            roundIndex,
          );
          final variants = (core['adaptive_variants'] as List? ?? const [])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList();
          final targeted = variants
              .where((variant) => variant['targeted_practice'] == true)
              .toList();

          expect(targeted, isNotEmpty, reason: coreId);
          final units = targeted
              .map((variant) => variant['targeted_unit'].toString())
              .toSet();
          for (final unit in units) {
            final pair = targeted
                .where((variant) => variant['targeted_unit'].toString() == unit)
                .toList();
            expect(pair, hasLength(2), reason: '$coreId $unit');
            expect(
              pair.map((variant) => variant['item_role']).toSet(),
              <String>{'REMEDIATION', 'CONFIRMATION'},
              reason: '$coreId $unit',
            );

            for (final variant in pair) {
              final itemId = variant['item_id'].toString();
              final resolved = coordinator.resolveItem(itemId);
              final research = CanonicalItemResolver.resolveByItemId(
                activity,
                itemId,
                roundIndex,
              );
              expect(resolved['item_id'], itemId, reason: itemId);
              expect(research.itemId, itemId, reason: itemId);
              expect(research.equivalentGroupId, coreId, reason: itemId);
              expect(research.targets, contains(unit), reason: itemId);

              if (variant['item_role'] == 'REMEDIATION') {
                expect(
                  research.responseLoadRelation,
                  'targeted_reduced',
                  reason: itemId,
                );
                expect(
                  research.difficultyB,
                  lessThanOrEqualTo(coreResearch.difficultyB),
                  reason: itemId,
                );
              } else {
                expect(
                  research.responseLoadRelation,
                  'targeted_equivalent',
                  reason: itemId,
                );
                expect(
                  research.difficultyB,
                  coreResearch.difficultyB,
                  reason: itemId,
                );
              }
              targetedCount++;
            }
          }
        }
      }

      expect(targetedCount, 126);
    },
  );

  test('targeted practice stays on the originating core progress dot', () {
    for (final activity in skill.activities) {
      for (
        var roundIndex = 0;
        roundIndex < activity.rounds.length;
        roundIndex++
      ) {
        final core = activity.rounds[roundIndex];
        final targeted = (core['adaptive_variants'] as List)
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .firstWhere((variant) => variant['targeted_practice'] == true);
        final coordinator = AdaptiveTaskCoordinator(
          activity: activity,
          initialRoundIndex: roundIndex,
        );
        final transition = coordinator.applyResult(<String, dynamic>{
          'next_action': <String, dynamic>{
            'decision': 'REMEDIATION',
            'next_phase': 'REMEDIATION',
            'next_item': targeted['item_id'],
          },
        });

        expect(transition.roundIndex, roundIndex);
        expect(transition.itemId, targeted['item_id']);
        expect(transition.isExternal, isFalse);
      }
    }
  });
}
