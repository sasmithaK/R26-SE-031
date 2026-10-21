import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/screens/games/skill_4/skill4_act4_jumbled_sentence.dart';
import 'package:sipsara_app/services/progress_service.dart';

void main() {
  final raw =
      jsonDecode(File('assets/data/curriculum/skill_4.json').readAsStringSync())
          as List<dynamic>;
  final root = Map<String, dynamic>.from(raw.single as Map);
  final activityJson = Map<String, dynamic>.from(
    (root['activities'] as List<dynamic>).firstWhere(
          (value) => (value as Map)['id'] == 'act_4',
        )
        as Map,
  );
  final rounds = (activityJson['rounds'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  test('Activity 4 uses the reviewed shared and two-step retry routes', () {
    final expected = <String, (String, int)>{
      'S4A4R01': ('පාසල් යනවා.', 2),
      'S4A4R01V1': ('හඳ පායනවා.', 2),
      'S4A4R01V2': ('හඳ පායනවා.', 2),
      'S4A4R02': ('පොතක් කියවනවා.', 2),
      'S4A4R02V1': ('මල් පිපෙනවා.', 2),
      'S4A4R02V2': ('බල්ලා දුවනවා.', 2),
      'S4A4R03': ('මල්ලි සරුංගලයක් යවනවා.', 3),
      'S4A4R03V1': ('කුරුල්ලා පියාඹනවා.', 2),
      'S4A4R03V2': ('තාත්තා ඔරුව පදිනවා.', 3),
      'S4A4R04': ('බල්ලාට කෑම දෙනවා.', 3),
      'S4A4R04V1': ('අම්මා බත් උයනවා.', 3),
      'S4A4R04V2': ('ගුරුතුමී අකුරු ලියනවා.', 3),
    };
    final activity = ActivityNode.fromJson(activityJson)..skillId = 'skill_4';

    Map<String, dynamic> resolve(String itemId) {
      for (final round in activity.rounds) {
        if (round['item_id'] == itemId) return round;
        for (final rawVariant in (round['adaptive_variants'] as List? ?? [])) {
          final variant = Map<String, dynamic>.from(rawVariant as Map);
          if (variant['item_id'] == itemId) {
            return <String, dynamic>{
              ...Map<String, dynamic>.from(variant['content'] as Map),
              ...variant,
            };
          }
        }
      }
      return const <String, dynamic>{};
    }

    expect(rounds, hasLength(4));
    for (final entry in expected.entries) {
      final item = resolve(entry.key);
      final (sentence, wordCount) = entry.value;
      final words = sentence.replaceFirst(RegExp(r'[.!?]$'), '').split(' ');
      expect(item['item_version'], 4, reason: entry.key);
      expect(item['correct_sentence'], sentence, reason: entry.key);
      expect(
        (item['scrambled_words'] as List<dynamic>).toSet(),
        words.toSet(),
        reason: entry.key,
      );
      final features = Map<String, dynamic>.from(
        item['difficulty_features'] as Map,
      );
      expect(features['sentence_word_count'], wordCount, reason: entry.key);
      expect(features['answer_pool_size'], wordCount, reason: entry.key);
    }
    expect(resolve('S4A4R01V1')['is_active'], isFalse);
    expect(resolve('S4A4R01V2')['is_active'], isTrue);
    expect(resolve('S4A4R01V1')['single_floor_retry'], isTrue);
    expect(resolve('S4A4R01V2')['single_floor_retry'], isTrue);
    expect(resolve('S4A4R02')['has_floor_remediation'], isTrue);
    expect(resolve('S4A4R02')['has_reduced_remediation'], isFalse);
    expect(resolve('S4A4R05'), isEmpty);
  });

  testWidgets('three-word errors retain and lock the correct prefix', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressService().init();
    await ProgressService().saveActivityState('skill_4', 'act_4', 2);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;

    final taskThreeActivity = ActivityNode.fromJson(activityJson)
      ..skillId = 'skill_4';
    await tester.pumpWidget(
      MaterialApp(
        home: Skill4Act4JumbledSentence(activityNode: taskThreeActivity),
      ),
    );
    await tester.pump();

    // Correct first word, then deliberately reverse the two remaining words.
    for (final word in <String>['මල්ලි', 'යවනවා', 'සරුංගලයක්']) {
      await tester.tap(find.text(word));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 900));

    final lockedWord = find.text('මල්ලි');
    final firstSlot = find
        .ancestor(of: lockedWord, matching: find.byType(AnimatedContainer))
        .first;
    final container = tester.widget<AnimatedContainer>(firstSlot);
    expect(
      (container.decoration! as BoxDecoration).border!.top.color,
      const Color(0xFF6DBE6D),
    );
    expect(lockedWord, findsOneWidget);

    // A locked correct prefix cannot be returned to the answer pool.
    await tester.tap(lockedWord);
    await tester.pump();
    expect(lockedWord, findsOneWidget);
  });
}
