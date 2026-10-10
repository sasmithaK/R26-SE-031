import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/models/curriculum_models.dart';
import '../lib/screens/games/skill_2/skill2_round_resolver.dart';

void main() {
  late SkillDetail skill;

  setUpAll(() {
    final decoded = json.decode(
      File('assets/data/curriculum/skill_2.json').readAsStringSync(),
    );
    skill = SkillDetail.fromJson(decoded, 'skill_2', 'Skill 2');
    for (final activity in skill.activities) {
      activity.skillId = skill.id;
    }
  });

  test('all 81 Skill 2 core and equivalent items resolve exactly', () {
    var resolvedCount = 0;

    for (final activity in skill.activities) {
      for (
        var roundIndex = 0;
        roundIndex < activity.rounds.length;
        roundIndex++
      ) {
        final coreRound = activity.rounds[roundIndex];
        final coreDifficulty = (coreRound['difficulty_b'] as num).toDouble();
        final hasReducedRemediation =
            coreRound['has_reduced_remediation'] == true;

        for (final variantId in <String?>[null, 'V1', 'V2']) {
          final resolved = Skill2RoundResolver.resolve(
            activity: activity,
            roundIndex: roundIndex,
            variantId: variantId,
          );
          final expectedId = '${coreRound['item_id']}${variantId ?? ''}';
          expect(resolved.itemId, expectedId, reason: expectedId);
          expect(resolved.variantId, variantId, reason: expectedId);
          expect(resolved.data, isNotEmpty, reason: expectedId);

          final research = CanonicalItemResolver.resolveByItemId(
            activity,
            expectedId,
            roundIndex,
          );
          expect(research.itemId, expectedId, reason: expectedId);
          expect(research.targets, isNotEmpty, reason: expectedId);
          if (variantId == null) {
            expect(research.itemRole, 'CORE', reason: expectedId);
            expect(research.difficultyB, coreDifficulty, reason: expectedId);
          } else if (variantId == 'V1') {
            expect(research.itemRole, 'REMEDIATION', reason: expectedId);
            expect(
              research.difficultyB,
              hasReducedRemediation
                  ? activity.id == 'act_1'
                        ? lessThanOrEqualTo(coreDifficulty)
                        : lessThan(coreDifficulty)
                  : coreDifficulty,
              reason: expectedId,
            );
          } else {
            expect(research.itemRole, 'CONFIRMATION', reason: expectedId);
            expect(research.difficultyB, coreDifficulty, reason: expectedId);
          }

          _expectPlayableContent(activity.id, expectedId, resolved.data);
          resolvedCount++;
        }
      }
    }

    expect(resolvedCount, 81);
  });

  test(
    'item ID parsing keeps remediation and confirmation on their core dot',
    () {
      expect(Skill2RoundResolver.roundIndexFromItemId('S2A1R01V1'), 0);
      expect(Skill2RoundResolver.roundIndexFromItemId('S2A5R05V2'), 4);
      expect(Skill2RoundResolver.variantFromItemId('S2A1R01V1'), 'V1');
      expect(Skill2RoundResolver.variantFromItemId('S2A1R01V2'), 'V2');
      expect(Skill2RoundResolver.variantFromItemId('S2A1R02'), isNull);
    },
  );

  test(
    'autoplay gate keys playback by item identity instead of spoken text',
    () {
      final gate = Skill2ItemAutoplayGate();

      expect(gate.shouldPlay('S2A3R04'), isTrue);
      expect(gate.shouldPlay('S2A3R04'), isFalse);
      expect(gate.shouldPlay('S2A3R04V1'), isTrue);
      expect(gate.shouldPlay('S2A3R05'), isTrue);
    },
  );

  test('Activities 1 and 2 autoplay only their opening core task', () {
    expect(
      Skill2RoundResolver.shouldAutoplayActivityIntroduction(roundIndex: 0),
      isTrue,
    );
    expect(
      Skill2RoundResolver.shouldAutoplayActivityIntroduction(
        roundIndex: 0,
        variantId: 'V1',
      ),
      isFalse,
    );
    expect(
      Skill2RoundResolver.shouldAutoplayActivityIntroduction(roundIndex: 1),
      isFalse,
    );
  });

  test('audio readiness rejects stale playback and requires success', () {
    final readiness = Skill2PromptReadiness();

    readiness.prepare('S2A3R01');
    final staleToken = readiness.begin('S2A3R01');
    readiness.prepare('S2A3R02');
    expect(
      readiness.finish(
        itemId: 'S2A3R01',
        requestToken: staleToken,
        didPlay: true,
      ),
      isFalse,
    );
    expect(readiness.isReady, isFalse);

    final failedToken = readiness.begin('S2A3R02');
    expect(
      readiness.finish(
        itemId: 'S2A3R02',
        requestToken: failedToken,
        didPlay: false,
      ),
      isTrue,
    );
    expect(readiness.hasFailed, isTrue);
    expect(readiness.isReady, isFalse);

    final successfulToken = readiness.begin('S2A3R02');
    expect(
      readiness.finish(
        itemId: 'S2A3R02',
        requestToken: successfulToken,
        didPlay: true,
      ),
      isTrue,
    );
    expect(readiness.isReady, isTrue);
    expect(readiness.hasFailed, isFalse);
  });

  test('Activity 1 repeated targets retain distinct option identities', () {
    final activity = skill.activities.firstWhere(
      (candidate) => candidate.id == 'act_1',
    );

    final core = CanonicalItemResolver.resolveByItemId(activity, 'S2A1R06', 5);
    final remediation = CanonicalItemResolver.resolveByItemId(
      activity,
      'S2A1R07V1',
      6,
    );

    expect(core.targets, <String>['S2A1R06_O5', 'S2A1R06_O6']);
    expect(core.targets.toSet(), hasLength(2));
    expect(remediation.targets, <String>['S2A1R07V1_O5', 'S2A1R07V1_O6']);
    expect(remediation.targets.toSet(), hasLength(2));
  });

  test('multi-answer decoding records every correct target by index', () {
    final activity = skill.activities.firstWhere(
      (candidate) => candidate.id == 'act_4',
    );
    final research = CanonicalItemResolver.resolveByItemId(
      activity,
      'S2A4R05V2',
      4,
    );

    expect(research.targets, hasLength(2));
    expect(research.targets, containsAll(<String>['පු', 'ව']));
    expect(research.distractors, isNot(contains('ව')));
  });

  test('Activity 1 equivalents preserve each round image-letter family', () {
    final activity = skill.activities.firstWhere(
      (candidate) => candidate.id == 'act_1',
    );
    const expected = <String, (int, int)>{
      'S2A1R01': (3, 1),
      'S2A1R01V1': (2, 1),
      'S2A1R01V2': (3, 1),
      'S2A1R02': (2, 2),
      'S2A1R02V1': (3, 1),
      'S2A1R02V2': (2, 2),
      'S2A1R03': (1, 3),
      'S2A1R03V1': (2, 2),
      'S2A1R03V2': (1, 3),
      'S2A1R04': (0, 4),
      'S2A1R04V1': (1, 3),
      'S2A1R04V2': (0, 4),
      'S2A1R05': (0, 6),
      'S2A1R05V1': (0, 4),
      'S2A1R05V2': (0, 6),
      'S2A1R06': (0, 6),
      'S2A1R06V1': (0, 6),
      'S2A1R06V2': (0, 6),
      'S2A1R07': (0, 6),
      'S2A1R07V1': (0, 6),
      'S2A1R07V2': (0, 6),
    };
    for (final entry in expected.entries) {
      final roundIndex = Skill2RoundResolver.roundIndexFromItemId(entry.key)!;
      final resolved = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: Skill2RoundResolver.variantFromItemId(entry.key),
      );
      final choices = List<Map<String, dynamic>>.from(
        (resolved.data['items'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final iconCount = choices.where((item) => item['type'] == 'icon').length;
      final letterCount = choices
          .where((item) => item['type'] == 'letter')
          .length;

      expect((iconCount, letterCount), entry.value, reason: entry.key);
      expect(
        choices.where((item) => item['is_target'] == true),
        everyElement(
          predicate<Map<String, dynamic>>((item) => item['type'] == 'letter'),
        ),
        reason: entry.key,
      );
      final research = CanonicalItemResolver.resolveByItemId(
        activity,
        entry.key,
        roundIndex,
      );
      expect(
        research.itemVersion,
        entry.key.endsWith('V1') || entry.key.endsWith('V2') ? 5 : 2,
        reason: entry.key,
      );
    }
  });

  test('Activity 2 equivalents preserve pair count and pilla difficulty', () {
    final activity = skill.activities.firstWhere(
      (candidate) => candidate.id == 'act_2',
    );
    const coreSignatures = <(int, int)>[(2, 0), (2, 1), (3, 1), (4, 2), (5, 2)];
    const remediationSignatures = <(int, int)>[
      (2, 0),
      (2, 0),
      (2, 1),
      (3, 1),
      (4, 2),
    ];

    (int, int) signature(Map<String, dynamic> data) {
      final letters = List<String>.from(data['letters'] as List);
      return (
        letters.length,
        letters.where((letter) => letter.length > 1).length,
      );
    }

    for (var roundIndex = 0; roundIndex < 5; roundIndex++) {
      final core = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
      );
      final remediation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V1',
      );
      final confirmation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V2',
      );

      expect(signature(core.data), coreSignatures[roundIndex]);
      expect(signature(remediation.data), remediationSignatures[roundIndex]);
      expect(signature(confirmation.data), coreSignatures[roundIndex]);

      final coreRound = activity.rounds[roundIndex];
      for (final variant in coreRound['adaptive_variants'] as List) {
        expect((variant as Map)['item_version'], 3);
      }
      expect(coreRound['has_reduced_remediation'], roundIndex > 0);
    }
  });

  test('Activity 3 audio tasks preserve reviewed difficulty progression', () {
    final activity = skill.activities.firstWhere(
      (candidate) => candidate.id == 'act_3',
    );
    const coreSignatures = <(int, String)>[
      (2, 'minimal_contrast_2'),
      (3, 'distinct_graphemes_3'),
      (3, 'confusable_graphemes_3'),
      (4, 'confusable_graphemes_4'),
      (5, 'confusable_graphemes_5'),
    ];
    const remediationSignatures = <(int, String)>[
      (2, 'minimal_contrast_2'),
      (2, 'minimal_contrast_2'),
      (3, 'distinct_graphemes_3'),
      (3, 'confusable_graphemes_3'),
      (4, 'confusable_graphemes_4'),
    ];
    final presentedTargets = <String>[];

    (int, String) signature(Map<String, dynamic> round) {
      return (
        List<String>.from(round['options'] as List).length,
        round['distractor_strategy'] as String,
      );
    }

    for (var roundIndex = 0; roundIndex < 5; roundIndex++) {
      final coreRound = activity.rounds[roundIndex];
      final core = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
      );
      final remediation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V1',
      );
      final confirmation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V2',
      );
      final variants = List<Map<String, dynamic>>.from(
        (coreRound['adaptive_variants'] as List).map(
          (variant) => Map<String, dynamic>.from(variant as Map),
        ),
      );

      expect(signature(core.data), coreSignatures[roundIndex]);
      expect(
        signature(<String, dynamic>{
          ...remediation.data,
          'distractor_strategy': variants[0]['distractor_strategy'],
        }),
        remediationSignatures[roundIndex],
      );
      expect(
        signature(<String, dynamic>{
          ...confirmation.data,
          'distractor_strategy': variants[1]['distractor_strategy'],
        }),
        coreSignatures[roundIndex],
      );
      expect(coreRound['item_version'], 3);
      expect(variants.every((variant) => variant['item_version'] == 3), isTrue);

      presentedTargets.addAll(<String>[
        core.data['correctOption'] as String,
        remediation.data['correctOption'] as String,
        confirmation.data['correctOption'] as String,
      ]);
    }

    for (var index = 1; index < presentedTargets.length; index++) {
      expect(presentedTargets[index], isNot(presentedTargets[index - 1]));
    }
  });

  test('Activity 4 variants preserve reviewed word-boundary progression', () {
    final activity = skill.activities.firstWhere(
      (candidate) => candidate.id == 'act_4',
    );
    const coreSignatures = <(int, int, int, String, int)>[
      (2, 0, 2, 'first', 1),
      (2, 0, 3, 'first', 1),
      (2, 1, 3, 'last', 1),
      (3, 0, 4, 'last', 1),
      (3, 2, 6, 'both', 2),
    ];
    const remediationSignatures = <(int, int, int, String, int)>[
      (2, 0, 2, 'first', 1),
      (2, 0, 2, 'first', 1),
      (2, 0, 3, 'first', 1),
      (2, 1, 3, 'last', 1),
      (3, 0, 4, 'last', 1),
    ];
    final presentedWords = <String>[];

    (int, int, int, String, int) signature(Map<String, dynamic> data) {
      final indices = data['correct_indices'] is List
          ? List<int>.from(data['correct_indices'] as List)
          : <int>[data['correct_index'] as int];
      return (
        List<String>.from(data['word_units'] as List).length,
        data['pilla_count'] as int,
        List<String>.from(data['options'] as List).length,
        data['target_position'] as String,
        indices.length,
      );
    }

    for (var roundIndex = 0; roundIndex < 5; roundIndex++) {
      final coreRound = activity.rounds[roundIndex];
      final core = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
      );
      final remediation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V1',
      );
      final confirmation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V2',
      );
      final variants = List<Map<String, dynamic>>.from(
        (coreRound['adaptive_variants'] as List).map(
          (variant) => Map<String, dynamic>.from(variant as Map),
        ),
      );

      expect(signature(core.data), coreSignatures[roundIndex]);
      expect(signature(remediation.data), remediationSignatures[roundIndex]);
      expect(signature(confirmation.data), coreSignatures[roundIndex]);
      expect(coreRound['item_version'], 6);
      expect(variants.every((variant) => variant['item_version'] == 6), isTrue);

      presentedWords.addAll(<String>[
        core.data['target_word'] as String,
        remediation.data['target_word'] as String,
        confirmation.data['target_word'] as String,
      ]);
    }

    expect(presentedWords.toSet().length, presentedWords.length);

    final taskOneRemediation = Skill2RoundResolver.resolve(
      activity: activity,
      roundIndex: 0,
      variantId: 'V1',
    );
    expect(taskOneRemediation.data['target_word'], 'රස');
    expect(taskOneRemediation.data['word_units'], <String>['ර', 'ස']);
    expect(taskOneRemediation.data['pilla_count'], 0);
    expect(taskOneRemediation.data['options'], <String>['න', 'ර']);
    expect(taskOneRemediation.data['correctOption'], 'ර');

    final taskThreeRemediation = Skill2RoundResolver.resolve(
      activity: activity,
      roundIndex: 2,
      variantId: 'V1',
    );
    expect(taskThreeRemediation.data['target_word'], 'ගම');
    expect(taskThreeRemediation.data['word_units'], <String>['ග', 'ම']);
    expect(taskThreeRemediation.data['pilla_count'], 0);
    expect(taskThreeRemediation.data['options'], <String>['බ', 'ග', 'ම']);
    expect(taskThreeRemediation.data['correctOption'], 'ග');
  });

  test('Activity 5 variants preserve reviewed memory progression', () {
    final activity = skill.activities.firstWhere(
      (candidate) => candidate.id == 'act_5',
    );
    const coreSignatures = <(int, int, int, int)>[
      (2, 0, 3, 6),
      (2, 1, 3, 5),
      (3, 0, 4, 5),
      (3, 1, 4, 4),
      (3, 3, 4, 4),
    ];
    const remediationSignatures = <(int, int, int, int)>[
      (2, 0, 3, 8),
      (2, 0, 3, 7),
      (2, 1, 3, 7),
      (3, 0, 4, 6),
      (3, 1, 4, 6),
    ];
    const confirmationSignatures = <(int, int, int, int)>[
      (2, 0, 3, 6),
      (2, 1, 3, 5),
      (3, 0, 4, 5),
      (3, 1, 4, 4),
      (3, 2, 4, 4),
    ];
    const expectedRemediationB = <double>[-1.5, -1.0, -0.5, 0.0, 0.5];
    final presentedWords = <String>[];

    (int, int, int, int) signature(Map<String, dynamic> data) => (
      List<String>.from(data['pattern'] as List).length,
      data['pilla_count'] as int,
      List<String>.from(data['options'] as List).length,
      data['show_seconds'] as int,
    );

    for (var roundIndex = 0; roundIndex < 5; roundIndex++) {
      final coreRound = activity.rounds[roundIndex];
      final core = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
      );
      final remediation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V1',
      );
      final confirmation = Skill2RoundResolver.resolve(
        activity: activity,
        roundIndex: roundIndex,
        variantId: 'V2',
      );
      final variants = List<Map<String, dynamic>>.from(
        (coreRound['adaptive_variants'] as List).map(
          (variant) => Map<String, dynamic>.from(variant as Map),
        ),
      );

      expect(signature(core.data), coreSignatures[roundIndex]);
      expect(signature(remediation.data), remediationSignatures[roundIndex]);
      expect(signature(confirmation.data), confirmationSignatures[roundIndex]);
      expect(variants[0]['difficulty_b'], expectedRemediationB[roundIndex]);
      expect(variants[1]['difficulty_b'], coreRound['difficulty_b']);
      expect(coreRound['item_version'], 3);
      expect(variants.every((variant) => variant['item_version'] == 3), isTrue);
      presentedWords.addAll(<String>[
        core.data['target_word'] as String,
        remediation.data['target_word'] as String,
        confirmation.data['target_word'] as String,
      ]);
    }

    expect(presentedWords.toSet().length, presentedWords.length);
    expect(
      presentedWords,
      containsAll(<String>['ගල්', 'අහස', 'පනාව', 'තරුව', 'පුටුව']),
    );
  });
}

