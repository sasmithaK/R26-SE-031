class SkillRegistry {
  static const Map<String, List<String>> skillHierarchy = {
    'Skill_1_Letter_Sound': [
      'skill1_act1_catch_letter',
      'skill1_act2_identify_sound',
      'skill1_act3_match_audio'
    ],
    'Skill_2_Visual_Discrimination': [
      'skill2_act1_odd_one_out',
      'skill2_act2_hidden_search',
      'skill2_act3_shadow_match'
    ],
    'Skill_3_Phonological_Awareness': [
      'skill3_act1_rhyming_words',
      'skill3_act2_syllable_split',
      'skill3_act3_blend_sounds'
    ],
    'Skill_4_Reading_Fluency': [
      'skill4_act1_read_aloud',
      'skill4_act2_speed_read',
      'skill4_act3_comprehension'
    ]
  };

  static const Map<String, String> skillNames = {
    'Skill_1_Letter_Sound': 'Letter & Sound Recognition',
    'Skill_2_Visual_Discrimination': 'Visual Discrimination',
    'Skill_3_Phonological_Awareness': 'Phonological Awareness',
    'Skill_4_Reading_Fluency': 'Reading Fluency & Comprehension'
  };

  static String getSkillName(String skillId) {
    return skillNames[skillId] ?? skillId;
  }
}
