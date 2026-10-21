import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/screens/games/skill_4/skill4_act1_mcq.dart';
import 'package:sipsara_app/screens/games/skill_4/skill4_act2_fill_blank.dart';
import 'package:sipsara_app/screens/games/skill_4/skill4_act3_mcq.dart';
import 'package:sipsara_app/screens/games/skill_4/skill4_act4_jumbled_sentence.dart';

void main() {
  final decoded =
      jsonDecode(File('assets/data/curriculum/skill_4.json').readAsStringSync())
          as List<dynamic>;
  final root = Map<String, dynamic>.from(decoded.single as Map);
  final activities = (root['activities'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  ActivityNode activityAt(int index) =>
      ActivityNode.fromJson(activities[index])..skillId = 'skill_4';

  Future<void> pumpGame(WidgetTester tester, Widget game) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(home: game));
    await tester.pump();
  }

  void resetView(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  Color optionBorderColor(WidgetTester tester, Finder option) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: option, matching: find.byType(AnimatedContainer)),
    );
    return (container.decoration! as BoxDecoration).border!.top.color;
  }

  testWidgets('Activity 1 shows stable green feedback before any transition', (
    tester,
  ) async {
    addTearDown(() => resetView(tester));
    final activity = activityAt(0);
    final round = activity.rounds.first;
    final itemId = round['item_id'].toString();
    final correctIndex = round['correct_index'] as int;
    final option = find.byKey(ValueKey('$itemId-option-$correctIndex'));

    await pumpGame(tester, Skill4Act1Mcq(activityNode: activity));
    await tester.tap(option);
    await tester.pump();

    expect(optionBorderColor(tester, option), const Color(0xFF6DBE6D));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(optionBorderColor(tester, option), const Color(0xFF6DBE6D));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(optionBorderColor(tester, option), isNot(const Color(0xFF6DBE6D)));
  });

  testWidgets('Activity 2 keeps its correct option visible and green', (
    tester,
  ) async {
    addTearDown(() => resetView(tester));
    final activity = activityAt(1);
    final round = activity.rounds.first;
    final itemId = round['item_id'].toString();
    final options = (round['options'] as List<dynamic>).cast<String>();
    final correctIndex = options.indexOf(round['correctOption'].toString());
    final option = find.byKey(ValueKey('$itemId-option-$correctIndex'));

    await pumpGame(tester, Skill4Act2FillBlank(activityNode: activity));
    await tester.tap(option);
    await tester.pump();

    expect(option, findsOneWidget);
    expect(optionBorderColor(tester, option), const Color(0xFF6DBE6D));
    expect(find.byKey(ValueKey('$itemId-blank-slot')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(optionBorderColor(tester, option), const Color(0xFF6DBE6D));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(optionBorderColor(tester, option), isNot(const Color(0xFF6DBE6D)));
  });

  testWidgets('Activity 3 holds auditory answer feedback before resetting', (
    tester,
  ) async {
    addTearDown(() => resetView(tester));
    final activity = activityAt(2);
    final round = activity.rounds.first;
    final itemId = round['item_id'].toString();
    final correctIndex = round['correct_index'] as int;
    final option = find.byKey(ValueKey('$itemId-option-$correctIndex'));

    await pumpGame(tester, Skill4Act3Mcq(activityNode: activity));
    await tester.tap(option);
    await tester.pump();

    expect(optionBorderColor(tester, option), const Color(0xFF6DBE6D));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(optionBorderColor(tester, option), const Color(0xFF6DBE6D));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(optionBorderColor(tester, option), isNot(const Color(0xFF6DBE6D)));
  });

  testWidgets('Activity 4 keeps the completed sentence green before reset', (
    tester,
  ) async {
    addTearDown(() => resetView(tester));
    final activity = activityAt(3);
    final round = activity.rounds.first;
    final itemId = round['item_id'].toString();
    final pool = (round['scrambled_words'] as List<dynamic>).cast<String>();
    final correctWords = round['correct_sentence']
        .toString()
        .replaceFirst(RegExp(r'[.!?]$'), '')
        .split(RegExp(r'\s+'));
    final used = <int>{};
    final correctPoolIndices = <int>[];
    for (final word in correctWords) {
      final index = List<int>.generate(pool.length, (value) => value)
          .firstWhere(
            (candidate) => !used.contains(candidate) && pool[candidate] == word,
          );
      used.add(index);
      correctPoolIndices.add(index);
    }

    await pumpGame(tester, Skill4Act4JumbledSentence(activityNode: activity));
    for (final index in correctPoolIndices) {
      await tester.tap(find.byKey(ValueKey('$itemId-token-$index')));
      await tester.pump();
    }

    final success = find.byKey(ValueKey('$itemId-correct-sentence'));
    expect(success, findsOneWidget);
    final successContainer = tester.widget<AnimatedContainer>(success);
    expect(
      (successContainer.decoration! as BoxDecoration).border!.top.color,
      const Color(0xFF6DBE6D),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    expect(success, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(success, findsNothing);
  });
}
