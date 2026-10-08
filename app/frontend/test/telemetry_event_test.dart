import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/models/adaptive_scaffold_models.dart';
import 'package:sipsara_app/models/curriculum_models.dart';
import 'package:sipsara_app/services/telemetry_service.dart';
import 'package:sipsara_app/widgets/telemetry_wrapper.dart';

ActivityNode _skillOneActivity() {
  return ActivityNode.fromJson(<String, dynamic>{
    'id': 'act_1',
    'title': 'Hidden search',
    'template_type': 'visual_hidden_search',
    'research_metadata': <String, dynamic>{
      'knowledge_component_id': 'KC_VISUAL_IDENTIFICATION',
      'prompt_modality': 'visual',
      'response_modality': 'tap',
      'research_role': 'supportive',
    },
    'rounds': <Map<String, dynamic>>[
      <String, dynamic>{
        'item_id': 'S1A1R01',
        'item_version': 2,
        'difficulty_label': 'easy',
        'difficulty_b': -1.0,
        'is_anchor': false,
        'equivalent_group_id': 'S1A1R01',
        'targets': <String>['animals/dog.png'],
      },
    ],
  })..skillId = 'skill_1';
}

void main() {
  test('research telemetry serializes exact adaptive item lineage', () {
    final event = TelemetryEvent(
      eventId: 'session:S1A5R02V1:complete',
      activityName: 'visual_memory_hats',
      roundNumber: 2,
      isCorrect: true,
      score: 95,
      timestamp: DateTime.utc(2026, 10, 7),
      firstTouchLatencyMs: 4000,
      totalRoundLatencyMs: 7000,
      misclickCount: 1,
      hesitationCount: 0,
      audioReplayCount: 0,
      isAbandoned: false,
      touchPath: const <TouchPoint>[],
      itemId: 'S1A5R02V1',
      knowledgeComponentId: 'KC_VISUAL_MEMORY',
      itemRole: 'REMEDIATION',
      equivalentGroupId: 'S1A5R02',
      responseLoadRelation: 'reduced',
      targets: const <String>['animals/cat.png'],
      selectedAnswers: const <String>['animals/cat.png'],
      scaffoldLevelUsed: 2,
      scaffoldApplications: const <Map<String, dynamic>>[
        <String, dynamic>{'scaffold_level': 2, 'action': 'disable_options'},
      ],
    );

    final json = event.toJson();
    expect(json['knowledge_component_id'], 'KC_VISUAL_MEMORY');
    expect(json['item_role'], 'REMEDIATION');
    expect(json['equivalent_group_id'], 'S1A5R02');
    expect(json['response_load_relation'], 'reduced');
    expect(json['targets'], <String>['animals/cat.png']);
    expect(json['selected_answers'], <String>['animals/cat.png']);
    expect(json['event_id'], 'session:S1A5R02V1:complete');
    expect(json['phase'], 'COMPLETE');
    expect(json['scaffold_level_used'], 2);
    expect(json['scaffold_applications'], hasLength(1));
    expect(json['timestamp'], '2026-10-07T00:00:00.000Z');
  });

  test('session serialization reuses the real-time completion event id', () {
    final event = TelemetryEvent(
      eventId: 'session:S1A1R01:complete',
      activityName: 'visual_hidden_search',
      roundNumber: 1,
      isCorrect: true,
      score: 100,
      timestamp: DateTime.utc(2026, 10, 8),
      firstTouchLatencyMs: 1500,
      totalRoundLatencyMs: 4000,
      misclickCount: 0,
      hesitationCount: 0,
      audioReplayCount: 0,
      isAbandoned: false,
      touchPath: const <TouchPoint>[],
    );

    final serialized = serializeTelemetryEvents(<TelemetryEvent>[
      event,
    ], 'session');

    expect(serialized.single['event_id'], 'session:S1A1R01:complete');
    expect(serialized.single['phase'], 'COMPLETE');
  });

  test('session payload preserves lineage and real UTC time boundaries', () {
    final payload = buildTelemetrySessionPayload(
      studentId: 'student-1',
      sessionId: 'session-1',
      durationSeconds: 60,
      startedAt: DateTime.parse('2026-10-08T09:00:00+05:30'),
      completedAt: DateTime.parse('2026-10-08T09:01:00+05:30'),
      events: <Map<String, dynamic>>[
        <String, dynamic>{'skill_id': 'skill_1', 'activity_id': 'act_4'},
      ],
      deviceMetrics: <String, dynamic>{'os': 'ios'},
    );

    expect(payload['skill_id'], 'skill_1');
    expect(payload['activity_id'], 'act_4');
    expect(payload['started_at'], '2026-10-08T03:30:00.000Z');
    expect(payload['completed_at'], '2026-10-08T03:31:00.000Z');
    expect(payload['session_duration_seconds'], 60);
  });

  test('disabled memory cards count as instructional hints', () {
    const commands = <ScaffoldCommand>[
      ScaffoldCommand(
        actionId: 'disable-1',
        type: ScaffoldActionType.disableOptions,
      ),
      ScaffoldCommand(
        actionId: 'highlight-1',
        type: ScaffoldActionType.highlightOptions,
      ),
      ScaffoldCommand(
        actionId: 'audio-1',
        type: ScaffoldActionType.replayInstruction,
      ),
    ];

    expect(countInstructionalChoiceHints(commands), 2);
  });

  test('only standalone level-map sessions submit at activity completion', () {
    final telemetry = TelemetryService();

    telemetry.startSession(submitOnActivityComplete: true);
    expect(telemetry.submitOnActivityComplete, isTrue);

    telemetry.startSession();
    expect(telemetry.submitOnActivityComplete, isFalse);
  });

  testWidgets('abandonment keeps canonical Skill 1 research identity', (
    tester,
  ) async {
    final activity = _skillOneActivity();
    final telemetry = TelemetryService()..startSession();

    await tester.pumpWidget(
      MaterialApp(
        home: TelemetryWrapper(
          activityNode: activity,
          onRoundComplete: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final event = telemetry.sessionEvents.single;
    final json = event.toJson();
    expect(json['phase'], 'ABANDONED');
    expect(json['is_abandoned'], isTrue);
    expect(json['skill_id'], 'skill_1');
    expect(json['activity_id'], 'act_1');
    expect(json['item_id'], 'S1A1R01');
    expect(json['item_version'], 2);
    expect(json['knowledge_component_id'], 'KC_VISUAL_IDENTIFICATION');
    expect(json['final_correct'], isFalse);
    expect(json['event_id'], endsWith(':S1A1R01:abandoned'));
  });

  testWidgets(
    'route pop records abandonment before the navigation future resumes',
    (tester) async {
      final telemetry = TelemetryService()..startSession();
      int? eventsVisibleAfterRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => TelemetryWrapper(
                        activityNode: _skillOneActivity(),
                        onRoundComplete: (_) {},
                        child: const Scaffold(body: SizedBox.expand()),
                      ),
                    ),
                  );
                  eventsVisibleAfterRoute = telemetry.sessionEvents.length;
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(eventsVisibleAfterRoute, 1);
      expect(telemetry.sessionEvents.single.phase, 'ABANDONED');
      expect(
        telemetry.sessionEvents.single.eventId,
        endsWith(':S1A1R01:abandoned'),
      );
    },
  );

  testWidgets('completed activity pop never creates a false abandonment', (
    tester,
  ) async {
    final telemetry = TelemetryService()..startSession();
    final wrapperKey = GlobalKey<TelemetryWrapperState>();

    await tester.pumpWidget(
      MaterialApp(
        home: TelemetryWrapper(
          key: wrapperKey,
          activityNode: _skillOneActivity(),
          onRoundComplete: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    wrapperKey.currentState!.applyAdaptiveNextAction(<String, dynamic>{
      'next_action': <String, dynamic>{
        'decision': 'ACTIVITY_COMPLETE',
        'next_item': 'COMPLETE',
      },
      'response_quality': 'CLEAN_SUCCESS',
    });
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(telemetry.sessionEvents, isEmpty);
  });
}
