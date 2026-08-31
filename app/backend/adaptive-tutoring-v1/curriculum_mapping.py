# curriculum_mapping.py
from typing import Dict, Any, Optional

# The frontend currently sends 'act_1', 'act_2' etc., which is ambiguous across the 4 skills.
# We define the ideal mapping keys here based on 'skill_X_act_Y' or 'X.Y'.
# We also provide a resolution helper that tries to parse various formats.

ACTIVITY_TO_KC = {
    # Skill 1
    "1.1": "KC_VISUAL_IDENTIFICATION",
    "1.2": "KC_VISUAL_MATCHING",
    "1.3": "KC_VISUAL_CATEGORIZATION",
    "1.4": "KC_VISUAL_PATTERN",
    "1.5": "KC_VISUAL_MEMORY",
    "skill_1_act_1": "KC_VISUAL_IDENTIFICATION",
    "skill_1_act_2": "KC_VISUAL_MATCHING",
    "skill_1_act_3": "KC_VISUAL_CATEGORIZATION",
    "skill_1_act_4": "KC_VISUAL_PATTERN",
    "skill_1_act_5": "KC_VISUAL_MEMORY",
    
    # Skill 2
    "2.1": "KC_LETTER_IDENTIFICATION",
    "2.2": "KC_LETTER_MATCHING",
    "2.3": "KC_PHONEME_LETTER_MAPPING",
    "2.4": "KC_LETTER_DECODING",
    "2.5": "KC_LETTER_MEMORY",
    "skill_2_act_1": "KC_LETTER_IDENTIFICATION",
    "skill_2_act_2": "KC_LETTER_MATCHING",
    "skill_2_act_3": "KC_PHONEME_LETTER_MAPPING",
    "skill_2_act_4": "KC_LETTER_DECODING",
    "skill_2_act_5": "KC_LETTER_MEMORY",
    
    # Skill 3
    "3.1": "KC_WORD_RECOGNITION",
    "3.2": "KC_WORD_FORMATION",
    "3.3": "KC_AUDITORY_WORD_RECOGNITION",
    "3.4": "KC_WORD_COMPLETION",
    "3.5": "KC_WORD_SEQUENCING",
    "skill_3_act_1": "KC_WORD_RECOGNITION",
    "skill_3_act_2": "KC_WORD_FORMATION",
    "skill_3_act_3": "KC_AUDITORY_WORD_RECOGNITION",
    "skill_3_act_4": "KC_WORD_COMPLETION",
    "skill_3_act_5": "KC_WORD_SEQUENCING",
    
    # Skill 4
    "4.1": "KC_SENTENCE_COMPREHENSION",
    "4.2": "KC_SENTENCE_COMPLETION",
    "4.3": "KC_AUDITORY_SENTENCE_RECOGNITION",
    "4.4": "KC_SENTENCE_SEQUENCING",
    "skill_4_act_1": "KC_SENTENCE_COMPREHENSION",
    "skill_4_act_2": "KC_SENTENCE_COMPLETION",
    "skill_4_act_3": "KC_AUDITORY_SENTENCE_RECOGNITION",
    "skill_4_act_4": "KC_SENTENCE_SEQUENCING",
}