void _expectPlayableContent(
  String activityId,
  String itemId,
  Map<String, dynamic> data,
) {
  switch (activityId) {
    case 'act_1':
      final items = List<Map<String, dynamic>>.from(
        (data['items'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      expect(items, isNotEmpty, reason: itemId);
      expect(
        items.any((item) => item['is_target'] == true),
        isTrue,
        reason: itemId,
      );
      break;
    case 'act_2':
      final letters = List<String>.from(data['letters'] as List);
      expect(letters, isNotEmpty, reason: itemId);
      expect(letters.toSet().length, letters.length, reason: itemId);
      break;
    case 'act_3':
    case 'act_4':
      final options = List<String>.from(data['options'] as List);
      expect(options, isNotEmpty, reason: itemId);
      expect(options.toSet().length, options.length, reason: itemId);
      final indices = data['correct_indices'] is List
          ? List<int>.from(data['correct_indices'] as List)
          : <int>[data['correct_index'] as int];
      expect(indices, isNotEmpty, reason: itemId);
      expect(
        indices.every((index) => index >= 0 && index < options.length),
        isTrue,
        reason: itemId,
      );
      if (data['correctOption'] != null) {
        expect(options[indices.first], data['correctOption'], reason: itemId);
      }
      break;
    case 'act_5':
      final pattern = List<String>.from(data['pattern'] as List);
      final options = List<String>.from(data['options'] as List);
      expect(pattern, isNotEmpty, reason: itemId);
      expect(options.toSet().length, options.length, reason: itemId);
      expect(pattern.every(options.contains), isTrue, reason: itemId);
      break;
    default:
      fail('Unexpected Skill 2 activity $activityId');
  }
}
