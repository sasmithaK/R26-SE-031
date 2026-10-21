import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/models/starter_baseline_models.dart';
import 'package:sipsara_app/screens/starter_learning_profile_screen.dart';
import 'package:sipsara_app/services/starter_baseline_service.dart';

class FakeStarterRepository implements StarterBaselineRepository {
  var started = false;

  @override
  Future<StarterBaselineStatus> getStatus(String studentId) async {
    return const StarterBaselineStatus(
      status: 'not_started',
      required: true,
      sessionId: null,
      nextItemIndex: 0,
      completedItemCount: 0,
      totalItemCount: 8,
    );
  }

  @override
  Future<StarterBaselineStatus> start(
    String studentId,
    String sessionId,
  ) async {
    started = true;
    return StarterBaselineStatus(
      status: 'in_progress',
      required: true,
      sessionId: sessionId,
      nextItemIndex: 0,
      completedItemCount: 0,
      totalItemCount: 8,
    );
  }

  @override
  Future<StarterBaselineStatus> submitResponse(
    String studentId,
    Map<String, dynamic> response,
  ) async {
    return const StarterBaselineStatus(
      status: 'in_progress',
      required: true,
      sessionId: 'test-session',
      nextItemIndex: 1,
      completedItemCount: 1,
      totalItemCount: 8,
    );
  }
}

