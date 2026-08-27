import re

def deduplicate_keys(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    new_lines = []
    
    in_si = False
    in_en = False
    si_keys = set()
    en_keys = set()
    
    for line in lines:
        if "'si': {" in line:
            in_si = True
            in_en = False
        elif "'en': {" in line:
            in_si = False
            in_en = True
            
        # check for duplicate keys
        match = re.search(r"^\s*'([^']+)'\s*:", line)
        if match:
            key = match.group(1)
            if in_si:
                if key in si_keys:
                    print(f"Removing duplicate key in si: {key}")
                    continue
                si_keys.add(key)
            elif in_en:
                if key in en_keys:
                    print(f"Removing duplicate key in en: {key}")
                    continue
                en_keys.add(key)
        
        new_lines.append(line)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))

if __name__ == '__main__':
    deduplicate_keys('/Users/isara/4Y 2S/RP/R26-SE-031/app/frontend/lib/services/localization_service.dart')
