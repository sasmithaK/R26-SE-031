import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/models/curriculum_models.dart';
import '../lib/widgets/telemetry_wrapper.dart';

// To test the internal state of TelemetryWrapperState, we use a GlobalKey.
void main() {
  group('Adaptive Navigation Tests - Step 2', () {
    late ActivityNode mockActivity;
    late GlobalKey<TelemetryWrapperState> key;

    setUp(() {
      mockActivity = ActivityNode(
        id: 'act_1',
        skillId: 'skill_2',
        name: 'Test Activity',
        description: 'Test',
        templateType: 'shadow_match',
        telemetryTags: [],
        rounds: [
          RoundNode(id: 'r1', stimulus: {}, targets: [], distractors: []),
          RoundNode(id: 'r2', stimulus: {}, targets: [], distractors: []),
          RoundNode(id: 'r3', stimulus: {}, targets: [], distractors: []),
          RoundNode(id: 'r4', stimulus: {}, targets: [], distractors: []),
          RoundNode(id: 'r5', stimulus: {}, targets: [], distractors: []),
          RoundNode(id: 'r6', stimulus: {}, targets: [], distractors: []),
        ],
      );
      key = GlobalKey<TelemetryWrapperState>();
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: TelemetryWrapper(
            key: key,
            activityNode: mockActivity,
            onRoundComplete: (score) {},
            child: const Text('Game'),
          ),
        ),
      );
    }

    testWidgets('TEST 1: Easier Jump - S2A1R06 to S2A1R03', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      final state = key.currentState!;
      
      dynamic dState = state;
      dState.currentRound = 6;

      final mockC4Response = {
        'next_action': {
          'next_activity': '2.1',
          'next_item': 'S2A1R03',
          'difficulty': -0.5,
          'decision': 'CONTINUE'
        }
      };

      dState.applyAdaptiveNextAction(mockC4Response);
      expect(dState.currentRound, 3);
    });

    testWidgets('TEST 2: Harder Jump - S2A1R02 to S2A1R05', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      dynamic dState = key.currentState!;
      dState.currentRound = 2;

      dState.applyAdaptiveNextAction({
        'next_action': {
          'next_activity': '2.1',
          'next_item': 'S2A1R05',
        }
      });
      expect(dState.currentRound, 5);
    });

    testWidgets('TEST 3: Same Round - S2A1R03 to S2A1R03', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      dynamic dState = key.currentState!;
      dState.currentRound = 3;

      dState.applyAdaptiveNextAction({
        'next_action': {
          'next_activity': '2.1',
          'next_item': 'S2A1R03',
        }
      });
      expect(dState.currentRound, 3);
    });

    testWidgets('TEST 4: Invalid Item -> Fallback', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      dynamic dState = key.currentState!;
      dState.currentRound = 2;

      dState.applyAdaptiveNextAction({
        'next_action': {
          'next_activity': '2.1',
          'next_item': 'INVALID',
        }
      });
      expect(dState.currentRound, 3);
    });

    testWidgets('TEST 5: Out of Bounds -> Fallback', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      dynamic dState = key.currentState!;
      dState.currentRound = 2;

      dState.applyAdaptiveNextAction({
        'next_action': {
          'next_activity': '2.1',
          'next_item': 'S2A1R99',
        }
      });
      expect(dState.currentRound, 3);
    });

    testWidgets('TEST 6: Different Activity -> Fallback', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      dynamic dState = key.currentState!;
      dState.currentRound = 2;

      dState.applyAdaptiveNextAction({
        'next_action': {
          'next_activity': '2.2',
          'next_item': 'S2A2R01',
        }
      });
      expect(dState.currentRound, 3);
    });
  });
}