KC_METADATA = {
    "KC_VISUAL_IDENTIFICATION": {"kc_id": "KC_VISUAL_IDENTIFICATION", "skill_id": "skill_1", "activity_id": "1.1", "description": "Identify pictures"},
    "KC_VISUAL_MATCHING": {"kc_id": "KC_VISUAL_MATCHING", "skill_id": "skill_1", "activity_id": "1.2", "description": "Match picture to shadow"},
    "KC_VISUAL_CATEGORIZATION": {"kc_id": "KC_VISUAL_CATEGORIZATION", "skill_id": "skill_1", "activity_id": "1.3", "description": "Sort pictures"},
    "KC_VISUAL_PATTERN": {"kc_id": "KC_VISUAL_PATTERN", "skill_id": "skill_1", "activity_id": "1.4", "description": "Complete pattern"},
    "KC_VISUAL_MEMORY": {"kc_id": "KC_VISUAL_MEMORY", "skill_id": "skill_1", "activity_id": "1.5", "description": "Memory game"},
    
    "KC_LETTER_IDENTIFICATION": {"kc_id": "KC_LETTER_IDENTIFICATION", "skill_id": "skill_2", "activity_id": "2.1", "description": "Identify target letter"},
    "KC_LETTER_MATCHING": {"kc_id": "KC_LETTER_MATCHING", "skill_id": "skill_2", "activity_id": "2.2", "description": "Match identical letters"},
    "KC_PHONEME_LETTER_MAPPING": {"kc_id": "KC_PHONEME_LETTER_MAPPING", "skill_id": "skill_2", "activity_id": "2.3", "description": "Listen and identify letter"},
    "KC_LETTER_DECODING": {"kc_id": "KC_LETTER_DECODING", "skill_id": "skill_2", "activity_id": "2.4", "description": "First/last letter decoding"},
    "KC_LETTER_MEMORY": {"kc_id": "KC_LETTER_MEMORY", "skill_id": "skill_2", "activity_id": "2.5", "description": "Letter pattern memory"},
    
    "KC_WORD_RECOGNITION": {"kc_id": "KC_WORD_RECOGNITION", "skill_id": "skill_3", "activity_id": "3.1", "description": "Choose word for picture"},
    "KC_WORD_FORMATION": {"kc_id": "KC_WORD_FORMATION", "skill_id": "skill_3", "activity_id": "3.2", "description": "Form word from letters"},
    "KC_AUDITORY_WORD_RECOGNITION": {"kc_id": "KC_AUDITORY_WORD_RECOGNITION", "skill_id": "skill_3", "activity_id": "3.3", "description": "Listen and identify word"},
    "KC_WORD_COMPLETION": {"kc_id": "KC_WORD_COMPLETION", "skill_id": "skill_3", "activity_id": "3.4", "description": "Fill missing letter"},
    "KC_WORD_SEQUENCING": {"kc_id": "KC_WORD_SEQUENCING", "skill_id": "skill_3", "activity_id": "3.5", "description": "Arrange letters into word"},
    
    "KC_SENTENCE_COMPREHENSION": {"kc_id": "KC_SENTENCE_COMPREHENSION", "skill_id": "skill_4", "activity_id": "4.1", "description": "Choose sentence for picture"},
    "KC_SENTENCE_COMPLETION": {"kc_id": "KC_SENTENCE_COMPLETION", "skill_id": "skill_4", "activity_id": "4.2", "description": "Fill missing word"},
    "KC_AUDITORY_SENTENCE_RECOGNITION": {"kc_id": "KC_AUDITORY_SENTENCE_RECOGNITION", "skill_id": "skill_4", "activity_id": "4.3", "description": "Listen and identify sentence"},
    "KC_SENTENCE_SEQUENCING": {"kc_id": "KC_SENTENCE_SEQUENCING", "skill_id": "skill_4", "activity_id": "4.4", "description": "Arrange words into sentence"},
}

import re

def resolve_canonical_activity(activity_id: str, item_id: str, skill_id: Optional[str] = None) -> Optional[str]:
    """
    Attempts to resolve the true canonical activity ID (e.g., '2.1').
    """
    # 1. Unambiguous
    if activity_id in ACTIVITY_TO_KC:
        return activity_id
    
    if re.match(r"^skill_\d+_act_\d+$", activity_id):
        return activity_id
        
    # 2. Ambiguous 'act_1' -> Check item_id (e.g. S2A1R01)
    if item_id:
        match = re.search(r"S(\d+)A(\d+)R", item_id, re.IGNORECASE)
        if match:
            return f"{match.group(1)}.{match.group(2)}"
            
    # 3. Handle frontend combined with skill_id (e.g., skill_id="skill_2", activity_id="act_2")
    if skill_id and skill_id.startswith("skill_") and activity_id.startswith("act_"):
        s_num = skill_id.split("_")[1]
        a_num = activity_id.split("_")[1]
        return f"{s_num}.{a_num}"
        
    return None

def resolve_knowledge_component(activity_id: str, item_id: str, provided_knowledge_component_id: str) -> str:
    """
    Resolves the official Knowledge Component for a given activity.
    Uses item_id to disambiguate 'act_1'.
    """
    canonical_act = resolve_canonical_activity(activity_id, item_id)
    
    if canonical_act and canonical_act in ACTIVITY_TO_KC:
        return ACTIVITY_TO_KC[canonical_act]
        
    # B. If the provided KC matches the official mapped KC list (it's already correct)
    if provided_knowledge_component_id in KC_METADATA:
        return provided_knowledge_component_id
        
    # D. Fallbacks
    old_to_new = {
        "KC_mirror_consonants": "KC_LETTER_IDENTIFICATION",
        "KC_LETTER_IDENTITY": "KC_LETTER_IDENTIFICATION"
    }
    
    if provided_knowledge_component_id in old_to_new:
        return old_to_new[provided_knowledge_component_id]
        
    return provided_knowledge_component_id

CURRICULUM_SEQUENCE = [
    "1.1", "1.2", "1.3", "1.4", "1.5",
    "2.1", "2.2", "2.3", "2.4", "2.5",
    "3.1", "3.2", "3.3", "3.4", "3.5",
    "4.1", "4.2", "4.3", "4.4"
]

def get_next_curriculum_activity(current_canonical_activity: str) -> Optional[str]:
    """
    Returns the next activity in the curriculum sequence.
    Returns None if the activity is unknown or if it's the final activity.
    """
    try:
        idx = CURRICULUM_SEQUENCE.index(current_canonical_activity)
        if idx + 1 < len(CURRICULUM_SEQUENCE):
            return CURRICULUM_SEQUENCE[idx + 1]
        return None
    except ValueError:
        return None
