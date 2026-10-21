import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sipsara_app/screens/therapist/therapist_adaptive_evidence_view.dart';

Map<String, dynamic> _activity({
  required String id,
  required String name,
  required Map<String, dynamic> task,
}) => <String, dynamic>{
  'activity_id': id,
  'activity_name': name,
  'skill_id': '1',
  'skill_name': 'දෘශ්‍ය කුසලතා',
  'knowledge_component_name': 'Visual evidence',
  'mastery': .45,
  'observations': 1,
  'session_count': 1,
  'trend': <Map<String, dynamic>>[],
  'core_tasks': 1,
  'independent_core_tasks': 0,
  'supported_core_tasks': 1,
  'confirmation_tasks': 0,
  'independent_confirmations': 0,
  'last_observed_at': '2026-10-19T03:30:00Z',
  'task_attempts': <Map<String, dynamic>>[task],
};

Map<String, dynamic> _task({
  required String itemId,
  required Map<String, dynamic> preview,
}) => <String, dynamic>{
  'item_id': itemId,
  'session_id': 'session-replay',
  'timestamp': '2026-10-19T03:30:00Z',
  'role': 'CORE',
  'first_response_correct': false,
  'final_correct': true,
  'completed_independently': false,
  'scaffold_level': 1,
  'support_actions': <String>['S1A4R05V2-C4-MODEL-2-1', 'highlightOptions'],
  'attempt_count': 3,
  'incorrect_attempt_count': 2,
  'total_round_latency_ms': 7420,
  'preview': preview,
};

Widget _app(List<Map<String, dynamic>> activities) => MaterialApp(
  home: Scaffold(
    body: TherapistAdaptiveEvidenceView(
      student: const <String, dynamic>{'student_id': 'student-1'},
      initialData: <String, dynamic>{
        'summary': <String, dynamic>{},
        'skills': <Map<String, dynamic>>[],
        'activities': activities,
        'support_effectiveness': <Map<String, dynamic>>[],
        'recurring_targets': <Map<String, dynamic>>[],
      },
    ),
  ),
);

Future<void> _openReplay(
  WidgetTester tester,
  List<Map<String, dynamic>> activities,
  String activityName,
  String itemId,
) async {
  await tester.pumpWidget(_app(activities));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text(activityName), 250);
  await tester.tap(find.text(activityName));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text(itemId), 250);
  await tester.tap(find.text(itemId));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('pattern replay shows a fixed train and attempt outcomes', (
    tester,
  ) async {
    final activity = _activity(
      id: '1.4',
      name: 'Pattern Activity',
      task: _task(
        itemId: 'S1A4R05V2',
        preview: <String, dynamic>{
          'available': true,
          'template_type': 'visual_pattern_adventure',
          'prompt': 'රටාවට ගැළපෙන පින්තූරය තෝරන්න',
          'options': <Map<String, dynamic>>[
            <String, dynamic>{
              'value': 'fruits_food/banana.png',
              'is_correct': true,
              'was_selected': true,
            },
            <String, dynamic>{
              'value': 'fruits_food/grapes.png',
              'is_correct': false,
              'was_selected': true,
            },
          ],
          'category_pairs': <Map<String, dynamic>>[],
          'correct_response': <String>['fruits_food/banana.png'],
          'response_attempts': <Map<String, dynamic>>[
            <String, dynamic>{
              'is_correct': false,
              'selected_answers': <String>['fruits_food/grapes.png'],
              'support_applied_before_response': false,
              'evidence_quality': 'exact',
            },
            <String, dynamic>{
              'is_correct': false,
              'selected_answers': <String>['fruits_food/ice_cream.png'],
              'support_applied_before_response': true,
              'support_actions_before_response': <String>['removeOptions'],
              'evidence_quality': 'exact',
            },
            <String, dynamic>{
              'is_correct': true,
              'selected_answers': <String>['fruits_food/banana.png'],
              'support_applied_before_response': true,
              'support_actions_before_response': <String>['highlightOptions'],
              'evidence_quality': 'exact',
            },
          ],
          'content': <String, dynamic>{
            'sequence': <dynamic>[
              'animals/turtle.png',
              'fruits_food/apple.png',
              'animals/turtle.png',
              null,
            ],
            'missing_index': 3,
          },
        },
      ),
    );

    await _openReplay(
      tester,
      <Map<String, dynamic>>[activity],
      'Pattern Activity',
      'S1A4R05V2',
    );

    expect(find.text('Pattern train'), findsOneWidget);
    expect(find.byIcon(Icons.train_rounded), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Learner response journey'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Incorrect response'), findsNWidgets(2));
    expect(find.text('Correct response'), findsOneWidget);
    expect(
      find.textContaining('Support: Highlight the correct answer'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Evidence details'), 300);
    await tester.pumpAndSettle();
    expect(find.text('3 total · 2 incorrect'), findsOneWidget);
    expect(find.text('7.4 seconds'), findsOneWidget);
    expect(find.text('Highlight the correct answer'), findsOneWidget);
    expect(find.textContaining('C4-MODEL'), findsNothing);
    expect(find.text('Struggled target'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('memory replay shows the target and complete card pool', (
    tester,
  ) async {
    final activity = _activity(
      id: '1.5',
      name: 'Memory Activity',
      task: _task(
        itemId: 'S1A5R04V2',
        preview: <String, dynamic>{
          'available': true,
          'template_type': 'visual_memory_hats',
          'prompt': 'මේ පින්තූරය තිබූ තැන තෝරන්න',
          'options': <Map<String, dynamic>>[],
          'category_pairs': <Map<String, dynamic>>[],
          'correct_response': <String>['everyday_objects/key.png'],
          'response_attempts': <Map<String, dynamic>>[],
          'content': <String, dynamic>{
            'assets': <String>[
              'everyday_objects/key.png',
              'everyday_objects/bell.png',
              'everyday_objects/clock.png',
              'everyday_objects/hat.png',
            ],
            'target_asset': 'everyday_objects/key.png',
          },
        },
      ),
    );

    await _openReplay(
      tester,
      <Map<String, dynamic>>[activity],
      'Memory Activity',
      'S1A5R04V2',
    );

    expect(find.text('Picture to remember'), findsOneWidget);
    expect(find.text('Cards shown'), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(5));
    expect(tester.takeException(), isNull);
  });
}
