import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/controllers/adaptive_task_coordinator.dart';
import 'package:sipsara_app/models/curriculum_models.dart';

void main() {
  final raw =
      jsonDecode(File('assets/data/curriculum/skill_4.json').readAsStringSync())
          as List<dynamic>;
  final root = Map<String, dynamic>.from(raw.single as Map);
  final activityJson = Map<String, dynamic>.from(
    (root['activities'] as List<dynamic>).firstWhere(
          (value) => (value as Map)['id'] == 'act_2',
        )
        as Map,
  );
  final activity = ActivityNode.fromJson(activityJson)..skillId = 'skill_4';
  final rounds = (activityJson['rounds'] as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  Map<String, dynamic> resolve(String itemId) =>
      AdaptiveTaskCoordinator(activity: activity).resolveItem(itemId);

  test('Activity 2 uses the reviewed four-task progression', () {
    final expected = <String, (List<Object?>, String, String, int)>{
      'S4A2R01': (<Object?>[null, 'පායනවා'], 'ඉර', 'sun_shining.png', 2),
      'S4A2R01V2': (<Object?>[null, 'පායනවා'], 'හඳ', 'moon_shining.png', 2),
      'S4A2R02': (<Object?>[null, 'පිපෙනවා'], 'මල්', 'flower_blooming.png', 2),
      'S4A2R02V1': (<Object?>[null, 'දුවනවා'], 'බල්ලා', 'dog_running.png', 2),
      'S4A2R02V2': (<Object?>[null, 'නිදියනවා'], 'පූසා', 'cat_sleeping.png', 2),
      'S4A2R03': (
        <Object?>['පවනි', null, 'යනවා'],
        'පාසල්',
        'girl_going_to_school.png',
        3,
      ),
      'S4A2R03V1': (
        <Object?>[null, 'පියාඹනවා'],
        'කුරුල්ලා',
        'bird_flying.png',
        2,
      ),
      'S4A2R03V2': (
        <Object?>['නංගි', null, 'කියවනවා'],
        'පොතක්',
        'girl_reading_tree.jpg',
        3,
      ),
      'S4A2R04V1': (
        <Object?>[null, 'චිත්‍රයක්', 'අඳිනවා'],
        'මල්ලි',
        'boy_drawing.png',
        3,
      ),
      'S4A2R04V2': (
        <Object?>[null, 'කෑම', 'දෙනවා'],
        'බල්ලාට',
        'boy_feeding_dog.jpg',
        4,
      ),
    };

    for (final entry in expected.entries) {
      final item = resolve(entry.key);
      final (sequence, answer, imageName, optionCount) = entry.value;
      expect(item['item_id'], entry.key);
      expect(item['item_version'], 4);
      expect(item['sequence'], sequence);
      expect(item['correctOption'], answer);
      expect(item['image_url'].toString(), endsWith(imageName));
      expect(item['options'], hasLength(optionCount));
      expect(
        File(item['image_url'].toString()).existsSync(),
        isTrue,
        reason: entry.key,
      );
    }

    expect(rounds, hasLength(4));
    expect(rounds.last['item_id'], 'S4A2R04');
    expect(resolve('S4A2R05'), isEmpty);
  });

  test('Task 1 exposes one shared retry', () {
    final variants = (rounds.first['adaptive_variants'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final remediation = variants.first;
    final confirmation = variants.last;

    expect(remediation['item_id'], 'S4A2R01V1');
    expect(remediation['is_active'], isFalse);
    expect(confirmation['item_id'], 'S4A2R01V2');
    expect(confirmation['is_active'], isTrue);
    expect(remediation['single_floor_retry'], isTrue);
    expect(confirmation['single_floor_retry'], isTrue);
    expect(remediation['content'], confirmation['content']);
  });

  test('Task 2 retains separate floor remediation and confirmation', () {
    final task = rounds[1];
    final variants = (task['adaptive_variants'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();

    expect(task['has_reduced_remediation'], isFalse);
    expect(task['has_floor_remediation'], isTrue);
    expect(variants.first['content']['correctOption'], 'බල්ලා');
    expect(variants.last['content']['correctOption'], 'පූසා');
    expect(
      variants.first['content']['image_url'],
      isNot(variants.last['content']['image_url']),
    );
  });
}
