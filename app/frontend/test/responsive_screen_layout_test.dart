import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/screens/activity_complete_screen.dart';
import 'package:sipsara_app/screens/assessment_prompt_screen.dart';
import 'package:sipsara_app/screens/signin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void useCompactViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('sign-in scrolls when the keyboard reduces the viewport', (
    tester,
  ) async {
    useCompactViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 280)),
          child: child!,
        ),
        home: const SignInScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assessment prompt remains usable on a compact viewport', (
    tester,
  ) async {
    useCompactViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: AssessmentPromptScreen(
          studentId: 'synthetic-student',
          studentName: 'Kasun',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity completion with a break fits compact viewport', (
    tester,
  ) async {
    useCompactViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final activity = ActivityNode.fromJson(<String, dynamic>{
      'id': 'act_1',
      'title': 'පින්තූර වෙන් කරමු',
      'template_type': 'visual_sorting',
      'rounds': <Map<String, dynamic>>[
        <String, dynamic>{'item_id': 'S1A3R01'},
      ],
    })..skillId = 'skill_1';

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

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('කෙටි විවේකයක් ගනිමු 🌿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
