import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/controllers/adaptive_choice_controller.dart';
import 'package:sipsara_app/adaptive/models/adaptive_scaffold_models.dart';
import 'package:sipsara_app/adaptive/widgets/adaptive_answer_pool.dart';

void main() {
  AdaptiveChoiceController<String> controller() =>
      AdaptiveChoiceController<String>(
        options: const <AdaptiveOption<String>>[
          AdaptiveOption<String>(
            id: 'S2A1R01_O1',
            value: 'ක',
            role: AdaptiveOptionRole.target,
          ),
          AdaptiveOption<String>(id: 'S2A1R01_O2', value: 'ග'),
          AdaptiveOption<String>(id: 'S2A1R01_O3', value: 'ච'),
          AdaptiveOption<String>(id: 'S2A1R01_O4', value: 'ට'),
        ],
      );

  test('removes distractors deterministically without removing the target', () {
    final choices = controller();
    final report = choices.applyPlan(
      const ScaffoldPlan(
        actionId: 'plan-1',
        commands: <ScaffoldCommand>[
          ScaffoldCommand(
            actionId: 'remove-1',
            type: ScaffoldActionType.removeOptions,
            targetOptionIds: <String>{'S2A1R01_O2'},
          ),
        ],
      ),
    );

    expect(
      choices.visibleOptions.map((option) => option.id),
      isNot(contains('S2A1R01_O2')),
    );
    expect(report.visibleBefore, 4);
    expect(report.visibleAfter, 3);

    final targetReport = choices.applyPlan(
      const ScaffoldPlan(
        actionId: 'plan-2',
        commands: <ScaffoldCommand>[
          ScaffoldCommand(
            actionId: 'remove-target',
            type: ScaffoldActionType.removeOptions,
            targetOptionIds: <String>{'S2A1R01_O1'},
          ),
        ],
      ),
    );
    expect(
      choices.visibleOptions.map((option) => option.id),
      contains('S2A1R01_O1'),
    );
    expect(
      targetReport.rejectedReasons,
      contains('TARGET_REMOVAL_BLOCKED:S2A1R01_O1'),
    );
  });

  test('never reduces a Grade 1 answer pool below two visible choices', () {
    final choices = controller();
    choices.applyPlan(
      const ScaffoldPlan(
        actionId: 'plan-minimum',
        commands: <ScaffoldCommand>[
          ScaffoldCommand(
            actionId: 'remove-many',
            type: ScaffoldActionType.removeOptions,
            targetOptionIds: <String>{'S2A1R01_O2', 'S2A1R01_O3', 'S2A1R01_O4'},
          ),
        ],
      ),
    );
    expect(choices.visibleOptions, hasLength(2));
  });

  test('two-card memory preserves both cards and can highlight the target', () {
    final choices = AdaptiveChoiceController<int>(
      minimumVisibleOptions: 2,
      options: const <AdaptiveOption<int>>[
        AdaptiveOption<int>(
          id: 'S1A5R01_O1',
          value: 0,
          role: AdaptiveOptionRole.target,
        ),
        AdaptiveOption<int>(
          id: 'S1A5R01_O2',
          value: 1,
          role: AdaptiveOptionRole.visualDistractor,
        ),
      ],
    );

    final removal = choices.applyPlan(
      const ScaffoldPlan(
        actionId: 'memory-remove-plan',
        commands: <ScaffoldCommand>[
          ScaffoldCommand(
            actionId: 'memory-remove-wrong',
            type: ScaffoldActionType.removeOptions,
            targetOptionIds: <String>{'S1A5R01_O2'},
          ),
        ],
      ),
    );

    expect(choices.visibleOptions, hasLength(2));
    expect(
      removal.rejectedReasons,
      contains('MINIMUM_VISIBLE_OPTIONS_REACHED'),
    );

    choices.applyPlan(
      const ScaffoldPlan(
        actionId: 'memory-highlight-plan',
        commands: <ScaffoldCommand>[
          ScaffoldCommand(
            actionId: 'memory-highlight-target',
            type: ScaffoldActionType.highlightOptions,
            targetOptionIds: <String>{'S1A5R01_O1'},
          ),
        ],
      ),
    );
    expect(
      choices.visualStateFor('S1A5R01_O1'),
      AdaptiveOptionVisualState.hint,
    );
  });

  test(
    'disabled memory card stays visible but becomes non-interactive state',
    () {
      final choices = AdaptiveChoiceController<int>(
        options: const <AdaptiveOption<int>>[
          AdaptiveOption<int>(
            id: 'S1A5R02_O1',
            value: 0,
            role: AdaptiveOptionRole.target,
          ),
          AdaptiveOption<int>(id: 'S1A5R02_O2', value: 1),
          AdaptiveOption<int>(id: 'S1A5R02_O3', value: 2),
        ],
      );

      choices.applyPlan(
        const ScaffoldPlan(
          actionId: 'memory-lock-plan',
          commands: <ScaffoldCommand>[
            ScaffoldCommand(
              actionId: 'memory-lock-wrong',
              type: ScaffoldActionType.disableOptions,
              targetOptionIds: <String>{'S1A5R02_O2'},
            ),
          ],
        ),
      );

      expect(choices.visibleOptions, hasLength(3));
      expect(
        choices.visualStateFor('S1A5R02_O2'),
        AdaptiveOptionVisualState.disabled,
      );
    },
  );

  test('the same action is idempotent', () {
    final choices = controller();
    const plan = ScaffoldPlan(
      actionId: 'plan-idempotent',
      commands: <ScaffoldCommand>[
        ScaffoldCommand(
          actionId: 'remove-once',
          type: ScaffoldActionType.removeOptions,
          targetOptionIds: <String>{'S2A1R01_O2'},
        ),
      ],
    );
    choices.applyPlan(plan);
    final repeated = choices.applyPlan(plan);
    expect(choices.visibleOptions, hasLength(3));
    expect(repeated.rejectedReasons, contains('DUPLICATE_ACTION:remove-once'));
  });

  test('reveals the next sequence token as a visible hint', () {
    final choices = controller();
    final report = choices.applyPlan(
      const ScaffoldPlan(
        actionId: 'reveal-plan',
        commands: <ScaffoldCommand>[
          ScaffoldCommand(
            actionId: 'reveal-first-token',
            type: ScaffoldActionType.revealFirstToken,
            targetOptionIds: <String>{'S2A1R01_O1'},
          ),
        ],
      ),
    );

    expect(report.appliedOptionIds, contains('S2A1R01_O1'));
    expect(
      choices.visualStateFor('S2A1R01_O1'),
      AdaptiveOptionVisualState.hint,
    );
  });

  testWidgets('answer pool rebuilds from visible options and closes the gap', (
    tester,
  ) async {
    final choices = controller();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: AdaptiveAnswerPool<String>(
              controller: choices,
              animationDuration: Duration.zero,
              itemBuilder: (context, option, state, extent) =>
                  SizedBox(width: extent, child: Text(option.value)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('ග'), findsOneWidget);

    choices.applyPlan(
      const ScaffoldPlan(
        actionId: 'ui-plan',
        commands: <ScaffoldCommand>[
          ScaffoldCommand(
            actionId: 'ui-remove',
            type: ScaffoldActionType.removeOptions,
            targetOptionIds: <String>{'S2A1R01_O2'},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ග'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
    expect(choices.visibleOptions, hasLength(3));
  });
}
