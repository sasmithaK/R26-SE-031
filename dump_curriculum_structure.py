import json
import glob

for f in sorted(glob.glob('app/frontend/assets/data/curriculum/skill_*.json')):
    with open(f, encoding='utf8') as file:
        data = json.load(file)
    print(f'\n--- {f} ---')
    for act in data[0]['activities']:
        print(f'Activity: {act.get("id")}, Template: {act.get("template_type")}, Rounds: {len(act.get("rounds", []))}')
        if act.get("rounds"):
            keys = list(act["rounds"][0].keys())
            print(f'  Round 1 keys: {keys}')
