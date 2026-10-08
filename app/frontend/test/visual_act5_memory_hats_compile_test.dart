import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/screens/games/skill_1/visual_act5_memory_hats.dart';

void main() {
  test('Skill 1 Activity 5 scaffold integration compiles', () {
    expect(VisualAct5MemoryHats, isA<Type>());
  });

  testWidgets('instruction card fits a narrow Grade 1 phone viewport', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final activity = ActivityNode(
      id: 'act_5',
      skillId: 'skill_1',
      title: 'පින්තූර මතකයෙන් සොයමු',
      telemetryTags: const <String>['visual', 'memory'],
      templateType: 'visual_memory_hats',
      rounds: const <Map<String, dynamic>>[
        <String, dynamic>{
          'item_id': 'S1A5R01',
          'assets': <String>['animals/bird.png', 'animals/butterfly.png'],
          'target_asset': 'animals/bird.png',
          'show_milliseconds': 6000,
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: VisualAct5MemoryHats(activityNode: activity)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);

    // Reach the recall layout, where the target preview, Sinhala instruction,
    // and audio button must all share the same narrow row.
    await tester.pump(const Duration(milliseconds: 6000));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Dispose the activity after its delayed sequence has started so the
    // production AnimationControllers cancel their own tickers cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
