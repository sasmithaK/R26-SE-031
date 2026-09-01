import 'package:flutter/material.dart';
import '../../models/curriculum_models.dart';
import '../../widgets/telemetry_wrapper.dart';


// Picture Recognition (skill_visual) Games
import 'skill_1/visual_act1_hidden_search.dart';
import 'skill_1/visual_act4_pattern_adventure.dart';
import 'skill_1/visual_act3_sorting_adventure.dart';
import 'skill_1/visual_act2_shadow_matching.dart';
import 'skill_1/visual_act5_memory_hats.dart';

// Skill 3 Dedicated Templates
import 'skill_3/skill3_act1_image_mcq.dart';
import 'skill_3/skill3_act2_word_formation_mcq.dart';
import 'skill_3/skill3_act3_audio_mcq.dart';
import 'skill_3/skill3_act4_fill_blank.dart';
import 'skill_3/skill3_act5_jumbled_word.dart';

import 'skill_4/skill4_act1_mcq.dart';
import 'skill_4/skill4_act2_fill_blank.dart';
import 'skill_4/skill4_act3_mcq.dart';
import 'skill_4/skill4_act4_jumbled_sentence.dart';

import 'skill_5/skill5_act1_mcq.dart';
import 'skill_5/skill5_act2_mcq.dart';
import 'skill_5/skill5_act3_mcq.dart';
import 'skill_5/skill5_act4_mcq.dart';

// Skill 2 Dedicated Templates
import 'skill_2/skill2_act3_audio.dart';
import 'skill_2/skill2_act2_identical_match.dart';

import 'skill_2/skill2_act4_mcq.dart';
import 'skill_2/skill2_act1_odd_one_out.dart';
import 'skill_2/skill2_act5_pattern_memory.dart';

import 'shared_templates/interactive_story_game.dart';

/// Central factory for constructing dynamic game screen instances based on template_type.
class GameFactory {
  static Widget buildGame(ActivityNode node, {bool isRemedial = false, Map<String, dynamic>? studentData}) {
    Widget gameContent;

    switch (node.templateType) {
      
      // --- Skill 3 Dedicated Templates ---
      case 'skill3_image_mcq':
        gameContent = Skill3Act1ImageMcq(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill3_word_formation':
        gameContent = Skill3Act2WordFormation(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill3_audio_mcq':
        gameContent = Skill3Act3AudioMcq(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill3_fill_blank':
        gameContent = Skill3Act4FillBlank(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill3_jumbled_word':
        gameContent = Skill3Act5JumbledWord(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;

      // --- Skill 4 Dedicated Templates ---
      case 'skill4_act1_mcq':
        gameContent = Skill4Act1Mcq(activityNode: node, studentData: studentData);
        break;
      case 'skill4_act2_fill_blank':
        gameContent = Skill4Act2FillBlank(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill4_act3_mcq':
        gameContent = Skill4Act3Mcq(activityNode: node, studentData: studentData);
        break;
      case 'skill4_act4_jumbled_sentence':
        gameContent = Skill4Act4JumbledSentence(activityNode: node, studentData: studentData);
        break;

      // --- Skill 5 Dedicated Templates ---
      case 'skill5_act1_mcq':
        gameContent = Skill5Act1Mcq(activityNode: node, studentData: studentData);
        break;
      case 'skill5_act2_mcq':
        gameContent = Skill5Act2Mcq(activityNode: node, studentData: studentData);
        break;
      case 'skill5_act3_mcq':
        gameContent = Skill5Act3Mcq(activityNode: node, studentData: studentData);
        break;
      case 'skill5_act4_mcq':
        gameContent = Skill5Act4Mcq(activityNode: node, studentData: studentData);
        break;

      // --- Picture Recognition (skill_visual) Templates ---
      case 'visual_hidden_search':
        gameContent = VisualAct1HiddenSearch(activityNode: node, studentData: studentData);
        break;
      case 'visual_pattern_adventure':
        gameContent = VisualAct4PatternAdventure(activityNode: node, studentData: studentData);
        break;
      case 'visual_sorting_adventure':
        gameContent = VisualAct3SortingAdventure(activityNode: node, studentData: studentData);
        break;
      case 'visual_odd_one_out':
        gameContent = VisualAct2ShadowMatching(activityNode: node, studentData: studentData);
        break;
      case 'visual_memory_hats':
        gameContent = VisualAct5MemoryHats(activityNode: node, studentData: studentData);
        break;

      // --- Skill 2 Dedicated Templates ---
      case 'skill2_audio':
        gameContent = Skill2Act3Audio(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill2_identical_match':
        gameContent = Skill2Act2IdenticalMatch(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;

      case 'skill2_mcq':
        gameContent = Skill2Act4Mcq(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill2_odd_one_out':
        gameContent = Skill2Act1OddOneOut(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;
      case 'skill2_pattern_memory':
        gameContent = Skill2Act5PatternMemory(activityNode: node, isRemedial: isRemedial, studentData: studentData);
        break;

      // --- Interactive Story ---
      case 'interactive_story':
        gameContent = InteractiveStoryGame(activityNode: node);
        break;

      // Fallback for unhandled or removed template types
      default:
        gameContent = const Scaffold(body: Center(child: Text("Unknown Game Type")));
    }

    return TelemetryWrapper(
      studentData: studentData,
      activityNode: node,
      onRoundComplete: (score) {
        // Handled dynamically via TelemetryWrapperState
      },
      child: gameContent,
    );
  }
}