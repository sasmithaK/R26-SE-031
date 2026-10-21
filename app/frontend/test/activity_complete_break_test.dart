import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/screens/activity_complete_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final activity = ActivityNode.fromJson(<String, dynamic>{
    'id': 'act_1',
    'title': 'පින්තූර වෙන් කරමු',
    'template_type': 'visual_sorting',
    'rounds': <Map<String, dynamic>>[
      <String, dynamic>{'item_id': 'S1A3R01'},
    ],
  })..skillId = 'skill_1';

  testWidgets('fatigue recommendation appears only after activity completion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityCompleteScreen(
          activityNode: activity,
          skillId: 'skill_1',
          score: 100,
          recommendBreak: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('කෙටි විවේකයක් ගනිමු 🌿'), findsOneWidget);
    expect(find.text('අරඹමු'), findsOneWidget);

    await tester.tap(find.text('අරඹමු'));
    await tester.pump();
    expect(find.textContaining('සන්සුන් වෙමු…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('සන්සුන් වෙමු… 59'), findsOneWidget);
  });

  testWidgets('normal completion does not show a forced break', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityCompleteScreen(
          activityNode: activity,
          skillId: 'skill_1',
          score: 100,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('කෙටි විවේකයක් ගනිමු 🌿'), findsNothing);
  });
}
