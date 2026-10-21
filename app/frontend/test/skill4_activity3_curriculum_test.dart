import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/controllers/adaptive_task_coordinator.dart';
import 'package:sipsara_app/models/curriculum_models.dart';

void main() {
  final raw =
      jsonDecode(File('assets/data/curriculum/skill_4.json').readAsStringSync())
          as List<dynamic>;
  final root = Map<String, dynamic>.from(raw.single as Map);
  final activityJson = Map<String, dynamic>.from(
    (root['activities'] as List<dynamic>).firstWhere(
          (value) => (value as Map)['id'] == 'act_3',
        )
        as Map,
  );
  final activity = ActivityNode.fromJson(activityJson)..skillId = 'skill_4';
  final rounds = (activityJson['rounds'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  Map<String, dynamic> resolve(String itemId) =>
      AdaptiveTaskCoordinator(activity: activity).resolveItem(itemId);

  test('Activity 3 uses the reviewed four-task auditory progression', () {
    final expected = <String, (String, int, int)>{
      'S4A3R01': ('පාසල් යනවා.', 2, 2),
      'S4A3R01V1': ('අම්මා උයයි.', 2, 2),
      'S4A3R01V2': ('පූසා දුවයි.', 2, 2),
      'S4A3R02': ('පොත බලනවා.', 2, 3),
      'S4A3R02V1': ('මල් පිපෙයි.', 2, 2),
      'S4A3R02V2': ('හඳ පායයි.', 2, 3),
      'S4A3R03': ('අම්මා බත් උයයි.', 3, 3),
      'S4A3R03V1': ('බල්ලා දුවයි.', 2, 3),
      'S4A3R03V2': ('මල්ලි සෙල්ලම් කරයි.', 3, 3),
      'S4A3R04': ('සමන් පොතක් කියවයි.', 3, 4),
      'S4A3R04V1': ('තාත්තා ඔරුව පදිනවා.', 3, 3),
      'S4A3R04V2': ('ගුරුතුමී පොත බලනවා.', 3, 4),
    };

    for (final entry in expected.entries) {
      final item = resolve(entry.key);
      final (sentence, wordCount, optionCount) = entry.value;
      final features = Map<String, dynamic>.from(
        item['difficulty_features'] as Map,
      );
      expect(item['item_id'], entry.key);
      expect(item['item_version'], 5);
      expect(item['audio_text'], sentence);
      expect(item['correctOption'], sentence);
      expect(item['options'], hasLength(optionCount));
      expect(features['sentence_word_count'], wordCount);
      expect(features['answer_pool_size'], optionCount);
      expect(features['max_word_letter_count'] as int, lessThanOrEqualTo(4));
    }

    expect(rounds, hasLength(4));
    expect(rounds.last['item_id'], 'S4A3R04');
    expect(resolve('S4A3R05'), isEmpty);
  });

  test('remediation pools follow the preceding core response load', () {
    final expectedRemediationPools = <int>[2, 2, 3, 3];

    for (var index = 0; index < rounds.length; index++) {
      final variants = (rounds[index]['adaptive_variants'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      final remediation = Map<String, dynamic>.from(
        variants.first['content'] as Map,
      );
      expect(
        remediation['options'],
        hasLength(expectedRemediationPools[index]),
        reason: variants.first['item_id'].toString(),
      );
    }

    expect(rounds.first['has_floor_remediation'], isTrue);
    expect(rounds.first['has_reduced_remediation'], isFalse);
    for (final round in rounds.skip(1)) {
      expect(round['has_reduced_remediation'], isTrue);
    }
  });
}
