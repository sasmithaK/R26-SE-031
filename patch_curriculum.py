import json
import os

def patch_skill(file_name, skill_rules):
    path = os.path.join('app/frontend/assets/data/curriculum', file_name)
    with open(path, 'r', encoding='utf8') as f:
        data = json.load(f)
    
    skill = data[0]
    skill_num = file_name.replace('skill_', '').replace('.json', '')
    
    for act_idx, act in enumerate(skill['activities']):
        act_id = act['id']
        rules = skill_rules.get(act_id, {})
        
        # Add research_metadata to activity
        act['research_metadata'] = {
            'knowledge_component_id': rules.get('kc', 'KC_UNKNOWN'),
            'prompt_modality': rules.get('prompt', 'visual'),
            'response_modality': rules.get('response', 'tap'),
            'research_role': rules.get('role', 'primary')
        }
        
        # Add item metadata to rounds
        if 'rounds' in act:
            for r_idx, r in enumerate(act['rounds']):
                diff_b = 0.0
                diff_label = "medium"
                if r_idx < len(act['rounds']) / 3:
                    diff_b = -1.0
                    diff_label = "easy"
                elif r_idx >= 2 * len(act['rounds']) / 3:
                    diff_b = 1.0
                    diff_label = "hard"
                
                is_anchor = (r_idx % 4 == 3) # Every 4th item is anchor

                item_id = f"S{skill_num}_A{act_idx+1}_R{(r_idx+1):02d}"
                r['item_id'] = item_id
                r['item_version'] = 1
                r['difficulty_label'] = diff_label
                r['difficulty_b'] = diff_b
                r['is_anchor'] = is_anchor
                
    with open(path, 'w', encoding='utf8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Patched {file_name}")

rules = {
    'skill_1.json': {
        'act_1': {'kc': 'KC_VISUAL_SUPPORT', 'prompt': 'visual', 'response': 'tap', 'role': 'supportive'},
        'act_2': {'kc': 'KC_VISUAL_SUPPORT', 'prompt': 'visual', 'response': 'tap', 'role': 'supportive'},
        'act_3': {'kc': 'KC_VISUAL_SUPPORT', 'prompt': 'visual', 'response': 'drag', 'role': 'supportive'},
        'act_4': {'kc': 'KC_VISUAL_SUPPORT', 'prompt': 'visual', 'response': 'tap', 'role': 'supportive'},
        'act_5': {'kc': 'KC_VISUAL_SUPPORT', 'prompt': 'visual', 'response': 'tap', 'role': 'supportive'}
    },
    'skill_2.json': {
        'act_1': {'kc': 'KC_AKSHARA_IDENTITY', 'prompt': 'visual', 'response': 'tap', 'role': 'primary'},
        'act_2': {'kc': 'KC_AKSHARA_IDENTITY', 'prompt': 'visual', 'response': 'tap', 'role': 'primary'},
        'act_3': {'kc': 'KC_PHONEME_GRAPHEME', 'prompt': 'audio', 'response': 'tap', 'role': 'primary'},
        'act_4': {'kc': 'KC_AKSHARA_IDENTITY', 'prompt': 'visual_text', 'response': 'tap', 'role': 'primary'},
        'act_5': {'kc': 'KC_ORTHOGRAPHIC_MEMORY', 'prompt': 'visual', 'response': 'sequence_tap', 'role': 'secondary'}
    },
    'skill_3.json': {
        'act_1': {'kc': 'KC_WORD_RECOGNITION', 'prompt': 'image', 'response': 'tap', 'role': 'primary'},
        'act_2': {'kc': 'KC_SPELLING_SEQUENCE', 'prompt': 'visual_text', 'response': 'tap', 'role': 'primary'},
        'act_3': {'kc': 'KC_WORD_RECOGNITION', 'prompt': 'audio', 'response': 'tap', 'role': 'primary'},
        'act_4': {'kc': 'KC_SPELLING_SEQUENCE', 'prompt': 'visual_text', 'response': 'tap', 'role': 'primary'},
        'act_5': {'kc': 'KC_SPELLING_SEQUENCE', 'prompt': 'image_text', 'response': 'drag', 'role': 'primary'}
    },
    'skill_4.json': {
        'act_1': {'kc': 'KC_SENTENCE_LANGUAGE', 'prompt': 'image', 'response': 'tap', 'role': 'secondary'},
        'act_2': {'kc': 'KC_SENTENCE_LANGUAGE', 'prompt': 'visual_text', 'response': 'tap', 'role': 'secondary'},
        'act_3': {'kc': 'KC_SENTENCE_LANGUAGE', 'prompt': 'audio', 'response': 'tap', 'role': 'secondary'},
        'act_4': {'kc': 'KC_SENTENCE_LANGUAGE', 'prompt': 'image_text', 'response': 'drag', 'role': 'secondary'}
    },
    'skill_5.json': {
        'act_1': {'kc': 'KC_READING_COMPREHENSION', 'prompt': 'visual_text', 'response': 'speech_and_tap', 'role': 'secondary'},
        'act_2': {'kc': 'KC_READING_COMPREHENSION', 'prompt': 'visual_text', 'response': 'speech_and_tap', 'role': 'secondary'},
        'act_3': {'kc': 'KC_READING_COMPREHENSION', 'prompt': 'visual_text', 'response': 'speech_and_tap', 'role': 'secondary'},
        'act_4': {'kc': 'KC_READING_COMPREHENSION', 'prompt': 'visual_text', 'response': 'speech_and_tap', 'role': 'secondary'}
    },
    'skill_6.json': {
        'act_1': {'kc': 'KC_ORAL_READING_FLUENCY', 'prompt': 'visual_text', 'response': 'speech', 'role': 'primary'},
        'act_2': {'kc': 'KC_READING_COMPREHENSION', 'prompt': 'visual_text', 'response': 'speech_and_tap', 'role': 'secondary'}
    }
}

for fname, skill_rules in rules.items():
    patch_skill(fname, skill_rules)
