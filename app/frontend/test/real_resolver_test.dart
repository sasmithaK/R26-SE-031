import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/curriculum_models.dart';

void main() {
  group('Real JSON CanonicalItemResolver Tests', () {
    test('Verify against real JSON', () {
      final curriculumDir = Directory('assets/data/curriculum');
      final skills = ['skill_1', 'skill_2', 'skill_3', 'skill_4', 'skill_5', 'skill_6'];
      
      final reports = [];

      for (var skillName in skills) {
        final file = File('${curriculumDir.path}/$skillName.json');
        if (!file.existsSync()) continue;

        final content = file.readAsStringSync();
        final data = json.decode(content);
        
        final skill = SkillDetail.fromJson(data, skillName, skillName);
        
        for (var act in skill.activities) {
          for (var i = 0; i < act.rounds.length; i++) {
            final roundData = act.rounds[i];
            
            final resolved = CanonicalItemResolver.resolve(act, roundData, i);
            
            reports.add({
              'source_item_id': resolved.itemId,
              'skill_id': skill.id,
              'activity_id': act.id,
              'template_type': act.templateType,
              'targets': resolved.targets,
              'target_count': resolved.targets.length,
              'distractors': resolved.distractors,
              'difficulty_b': resolved.difficultyB,
              'is_anchor': resolved.isAnchor,
            });
          }
        }
      }
      
      final typesToPrint = [
        {'skill': 'skill_1', 'type': 'visual_hidden_search'},
        {'skill': 'skill_2', 'type': 'skill2_odd_one_out', 'multi': false},
        {'skill': 'skill_2', 'type': 'skill2_odd_one_out', 'multi': true},
        {'skill': 'skill_2', 'type': 'skill2_pattern_memory'},
        {'skill': 'skill_3', 'type': 'skill3_image_mcq'},
        {'skill': 'skill_3', 'type': 'skill3_fill_blank'},
        {'skill': 'skill_3', 'type': 'skill3_jumbled_word'},
        {'skill': 'skill_4', 'type': 'skill4_act4_jumbled_sentence'},
        {'skill': 'skill_5', 'type': 'skill5_act1_mcq'},
        {'skill': 'skill_6', 'type': 'interactive_story'}
      ];
      
      for (var req in typesToPrint) {
        final match = reports.firstWhere((r) {
          if (r['skill_id'] != req['skill']) return false;
          
          if (req['type'] == 'skill3_fill_blank') {
            if (!r['template_type'].toString().contains('fill_blank')) return false;
          } else if (req['type'] == 'skill5_act1_mcq') {
            if (!r['template_type'].toString().contains('skill5_act1_mcq')) return false;
          } else if (r['template_type'] != req['type']) {
            return false;
          }
          
          if (req['multi'] == true && (r['target_count'] as int) <= 1) return false;
          if (req['multi'] == false && (r['target_count'] as int) > 1) return false;
          
          return true;
        }, orElse: () => null);
        
        if (match != null) {
          print('---');
          print('source item_id: ${match["source_item_id"]}');
          print('skill_id: ${match["skill_id"]}');
          print('activity_id: ${match["activity_id"]}');
          print('template_type: ${match["template_type"]}');
          print('targets: ${match["targets"]}');
          print('target_count: ${match["target_count"]}');
          print('options (distractors): ${match["distractors"]}');
          print('difficulty_b: ${match["difficulty_b"]}');
          print('is_anchor: ${match["is_anchor"]}');
        }
      }
    });
  });
}
