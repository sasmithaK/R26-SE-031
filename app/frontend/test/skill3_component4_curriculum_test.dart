import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/controllers/adaptive_task_coordinator.dart';
import 'package:sipsara_app/models/curriculum_models.dart';

void main() {
  final raw =
      jsonDecode(File('assets/data/curriculum/skill_3.json').readAsStringSync())
          as List<dynamic>;
  final root = Map<String, dynamic>.from(raw.single as Map);
  final activities = (root['activities'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  test('all 75 Skill 3 items resolve with exact V1 and V2 content', () {
    var itemCount = 0;
    for (
      var activityIndex = 0;
      activityIndex < activities.length;
      activityIndex++
    ) {
      final activityJson = activities[activityIndex];
      final activity = ActivityNode.fromJson(activityJson)..skillId = 'skill_3';
      final coordinator = AdaptiveTaskCoordinator(activity: activity);
      final rounds = activityJson['rounds'] as List<dynamic>;
      final expectedVersion = <int>{3, 4}.contains(activityIndex) ? 10 : 9;

      expect(rounds, hasLength(5));
      for (var roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
        final core = Map<String, dynamic>.from(rounds[roundIndex] as Map);
        final baseId =
            'S3A${activityIndex + 1}R${(roundIndex + 1).toString().padLeft(2, '0')}';
        expect(core['item_id'], baseId);
        expect(core['item_version'], expectedVersion);
        itemCount++;

        final variants = (core['adaptive_variants'] as List<dynamic>)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        expect(variants, hasLength(2));

        for (
          var variantIndex = 0;
          variantIndex < variants.length;
          variantIndex++
        ) {
          final variant = variants[variantIndex];
          final itemId = '${baseId}V${variantIndex + 1}';
          final resolved = coordinator.resolveItem(itemId);
          expect(variant['item_id'], itemId);
          expect(variant['item_version'], expectedVersion);
          expect(resolved['item_id'], itemId);
          expect(resolved['core_item_id'], baseId);
          expect(
            resolved['difficulty_features'],
            variant['difficulty_features'],
          );
          final content = Map<String, dynamic>.from(variant['content'] as Map);
          final matchingCoreContent = <String, dynamic>{
            for (final key in content.keys) key: core[key],
          };
          expect(
            jsonEncode(content),
            isNot(jsonEncode(matchingCoreContent)),
            reason: itemId,
          );
          itemCount++;

          if (<int>{0, 3, 4}.contains(activityIndex)) {
            final image = resolved['image_url']?.toString() ?? '';
            expect(image, isNotEmpty, reason: itemId);
            expect(File(image).existsSync(), isTrue, reason: itemId);
          }
        }
      }
    }
    expect(itemCount, 75);
  });

  test(
    'Skill 3 V1 uses the previous structure and V2 keeps core structure',
    () {
      for (
        var activityIndex = 0;
        activityIndex < activities.length;
        activityIndex++
      ) {
        final rounds = activities[activityIndex]['rounds'] as List<dynamic>;
        for (var roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
          final core = Map<String, dynamic>.from(rounds[roundIndex] as Map);
          final variants = core['adaptive_variants'] as List<dynamic>;
          final remediation = Map<String, dynamic>.from(variants[0] as Map);
          final confirmation = Map<String, dynamic>.from(variants[1] as Map);
          final source = Map<String, dynamic>.from(
            rounds[roundIndex == 0 ? 0 : roundIndex - 1] as Map,
          );

          final confirmationId = confirmation['item_id'].toString();
          final remediationId = remediation['item_id'].toString();
          final expectedConfirmation = confirmationId == 'S3A5R02V2'
              ? <String, dynamic>{
                  'word_unit_count': 2,
                  'pilla_count': 1,
                  'answer_pool_size': 2,
                  'has_matching_image': true,
                }
              : core['difficulty_features'];
          final expectedRemediation = remediationId == 'S3A5R03V1'
              ? <String, dynamic>{
                  'word_unit_count': 2,
                  'pilla_count': 1,
                  'answer_pool_size': 2,
                  'has_matching_image': true,
                }
              : source['difficulty_features'];
          expect(
            confirmation['difficulty_features'],
            expectedConfirmation,
            reason: confirmationId,
          );
          expect(
            remediation['difficulty_features'],
            expectedRemediation,
            reason: remediationId,
          );
        }
      }
    },
  );

  test('Activity 1 keeps every answer at the target word-unit length', () {
    final rounds = activities.first['rounds'] as List<dynamic>;
    for (final rawRound in rounds) {
      final core = Map<String, dynamic>.from(rawRound as Map);
      final allItems = <Map<String, dynamic>>[
        core,
        ...(core['adaptive_variants'] as List<dynamic>).map((rawVariant) {
          final variant = Map<String, dynamic>.from(rawVariant as Map);
          return <String, dynamic>{
            ...variant,
            ...Map<String, dynamic>.from(variant['content'] as Map),
          };
        }),
      ];
      for (final item in allItems) {
        final features = Map<String, dynamic>.from(
          item['difficulty_features'] as Map,
        );
        final expected = features['word_unit_count'] as int;
        final options = (item['options'] as List<dynamic>).cast<String>();
        expect(
          options.map(_sinhalaUnitCount).toSet(),
          <int>{expected},
          reason: item['item_id']?.toString(),
        );
      }
    }
  });
}

int _sinhalaUnitCount(String value) {
  const combiningMarks = <int>{
    0x0DCA,
    0x0DCF,
    0x0DD0,
    0x0DD1,
    0x0DD2,
    0x0DD3,
    0x0DD4,
    0x0DD6,
    0x0DD8,
    0x0DD9,
    0x0DDA,
    0x0DDB,
    0x0DDC,
    0x0DDD,
    0x0DDE,
    0x0DDF,
    0x0DF2,
    0x0DF3,
  };
  return value.runes
      .where((rune) => rune >= 0x0D80 && rune <= 0x0DFF)
      .where((rune) => !combiningMarks.contains(rune))
      .length;
}
