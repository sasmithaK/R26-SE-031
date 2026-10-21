import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipsara_app/adaptive/controllers/adaptive_task_coordinator.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/screens/games/skill_4/skill4_act1_mcq.dart';

void main() {
  final raw =
      jsonDecode(File('assets/data/curriculum/skill_4.json').readAsStringSync())
          as List<dynamic>;
  final root = Map<String, dynamic>.from(raw.single as Map);
  final activityJson = Map<String, dynamic>.from(
    (root['activities'] as List<dynamic>).first as Map,
  );
  final activity = ActivityNode.fromJson(activityJson)..skillId = 'skill_4';
  final rounds = (activityJson['rounds'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  Map<String, dynamic> resolve(String itemId) =>
      AdaptiveTaskCoordinator(activity: activity).resolveItem(itemId);

  test('opening tasks use the reviewed Grade 1 sentence sequence', () {
    final expected = <String, (String, String, int)>{
      'S4A1R01': ('හඳ පායනවා.', 'moon_shining.png', 2),
      'S4A1R01V2': ('ඉර පායනවා.', 'sun_shining.png', 2),
      'S4A1R02': ('අම්මා උයනවා.', 'mother_cooking.png', 3),
      'S4A1R02V1': ('ඔරුව පදිනවා.', 'rowing_boat.png', 2),
      'S4A1R02V2': ('පොත කියවනවා.', 'boy_reading.png', 3),
      'S4A1R03': ('පවනි පාසල් යනවා.', 'girl_going_to_school.png', 3),
      'S4A1R04': ('කෝසල සරුංගලය යවනවා.', 'boy_flying_kite.png', 3),
      'S4A1R04V1': ('පවනි සෙල්ලම් කරනවා.', 'children_playing_ball.jpg', 3),
      'S4A1R04V2': ('ගුරුතුමී අකුරු ලියනවා.', 'teacher_writing.png', 3),
    };

    for (final entry in expected.entries) {
      final item = resolve(entry.key);
      final (answer, imageName, optionCount) = entry.value;
      expect(item['item_id'], entry.key);
      expect(item['item_version'], 5);
      expect(item['correctOption'], answer);
      expect(item['image_url'].toString(), endsWith(imageName));
      expect(item['options'], hasLength(optionCount));
      expect(
        File(item['image_url'].toString()).existsSync(),
        isTrue,
        reason: entry.key,
      );
    }
  });

  test('Task 1 exposes one active sun retry instead of two', () {
    final variants = (rounds.first['adaptive_variants'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final remediation = variants.first;
    final confirmation = variants.last;

    expect(remediation['item_id'], 'S4A1R01V1');
    expect(remediation['is_active'], isFalse);
    expect(confirmation['item_id'], 'S4A1R01V2');
    expect(confirmation['is_active'], isTrue);
    expect(remediation['single_floor_retry'], isTrue);
    expect(confirmation['single_floor_retry'], isTrue);
    expect(remediation['content'], confirmation['content']);
  });

  test('Task 2 keeps separate remediation and confirmation content', () {
    final variants = (rounds[1]['adaptive_variants'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    expect(variants.first['item_id'], 'S4A1R02V1');
    expect(variants.last['item_id'], 'S4A1R02V2');
    expect(
      variants.first['content']['correctOption'],
      isNot(variants.last['content']['correctOption']),
    );
    expect(rounds[1]['has_reduced_remediation'], isTrue);
  });

  test('Activity 1 ends at Task 4 with remediation and confirmation', () {
    expect(rounds, hasLength(4));
    expect(rounds.last['item_id'], 'S4A1R04');
    expect(rounds.last['difficulty_label'], 'hard');
    expect(rounds.last['has_reduced_remediation'], isTrue);

    final variants = (rounds.last['adaptive_variants'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    expect(variants.first['item_id'], 'S4A1R04V1');
    expect(variants.last['item_id'], 'S4A1R04V2');
  });

  testWidgets('a missing or duplicate response never completes the activity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: Skill4Act1Mcq(activityNode: activity)),
    );
    await tester.pump();

    final correctAnswer = find.text('හඳ පායනවා.');
    expect(correctAnswer, findsOneWidget);
    await tester.tap(correctAnswer);
    await tester.tap(correctAnswer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('ඔබ සියල්ල සාර්ථකව නිම කළා!'), findsNothing);
    expect(find.text('1/4'), findsOneWidget);
    expect(correctAnswer, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