void main() {
  test('catalog has two versioned probes per skill', () {
    expect(starterBaselineTasks, hasLength(8));
    expect(
      starterBaselineTasks.map((task) => task.itemId).toSet(),
      hasLength(8),
    );
    for (var skill = 1; skill <= 4; skill++) {
      expect(
        starterBaselineTasks.where((task) => task.skillNumber == skill),
        hasLength(2),
      );
    }
    for (final task in starterBaselineTasks.where((task) => task.isSequence)) {
      expect(task.correctAnswerIds.length, greaterThan(1));
    }

    final treeTask = starterBaselineTasks.singleWhere(
      (task) => task.itemId == 'BL1S3W01',
    );
    expect(treeTask.choices.map((choice) => choice.id).toSet(), {
      'ගල',
      'ගස',
      'කට',
    });
    expect(treeTask.correctAnswerIds, ['ගස']);

    final wordSequenceTask = starterBaselineTasks.singleWhere(
      (task) => task.itemId == 'BL1S3W02',
    );
    expect(wordSequenceTask.prompt, 'ඇසෙන වචනය අකුරුවලින් සකසන්න.');
    expect(wordSequenceTask.helperText, isNull);

    final sentenceSequenceTask = starterBaselineTasks.singleWhere(
      (task) => task.itemId == 'BL1S4S02',
    );
    expect(sentenceSequenceTask.helperText, isNull);
  });

  test('a new sequence choice replaces the latest choice when full', () {
    expect(
      updateStarterSequenceSelection(
        currentSelection: const ['මා', 'ත'],
        tappedId: 'ල',
        requiredCount: 2,
      ),
      ['මා', 'ල'],
    );
    expect(
      updateStarterSequenceSelection(
        currentSelection: const ['පවනි', 'ගසට', 'යනවා'],
        tappedId: 'පාසල්',
        requiredCount: 3,
      ),
      ['පවනි', 'ගසට', 'පාසල්'],
    );
  });

  test('baseline option order is a stable per-learner permutation', () {
    for (final task in starterBaselineTasks) {
      final first = orderedStarterChoices(task, 'student-a');
      final repeated = orderedStarterChoices(task, 'student-a');
      expect(
        first.map((choice) => choice.id),
        repeated.map((choice) => choice.id),
      );
      expect(
        first.map((choice) => choice.id).toSet(),
        task.choices.map((choice) => choice.id).toSet(),
      );
    }
  });

  test('audio letter probe uses one clear instruction', () {
    final task = starterBaselineTasks.singleWhere(
      (task) => task.itemId == 'BL1S2L02',
    );
    expect(task.spokenPrompt, 'කා අකුර තෝරන්න.');
  });

  test('only terminal states bypass the starter profile', () {
    for (final status in ['completed', 'insufficient', 'not_required']) {
      expect(
        StarterBaselineStatus(
          status: status,
          required: true,
          sessionId: null,
          nextItemIndex: 0,
          completedItemCount: 0,
          totalItemCount: 8,
        ).isTerminal,
        isTrue,
      );
    }
    expect(
      const StarterBaselineStatus(
        status: 'in_progress',
        required: true,
        sessionId: 'session',
        nextItemIndex: 2,
        completedItemCount: 2,
        totalItemCount: 8,
      ).isTerminal,
      isFalse,
    );
    expect(
      const StarterBaselineStatus(
        status: 'declined',
        required: true,
        sessionId: null,
        nextItemIndex: 0,
        completedItemCount: 0,
        totalItemCount: 8,
      ).isTerminal,
      isFalse,
    );
  });

  testWidgets('completed baseline shows the standard completion content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: StarterLearningProfileScreen(
          studentData: const {
            'id': 'student-complete',
            'first_name': 'ඉසර',
            'avatar_url': 'assets/images/characters/human/human_student_3.png',
          },
          repository: FakeStarterRepository(),
          initialStatus: const StarterBaselineStatus(
            status: 'completed',
            required: false,
            sessionId: 'completed-session',
            nextItemIndex: 8,
            completedItemCount: 8,
            totalItemCount: 8,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('හරිම හොඳයි! 🌟'), findsOneWidget);
    expect(find.text('දැන් අපි ඉගෙනුම් ගමන පටන් ගමු.'), findsOneWidget);
    expect(find.text('මගේ ඉගෙනුම් පිටුවට යමු'), findsOneWidget);
    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    final completionAvatar = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('starter-complete-student-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (completionAvatar.image as AssetImage).assetName,
      'assets/images/characters/human/human_student_3.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exit dialog is clear and keeps the selected student avatar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: StarterLearningProfileScreen(
          studentData: const {
            'id': 'student-dialog',
            'first_name': 'පවනි',
            'avatar_url': 'assets/images/characters/human/human_student_3.png',
          },
          repository: FakeStarterRepository(),
          initialStatus: const StarterBaselineStatus(
            status: 'not_started',
            required: true,
            sessionId: null,
            nextItemIndex: 0,
            completedItemCount: 0,
            totalItemCount: 8,
          ),
        ),
      ),
    );
    await tester.pump();

    final introAvatar = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('starter-intro-student-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (introAvatar.image as AssetImage).assetName,
      'assets/images/characters/human/human_student_3.png',
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('දැන් මොකද කරන්නේ?'), findsOneWidget);
    expect(find.text('දැන් ඉතිරි ටික කරමු'), findsOneWidget);
    expect(find.text('පසුව කරමු'), findsOneWidget);
    expect(find.text('දැන් ඉගෙනුම් පිටුවට යමු'), findsNothing);
    expect(find.text('මේ වතාවේ මඟ හරින්න'), findsNothing);
    expect(
      find.byKey(const ValueKey('starter-exit-student-avatar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new learner sees intro and two practice examples before probes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeStarterRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: StarterLearningProfileScreen(
            studentData: const {'id': 'student-1', 'first_name': 'ඉසරා'},
            repository: repository,
            initialStatus: const StarterBaselineStatus(
              status: 'not_started',
              required: true,
              sessionId: null,
              nextItemIndex: 0,
              completedItemCount: 0,
              totalItemCount: 8,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('අපි විනෝදයෙන් ඉගෙන ගනිමු!'), findsNothing);
      expect(
        find.text('හොඳින් බලලා, අහලා, ඔයාට හිතෙන පිළිතුර තෝරන්න.'),
        findsOneWidget,
      );
      expect(find.text('වැරදුණත් කමක් නැහැ'), findsOneWidget);

      await tester.tap(find.text('අරඹමු  🚀'));
      await tester.pump();
      expect(repository.started, isTrue);
      expect(find.text('පුහුණු වීම'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('ඉදිරියට යමු'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('පුහුණු වීම'), findsOneWidget);
      expect(find.text('ගස උසයි'), findsOneWidget);

      await tester.tap(find.text('ගස'));
      await tester.tap(find.text('උසයි'));
      await tester.tap(find.text('ඉදිරියට යමු'));
      await tester.pump();
      expect(find.text('පින්තූර හඳුනාගැනීම'), findsOneWidget);
      expect(find.text('බල්ලා සොයා තෝරන්න.'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    },
  );

  testWidgets('practice never traps a child after two incorrect attempts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: StarterLearningProfileScreen(
          studentData: const {'id': 'student-retry', 'first_name': 'පවනි'},
          repository: FakeStarterRepository(),
          initialStatus: const StarterBaselineStatus(
            status: 'not_started',
            required: true,
            sessionId: null,
            nextItemIndex: 0,
            completedItemCount: 0,
            totalItemCount: 8,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('අරඹමු  🚀'));
    await tester.pump();

    // First miss receives one gentle retry.
    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('තවත් වරක් හොඳින් බලලා තෝරමු.'), findsOneWidget);

    // A second miss advances without revealing whether the answer was right.
    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ගස උසයි'), findsOneWidget);

    // Wrong order follows the same one-retry maximum.
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('උසයි'));
      await tester.tap(find.text('ගස'));
      await tester.tap(find.text('ඉදිරියට යමු'));
      await tester.pump();
    }
    expect(find.text('පින්තූර හඳුනාගැනීම'), findsOneWidget);
  });

  testWidgets(
    'image-to-text probe transition keeps finite animated constraints',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _TransitionStarterRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: StarterLearningProfileScreen(
            studentData: const {'id': 'student-2', 'first_name': 'පවනි'},
            repository: repository,
            initialStatus: const StarterBaselineStatus(
              status: 'in_progress',
              required: true,
              sessionId: 'transition-session',
              nextItemIndex: 1,
              completedItemCount: 1,
              totalItemCount: 8,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('අපි ඉතිරි ක්‍රීඩා කරමු!'), findsNothing);
      expect(find.text('ආයුබෝවන්, පවනි! නැවත හමුවීම සතුටක්.'), findsOneWidget);
      expect(
        find.text('ඔයා කරපු දේ සුරැකිලා තියෙනවා. ඉතිරි ටික මෙතැනින්ම කරමු.'),
        findsOneWidget,
      );
      await tester.tap(find.text('ඉතිරි ටික කරමු'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('සෙවණැලි ගැළපීම'), findsOneWidget);

      await tester.tap(find.text('අලියා'));
      await tester.pump();
      await tester.tap(find.text('ඉදිරියට'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('අකුරු හඳුනාගැනීම'), findsOneWidget);
      expect(find.text('අකුර තෝරන්න.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('baseline-target-letter')),
        findsOneWidget,
      );
      final letterCenters = ['ම', 'අ', 'ක']
          .map(
            (letter) =>
                tester.getCenter(find.byKey(ValueKey('BL1S2L01:$letter'))),
          )
          .toList();
      expect(
        letterCenters.every(
          (center) => (center.dy - letterCenters.first.dy).abs() < 0.1,
        ),
        isTrue,
      );
      expect(letterCenters.map((center) => center.dx).toSet(), hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('intro info pills fit without overflowing on a compact phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: StarterLearningProfileScreen(
          studentData: const {'id': 'student-compact', 'first_name': 'ඉසර'},
          repository: FakeStarterRepository(),
          initialStatus: const StarterBaselineStatus(
            status: 'not_started',
            required: true,
            sessionId: null,
            nextItemIndex: 0,
            completedItemCount: 0,
            totalItemCount: 8,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('පුංචි වැඩ 8ක්'), findsOneWidget);
    expect(find.text('වැරදුණත් කමක් නැහැ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task seven uses the available space for its prompt picture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: StarterLearningProfileScreen(
          studentData: const {'id': 'student-task-seven', 'first_name': 'ඉසර'},
          repository: FakeStarterRepository(),
          initialStatus: const StarterBaselineStatus(
            status: 'in_progress',
            required: true,
            sessionId: 'task-seven-session',
            nextItemIndex: 6,
            completedItemCount: 6,
            totalItemCount: 8,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ඉතිරි ටික කරමු'));
    await tester.pump();

    final pictureSize = tester.getSize(
      find.byKey(const ValueKey('baseline-prompt-image-BL1S4S01')),
    );
    expect(pictureSize.width, 210);
    expect(pictureSize.height, greaterThanOrEqualTo(190));
    expect(tester.takeException(), isNull);
  });

  testWidgets('task eight has a larger prompt picture without helper text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: StarterLearningProfileScreen(
          studentData: const {'id': 'student-task-eight', 'first_name': 'ඉසර'},
          repository: FakeStarterRepository(),
          initialStatus: const StarterBaselineStatus(
            status: 'in_progress',
            required: true,
            sessionId: 'task-eight-session',
            nextItemIndex: 7,
            completedItemCount: 7,
            totalItemCount: 8,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ඉතිරි ටික කරමු'));
    await tester.pump();

    expect(find.text('වචන තුන නිවැරදි පිළිවෙළට තෝරන්න.'), findsNothing);
    final pictureSize = tester.getSize(
      find.byKey(const ValueKey('baseline-prompt-image-BL1S4S02')),
    );
    expect(pictureSize.width, 190);
    expect(pictureSize.height, greaterThanOrEqualTo(155));
    expect(tester.takeException(), isNull);
  });
}

class _TransitionStarterRepository extends FakeStarterRepository {
  @override
  Future<StarterBaselineStatus> submitResponse(
    String studentId,
    Map<String, dynamic> response,
  ) async {
    return StarterBaselineStatus(
      status: 'in_progress',
      required: true,
      sessionId: response['session_id']?.toString(),
      nextItemIndex: 2,
      completedItemCount: 2,
      totalItemCount: 8,
    );
  }
}
