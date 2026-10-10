"""Generate the reviewed Component 4 item variants for Skills 1-4.

This is a deterministic curriculum build step.  It snapshots the four Skill 1
runtime generators into the canonical curriculum and gives every core item two
unseen instructional equivalents:

* V1 - unseen remediation content at a valid lower task level, including the
  previous-round difficulty structure for Skill 2 Activity 1
* V2 - independent confirmation content at the original task load/difficulty

The generated JSON remains the runtime source for Flutter and the item-bank
source for the adaptive service, preventing frontend/backend content drift.
"""

from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Any, Callable, Dict, List


ROOT = Path(__file__).resolve().parents[2]
CURRICULUM = ROOT / "frontend" / "assets" / "data" / "curriculum"

ASSETS = [
    "animals/bird.png", "animals/butterfly.png", "animals/cat.png",
    "animals/cow.png", "animals/dog.png", "animals/elephant.png",
    "animals/fish.png", "animals/frog.png", "animals/rabbit.png",
    "animals/snail.png", "animals/turtle.png", "fruits_food/apple.png",
    "fruits_food/banana.png", "fruits_food/grapes.png",
    "fruits_food/ice_cream.png", "fruits_food/mango.png",
    "fruits_food/orange.png", "fruits_food/watermelon.png",
    "flowers/nil_manel.png", "flowers/nelum.png", "flowers/araliya.png",
    "flowers/wada_mal.png", "flowers/flower_05.png", "vehicles/airplane.png",
    "vehicles/bicycle.png", "vehicles/boat.png", "vehicles/train.png",
    "vehicles/van.png", "everyday_objects/book.png", "everyday_objects/key.png",
    "everyday_objects/bell.png", "everyday_objects/clock.png",
    "everyday_objects/hat.png", "everyday_objects/kite.png",
    "everyday_objects/umbrella.png", "everyday_objects/pencil.png",
]

# Ice cream remains a valid general-purpose visual item, but it must never be
# sampled into the semantic fruit category used by Skill 1 Activity 3.
FRUIT_ASSETS = [
    "fruits_food/apple.png",
    "fruits_food/banana.png",
    "fruits_food/grapes.png",
    "fruits_food/mango.png",
    "fruits_food/orange.png",
    "fruits_food/watermelon.png",
]

SKILL1_ACTIVITY_KCS = {
    1: "KC_VISUAL_IDENTIFICATION",
    2: "KC_VISUAL_MATCHING",
    3: "KC_VISUAL_CATEGORIZATION",
    4: "KC_VISUAL_PATTERN",
    5: "KC_VISUAL_MEMORY",
}

SKILL2_ACTIVITY_KCS = {
    1: "KC_LETTER_IDENTIFICATION",
    2: "KC_LETTER_MATCHING",
    3: "KC_PHONEME_LETTER_MAPPING",
    4: "KC_LETTER_DECODING",
    5: "KC_LETTER_MEMORY",
}

ASSET_NAMES = {
    "animals/bird.png": "කුරුල්ලා", "animals/butterfly.png": "සමනලයා",
    "animals/cat.png": "පූසා", "animals/cow.png": "එළදෙන",
    "animals/dog.png": "බල්ලා", "animals/elephant.png": "අලියා",
    "animals/fish.png": "මාළුවා", "animals/frog.png": "ගෙම්බා",
    "animals/rabbit.png": "හාවා", "animals/snail.png": "ගොළුබෙල්ලා",
    "animals/turtle.png": "ඉබ්බා", "fruits_food/apple.png": "ඇපල් ගෙඩිය",
    "fruits_food/banana.png": "කෙසෙල් ගෙඩිය", "fruits_food/grapes.png": "මිදි",
    "fruits_food/mango.png": "අඹ ගෙඩිය", "fruits_food/orange.png": "දොඩම් ගෙඩිය",
    "fruits_food/watermelon.png": "කොමඩු ගෙඩිය", "vehicles/boat.png": "ඔරුව",
    "vehicles/train.png": "දුම්රිය", "vehicles/van.png": "වෑන් රථය",
    "vehicles/airplane.png": "ගුවන් යානය", "vehicles/bicycle.png": "බයිසිකලය",
    "everyday_objects/book.png": "පොත", "everyday_objects/key.png": "යතුර",
    "everyday_objects/bell.png": "සීනුව", "everyday_objects/clock.png": "ඔරලෝසුව",
    "everyday_objects/hat.png": "තොප්පිය", "everyday_objects/kite.png": "සරුංගලය",
}


def canonical(value: str) -> str:
    compact = value.replace("_", "").replace("-", "")
    match = re.fullmatch(r"S(\d+)A(\d+)R(\d+)(V\d+)?", compact, re.I)
    if not match:
        return value
    return f"S{match.group(1)}A{match.group(2)}R{int(match.group(3)):02d}{match.group(4) or ''}".upper()


def skill2_activity1_prompt(targets: List[str]) -> str:
    if len(targets) <= 1:
        return f"'{targets[0]}' අකුර සොයන්න."
    if len(set(targets)) == 1:
        count_label = {2: "දෙක"}.get(len(targets), str(len(targets)))
        return f"'{targets[0]}' අකුරු {count_label} සොයන්න."
    joined = " සහ ".join(f"'{target}'" for target in targets)
    return f"{joined} අකුරු සොයන්න."


def metadata(round_number: int, difficulty: float, *, anchor: bool = False) -> Dict[str, Any]:
    return {
        "item_version": 2,
        "difficulty_label": "easy" if difficulty < -0.25 else "hard" if difficulty > 0.75 else "medium",
        "difficulty_b": difficulty,
        "is_anchor": anchor,
        "equivalent_group_id": "",
    }


def skill1_rounds() -> Dict[str, List[Dict[str, Any]]]:
    shadow_counts = [2, 3, 4, 5, 6]
    shadows = []
    for index, count in enumerate(shadow_counts):
        row = {"target_assets": ASSETS[index:index + count], "difficulty": index + 1}
        row.update(metadata(index + 1, [-1.0, -1.0, 0.0, 0.0, 1.0][index], anchor=index == 3))
        shadows.append(row)

    category_assets = {
        "animals": ASSETS[0:11],
        "fruits": FRUIT_ASSETS,
        "flowers": ASSETS[18:23],
        "vehicles": ASSETS[23:28],
    }
    category_labels = {"animals": "සතුන්", "fruits": "පලතුරු", "flowers": "මල්", "vehicles": "වාහන"}
    category_icons = {"animals": "animals/elephant.png", "fruits": "fruits_food/apple.png", "flowers": "flowers/nelum.png", "vehicles": "vehicles/van.png"}
    layouts = [(["animals", "fruits"], [2, 1]), (["vehicles", "flowers"], [2, 2]),
               (["animals", "fruits"], [3, 3]), (["animals", "fruits", "vehicles"], [2, 2, 2]),
               (["fruits", "vehicles", "flowers"], [3, 3, 3])]
    sorting = []
    for index, (categories, counts) in enumerate(layouts):
        selected = {key: category_assets[key][:counts[pos]] for pos, key in enumerate(categories)}
        row = {
            "categories": selected,
            "category_labels": {key: category_labels[key] for key in categories},
            "category_icons": {key: category_icons[key] for key in categories},
            "difficulty": index + 1,
        }
        row.update(metadata(index + 1, [-1.0, -1.0, 0.0, 0.0, 1.0][index], anchor=index == 3))
        sorting.append(row)

    structures = ["ABAB", "AABB", "ABCAB", "ABCDAB", "ABBCABBC"]
    option_counts = [2, 3, 3, 4, 4]
    patterns = []
    for index, structure in enumerate(structures):
        symbols = sorted(set(structure))
        mapping = {symbol: ASSETS[index * 4 + pos] for pos, symbol in enumerate(symbols)}
        full = [mapping[symbol] for symbol in structure]
        correct = full[-1]
        options = [correct]
        for asset in ASSETS[index * 4 + len(symbols):]:
            if asset not in options:
                options.append(asset)
            if len(options) == option_counts[index]:
                break
        row = {
            "sequence": [*full[:-1], None], "missing_index": len(full) - 1,
            "correct_answer": correct, "options": options, "difficulty": index + 1,
        }
        row.update(metadata(index + 1, [-1.0, -1.0, 0.0, 0.0, 1.0][index], anchor=index == 3))
        patterns.append(row)

    memory = []
    for index, (count, duration) in enumerate([(2, 6000), (3, 5000), (3, 4000), (4, 4000), (5, 4000)]):
        assets = ASSETS[index * 3:index * 3 + count]
        row = {"assets": assets, "target_asset": assets[index % count], "show_milliseconds": duration}
        row.update(metadata(index + 1, [-1.0, -1.0, 0.0, 0.0, 1.0][index], anchor=index == 3))
        memory.append(row)
    return {"act_2": shadows, "act_3": sorting, "act_4": patterns, "act_5": memory}


LETTER_SETS = [
    ("ක", ["ත", "ව", "ය", "ක"]), ("ග", ["ද", "න", "ග", "ර"]),
    ("ප", ["බ", "ම", "ය", "ප"]), ("ල", ["ව", "ර", "ල", "ස"]),
    ("න", ["ම", "න", "ත", "ද"]), ("ස", ["හ", "ව", "ස", "ර"]),
    ("ට", ["ඩ", "ත", "ට", "ප"]), ("බ", ["ප", "ම", "බ", "ද"]),
    ("ඉ", ["ඊ", "උ", "ඉ", "එ"]), ("උ", ["ඔ", "ඌ", "උ", "අ"]),
    ("එ", ["ඒ", "ඔ", "එ", "ඇ"]), ("හ", ["ස", "හ", "න", "ව"]),
    ("ච", ["ජ", "ට", "ච", "ක"]), ("ද", ["ත", "ධ", "ද", "න"]),
]

# Visual distractors for Skill 2 Activity 1. Every image inside a generated
# answer pool is different, and V1/V2 use disjoint, familiar Grade 1 images.
# This prevents location or repeated-picture memory from revealing the answer.
SKILL2_ACTIVITY1_ICONS = [
    "assets/images/activity_icons/animals/cat.png",
    "assets/images/activity_icons/animals/dog.png",
    "assets/images/activity_icons/animals/fish.png",
    "assets/images/activity_icons/animals/rabbit.png",
    "assets/images/activity_icons/fruits_food/banana.png",
    "assets/images/activity_icons/fruits_food/orange.png",
    "assets/images/activity_icons/everyday_objects/balloon.png",
    "assets/images/activity_icons/everyday_objects/book.png",
    "assets/images/activity_icons/vehicles/bus.png",
    "assets/images/activity_icons/vehicles/boat.png",
    "assets/images/activity_icons/nature/sun.png",
    "assets/images/activity_icons/nature/leaf.png",
]

# Reviewed Grade 1 Sinhala letter sets for Skill 2 Activity 1 equivalents.
# Each tuple is (target letters, distractor letters) for R1V1, R1V2, ... R7V2.
# Compound signs and visually complex conjuncts are deliberately excluded.
SKILL2_ACTIVITY1_SIMPLE_VARIANTS = [
    (["ක"], ["ත"]),
    (["ග"], ["න"]),
    (["ප"], ["බ"]),
    (["ල"], ["ව"]),
    (["න"], ["ම", "ත"]),
    (["ස"], ["හ", "ව"]),
    (["ට"], ["ත", "න"]),
    (["බ"], ["ප"]),
    (["ඉ"], ["උ"]),
    (["උ"], ["ඔ"]),
    (["එ", "එ"], ["අ"]),
    (["හ", "හ"], ["ස"]),
    (["ය", "ය"], ["ල"]),
    (["ද", "න"], ["ත"]),
]

# (image count, letter count, target count) for an easier V1 after each core
# round. R2-R7 deliberately reuse the preceding round's task structure. R1
# has no predecessor, so it uses a reviewed three-choice floor task.
SKILL2_ACTIVITY1_REMEDIATION_LAYOUTS = {
    1: (2, 1, 1),
    2: (3, 1, 1),
    3: (2, 2, 1),
    4: (1, 3, 1),
    5: (0, 4, 1),
    6: (0, 6, 1),
    7: (0, 6, 2),
}

PAIR_SETS = [
    ["ත", "ව"], ["ය", "ර"], ["ප", "ස"], ["අ", "ඉ"], ["ක", "ග", "ම"],
    ["ට", "ඩ", "න"], ["ක", "ග", "ත", "ද"], ["ප", "බ", "ම", "ය"],
    ["ක", "ග", "ට", "ඩ", "ත"], ["ද", "න", "ප", "බ", "ම"],
    ["ර", "ල", "ව", "ස"], ["අ", "ආ", "ඉ", "ඊ"],
    ["බ", "ප", "ල"], ["උ", "එ", "ඔ"],
]

# Reviewed Grade 1 matching tasks for Skill 2 Activity 2. Difficulty is a
# combination of pair count and orthographic complexity: a base letter is
# easier than a letter carrying a simple vowel sign (pilla). V1 follows the
# immediately preceding level; V2 keeps the failed core level with new text.
# The entries are ordered R1V1, R1V2, ... R5V2.
SKILL2_ACTIVITY2_VARIANTS = [
    ["ත", "ව"], ["ය", "ර"],
    ["ප", "ස"], ["ලා", "න"],
    ["පා", "ස"], ["ක", "මු", "ය"],
    ["ත", "නු", "ම"], ["ප", "බි", "ය", "කු"],
    ["ග", "ටි", "ව", "සු"], ["ද", "නා", "ප", "බු", "ම"],
]

# Reviewed phoneme-to-grapheme progression for Skill 2 Activity 3. R1-R2
# establish response-set size, while R3-R5 deliberately increase grapheme
# similarity as well as the number of choices. Each V1 uses the immediately
# preceding level and each V2 preserves the failed core level with a new
# target. Adjacent items never repeat a target, which also prevents a child
# from succeeding through short-term target memory.
SKILL2_ACTIVITY3_CORE_ITEMS = [
    ("අ", ["අ", "ආ"], "minimal_contrast_2"),
    ("ස", ["ය", "ස", "ර"], "distinct_graphemes_3"),
    ("බ", ["ප", "බ", "ම"], "confusable_graphemes_3"),
    ("ට", ["ඩ", "ට", "ත", "ද"], "confusable_graphemes_4"),
    ("ක", ["ග", "ක", "ච", "ජ", "ට"], "confusable_graphemes_5"),
]

# Ordered R1V1, R1V2, ... R5V2.
SKILL2_ACTIVITY3_VARIANTS = [
    ("න", ["න", "හ"], "minimal_contrast_2"),
    ("ග", ["ග", "ක"], "minimal_contrast_2"),
    ("ම", ["ම", "ය"], "minimal_contrast_2"),
    ("ල", ["ව", "ල", "ර"], "distinct_graphemes_3"),
    ("හ", ["අ", "හ", "උ"], "distinct_graphemes_3"),
    ("ද", ["ත", "ද", "න"], "confusable_graphemes_3"),
    ("ප", ["බ", "ප", "ම"], "confusable_graphemes_3"),
    ("ඩ", ["ට", "ඩ", "ත", "ද"], "confusable_graphemes_4"),
    ("ජ", ["ච", "ජ", "ට", "ඩ"], "confusable_graphemes_4"),
    ("ව", ["ර", "ව", "ය", "ල", "ස"], "confusable_graphemes_5"),
]

# Reviewed word-boundary progression for Skill 2 Activity 4. Each tuple is
# (word, instructional units, vowel-sign count, requested boundary, options).
# V1 follows the preceding level; V2 preserves the failed core level.
SKILL2_ACTIVITY4_CORE_ITEMS = [
    ("අත", ["අ", "ත"], 0, "first", ["අ", "ම"]),
    ("මල", ["ම", "ල"], 0, "first", ["ය", "ම", "ර"]),
    ("පොත", ["පො", "ත"], 1, "last", ["පො", "ව", "ත"]),
    ("අහස", ["අ", "හ", "ස"], 0, "last", ["අ", "හ", "ය", "ස"]),
    ("බල්ලා", ["බ", "ල්", "ලා"], 2, "both", ["ම", "ලා", "ඩ", "බ", "ඔ", "ය"]),
]

# Ordered R1V1, R1V2, ... R5V2.
SKILL2_ACTIVITY4_VARIANTS = [
    ("රස", ["ර", "ස"], 0, "first", ["න", "ර"]),
    ("ඉර", ["ඉ", "ර"], 0, "first", ["න", "ඉ"]),
    ("රට", ["ර", "ට"], 0, "first", ["ර", "ව"]),
    ("ගස", ["ග", "ස"], 0, "first", ["ය", "ග", "ත"]),
    ("ගම", ["ග", "ම"], 0, "first", ["බ", "ග", "ම"]),
    ("පාට", ["පා", "ට"], 1, "last", ["ත", "ඩ", "ට"]),
    ("රූප", ["රූ", "ප"], 1, "last", ["බ", "ම", "ප"]),
    ("පහන", ["ප", "හ", "න"], 0, "last", ["ප", "හ", "ය", "න"]),
    ("කඩය", ["ක", "ඩ", "ය"], 0, "last", ["ක", "ඩ", "ම", "ය"]),
    ("පුටුව", ["පු", "ටු", "ව"], 2, "both", ["ම", "පු", "ඩ", "ව", "ඔ", "ය"]),
]


# Reviewed memory/orthography progression for Skill 2 Activity 5. Each tuple
# is (word, instructional units, vowel-sign count, options, exposure seconds).
SKILL2_ACTIVITY5_CORE_ITEMS = [
    ("රට", ["ර", "ට"], 0, ["ර", "ට", "ම"], 6),
    ("මල්", ["ම", "ල්"], 1, ["ම", "ක්", "ල්"], 5),
    ("ගමන", ["ග", "ම", "න"], 0, ["ග", "ම", "ක", "න"], 5),
    ("ගසක්", ["ග", "ස", "ක්"], 1, ["ක්", "ස", "ට්", "ග"], 4),
    ("මිහිරි", ["මි", "හි", "රි"], 3, ["හි", "වි", "රි", "මි"], 4),
]

# Ordered R1V1, R1V2, ... R5V2. V1 follows the preceding structural level;
# V2 preserves the failed core level with a new, meaningful word.
SKILL2_ACTIVITY5_VARIANTS = [
    ("අත", ["අ", "ත"], 0, ["අ", "ත", "ක"], 8),
    ("ගස", ["ග", "ස"], 0, ["ග", "ස", "ක"], 6),
    ("ඉර", ["ඉ", "ර"], 0, ["ඉ", "ර", "ක"], 7),
    ("ගල්", ["ග", "ල්"], 1, ["ග", "ල්", "ත"], 5),
    ("කුඩ", ["කු", "ඩ"], 1, ["කු", "ඩ", "ය"], 7),
    ("කඩය", ["ක", "ඩ", "ය"], 0, ["ක", "ඩ", "ය", "ම"], 5),
    ("අහස", ["අ", "හ", "ස"], 0, ["අ", "හ", "ස", "ම"], 6),
    ("පනාව", ["ප", "නා", "ව"], 1, ["ප", "නා", "ව", "ක"], 4),
    ("තරුව", ["ත", "රු", "ව"], 1, ["ත", "රු", "ව", "ය"], 6),
    ("පුටුව", ["පු", "ටු", "ව"], 2, ["පු", "ටු", "ව", "ක"], 4),
]


def skill2_activity5_content(spec) -> Dict[str, Any]:
    word, pattern, pilla_count, options, show_seconds = spec
    return {
        "target_word": word,
        "pattern": list(pattern),
        "pilla_count": pilla_count,
        "options": list(options),
        "show_seconds": show_seconds,
    }


def skill2_activity4_content(spec) -> Dict[str, Any]:
    word, units, pilla_count, target_position, options = spec
    content = {
        "target_word": word,
        "word_units": list(units),
        "pilla_count": pilla_count,
        "target_position": target_position,
        "options": list(options),
    }
    if target_position == "both":
        targets = [units[0], units[-1]]
        content.update({
            "prompt": f"'{word}' යන වචනයේ මුල් සහ අග අකුරු තෝරන්න",
            "correct_indices": [options.index(target) for target in targets],
        })
    else:
        target = units[0] if target_position == "first" else units[-1]
        position_text = "මුල්" if target_position == "first" else "අග"
        content.update({
            "prompt": f"'{word}' යන වචනයේ {position_text} අකුර කුමක්ද?",
            "correctOption": target,
            "correct_index": options.index(target),
        })
    return content

WORD_PARTS = [
    (["අ", "ත"], "අත"), (["ග", "ස"], "ගස"), (["ඉ", "ර"], "ඉර"),
    (["ම", "ල"], "මල"), (["කු", "ඩ", "ය"], "කුඩය"),
    (["ක", "ඩ", "ය"], "කඩය"),
    (["ත", "රු", "ව"], "තරුව"), (["පු", "ටු", "ව"], "පුටුව"),
    (["ප", "හ", "න"], "පහන"), (["ප", "නා", "ව"], "පනාව"),
    (["බ", "ල්", "ලා"], "බල්ලා"), (["අ", "ක්", "කා"], "අක්කා"),
    (["කු", "රු", "ල්", "ලා"], "කුරුල්ලා"), (["පා", "ස", "ල"], "පාසල"),
]

PICTURE_WORDS = [
    ("assets/images/activity_icons/animals/cat.png", "පූසා"),
    ("assets/images/activity_icons/animals/dog.png", "බල්ලා"),
    ("assets/images/activity_icons/animals/fish.png", "මාළුවා"),
    ("assets/images/activity_icons/animals/bird.png", "කුරුල්ලා"),
    ("assets/images/activity_icons/fruits_food/apple.png", "ඇපල්"),
    ("assets/images/activity_icons/fruits_food/banana.png", "කෙසෙල්"),
    ("assets/images/activity_icons/fruits_food/mango.png", "අඹ"),
    ("assets/images/activity_icons/everyday_objects/book.png", "පොත"),
    ("assets/images/activity_icons/everyday_objects/hat.png", "තොප්පිය"),
    ("assets/images/activity_icons/everyday_objects/clock.png", "ඔරලෝසුව"),
    ("assets/images/activity_icons/vehicles/train.png", "දුම්රිය"),
    ("assets/images/activity_icons/vehicles/boat.png", "ඔරුව"),
    ("assets/images/activity_icons/vehicles/bicycle.png", "බයිසිකලය"),
    ("assets/images/activity_icons/nature/moon.png", "හඳ"),
]

SENTENCES = [
    ("assets/images/games/boy_drawing.png", "මල්ලි චිත්‍රයක් අඳිනවා."),
    ("assets/images/games/boy_flying_kite.png", "මල්ලි සරුංගලයක් යවනවා."),
    ("assets/images/games/boy_feeding_dog.jpg", "මල්ලි බල්ලාට කෑම දෙනවා."),
    ("assets/images/games/children_playing_ball.jpg", "ළමයි බෝල සෙල්ලම් කරනවා."),
    ("assets/images/games/girl_reading_tree.jpg", "නංගි පොතක් කියවනවා."),
    ("assets/images/games/girl_going_to_school.png", "නංගි පාසල් යනවා."),
    ("assets/images/games/flower_blooming.png", "මල් පිපෙනවා."),
    ("assets/images/games/moon_shining.png", "හඳ පායනවා."),
    ("assets/images/games/mother_cooking.png", "අම්මා කෑම උයනවා."),
    ("assets/images/games/rowing_boat.png", "තාත්තා ඔරුව පදිනවා."),
]


def rotate(values: List[Any], start: int, count: int) -> List[Any]:
    return [copy.deepcopy(values[(start + offset) % len(values)]) for offset in range(count)]


def unique_values(values: List[Any]) -> List[Any]:
    """Preserve display order while removing ambiguous duplicate choices."""
    result = []
    for value in values:
        if value not in result:
            result.append(copy.deepcopy(value))
    return result


def difficulty_label(difficulty: float) -> str:
    return "easy" if difficulty < -0.25 else "hard" if difficulty > 0.75 else "medium"


def _reduce_choice_options(content: Dict[str, Any]) -> bool:
    options = list(content.get("options") or [])
    if len(options) <= 2:
        return False

    correct_values: List[Any] = []
    if content.get("correctOption") is not None:
        correct_values.append(content["correctOption"])
    for index in content.get("correct_indices") or []:
        if 0 <= index < len(options):
            correct_values.append(options[index])
    if not correct_values and isinstance(content.get("correct_index"), int):
        index = content["correct_index"]
        if 0 <= index < len(options):
            correct_values.append(options[index])

    minimum = max(2, len(correct_values) + (1 if correct_values else 0))
    desired = max(minimum, len(options) - 1)
    kept: List[Any] = []
    for value in [*correct_values, *options]:
        if value not in kept:
            kept.append(value)
        if len(kept) == desired:
            break
    content["options"] = kept
    if content.get("correctOption") is not None:
        content["correct_index"] = kept.index(content["correctOption"])
    if content.get("correct_indices") is not None:
        content["correct_indices"] = [kept.index(value) for value in correct_values]
    return len(kept) < len(options)


def reduce_remediation_load(
    skill: int,
    activity: int,
    content: Dict[str, Any],
    core: Dict[str, Any],
) -> tuple[Dict[str, Any], bool]:
    """Reduce one valid cognitive-load dimension without making a task invalid."""
    easier = copy.deepcopy(content)

    if skill == 1 and activity == 1:
        old_targets = int(easier.get("target_count", 1))
        old_distractors = int(easier.get("distractor_count", 0))
        easier["target_count"] = max(1, old_targets - 1)
        easier["distractors"] = list(easier.get("distractors") or [])[:max(1, old_distractors - 2)]
        easier["distractor_count"] = len(easier["distractors"])
        return easier, (
            easier["target_count"] < old_targets
            or easier["distractor_count"] < old_distractors
        )

    if skill == 1 and activity == 2:
        assets = list(easier.get("target_assets") or [])
        if len(assets) <= 2:
            return easier, False
        easier["target_assets"] = assets[:-1]
        return easier, True

    if skill == 1 and activity == 3:
        categories = easier.get("categories") or {}
        candidates = [
            key for key, values in categories.items() if len(values) > 1
        ]
        if not candidates:
            return easier, False
        largest = max(candidates, key=lambda key: len(categories[key]))
        categories[largest] = list(categories[largest])[:-1]
        return easier, True

    if skill == 1 and activity == 5:
        assets = list(easier.get("assets") or [])
        reduced = len(assets) > 2
        if reduced:
            easier["assets"] = assets[:-1]
            if easier.get("target_asset") not in easier["assets"]:
                easier["target_asset"] = easier["assets"][0]
        easier["show_milliseconds"] = int(
            easier.get("show_milliseconds", 4000)
        ) + 2000
        return easier, True

    if skill == 2 and activity == 1:
        # variant_content already applies the reviewed previous-round layout.
        return easier, True

    if skill == 2 and activity == 2:
        # Activity 2 V1 is already authored at the preceding difficulty in
        # variant_content. R2 is easier through orthographic complexity even
        # though both levels contain two matching pairs.
        return easier, float(core.get("difficulty_b", -1.0)) > -1.0

    if skill == 2 and activity == 3:
        # Activity 3 V1 is authored at the preceding response-set and
        # distractor-similarity level in variant_content.
        return easier, float(core.get("difficulty_b", -1.0)) > -1.0

    if skill == 2 and activity == 4:
        # Activity 4 V1 is authored at the preceding word/pool complexity.
        return easier, float(core.get("difficulty_b", -1.0)) > -1.0

    if skill == 2 and activity == 5:
        # V1 is explicitly authored at the preceding memory/orthography level.
        return easier, True

    if (skill, activity) in {
        (1, 4),
        (3, 1), (3, 2), (3, 3), (3, 4),
        (4, 1), (4, 2), (4, 3),
    }:
        return easier, _reduce_choice_options(easier)

    # Jumbled-word and jumbled-sentence V1 content is generated at a shorter
    # valid length directly in variant_content.
    if skill == 3 and activity == 5:
        core_length = len(core.get("scrambled_letters") or [])
        return easier, core_length > 2
    if skill == 4 and activity == 4:
        core_length = len(core.get("scrambled_words") or [])
        return easier, core_length > 2

    return easier, False


def variant_content(skill: int, activity: int, round_index: int, variant: int, core: Dict[str, Any]) -> Dict[str, Any]:
    slot = (round_index - 1) * 2 + (variant - 1)
    option_count = len((core.get("content") or core).get("options") or [])

    if skill == 1 and activity == 1:
        target_count = int(core.get("target_count", 1))
        distractor_count = int(core.get("distractor_count", len(core.get("distractors", []))))
        target = ASSETS[(slot + 5) % len(ASSETS)]
        distractors = [asset for asset in rotate(ASSETS, slot + 11, distractor_count + 1) if asset != target][:distractor_count]
        name = ASSET_NAMES.get(target, "පින්තූරය")
        return {"targets": [target], "target_count": target_count, "distractors": distractors,
                "distractor_count": distractor_count, "instruction": f"{name} සොයන්න!"}

    if skill == 1 and activity == 2:
        count = len(core["target_assets"])
        return {"target_assets": rotate(ASSETS, 12 + slot * 3, count), "difficulty": core["difficulty"]}

    if skill == 1 and activity == 3:
        categories = list(core["categories"])
        shifted = {}
        source = {"animals": ASSETS[0:11], "fruits": FRUIT_ASSETS, "flowers": ASSETS[18:23], "vehicles": ASSETS[23:28]}
        for pos, category in enumerate(categories):
            count = len(core["categories"][category])
            shifted[category] = rotate(source[category], slot + pos + 2, count)
        return {**{key: copy.deepcopy(value) for key, value in core.items() if key not in {"categories", "adaptive_variants"}}, "categories": shifted}

    if skill == 1 and activity == 4:
        sequence = list(core["sequence"])
        unique = max(2, len({value for value in sequence if value is not None}))
        chosen = rotate(ASSETS, 10 + slot * 4, unique + len(core["options"]))
        old_values = []
        for value in sequence:
            if value is not None and value not in old_values:
                old_values.append(value)
        mapping = {value: chosen[pos] for pos, value in enumerate(old_values)}
        new_sequence = [mapping.get(value) if value is not None else None for value in sequence]
        correct = mapping[core["correct_answer"]]
        options = [correct]
        for value in chosen[unique:]:
            if value not in options:
                options.append(value)
            if len(options) == len(core["options"]):
                break
        return {"sequence": new_sequence, "missing_index": core["missing_index"], "correct_answer": correct,
                "options": options, "difficulty": core["difficulty"]}

    if skill == 1 and activity == 5:
        count = len(core["assets"])
        assets = rotate(ASSETS, 8 + slot * 3, count)
        return {"assets": assets, "target_asset": assets[(slot + 1) % count],
                "show_milliseconds": core["show_milliseconds"]}

    if skill == 2 and activity == 1:
        source = core.get("content") or core
        source_items = list(source.get("items", []))
        icon_count = sum(1 for item in source_items if item.get("type") == "icon")
        letter_count = len(source_items) - icon_count
        target_count = (
            sum(1 for item in source_items if item.get("is_target")) or 1
        )
        if variant == 1:
            icon_count, letter_count, target_count = (
                SKILL2_ACTIVITY1_REMEDIATION_LAYOUTS[round_index]
            )
        configured_targets, configured_distractors = (
            SKILL2_ACTIVITY1_SIMPLE_VARIANTS[slot]
        )
        rendered_targets = list(configured_targets[:target_count])
        while len(rendered_targets) < target_count:
            rendered_targets.append(rendered_targets[-1])
        letter_distractor_count = max(0, letter_count - target_count)
        icons = rotate(
            SKILL2_ACTIVITY1_ICONS,
            slot * 3,
            icon_count,
        )
        items = [
            {"type": "icon", "value": icon, "is_target": False}
            for icon in icons
        ]
        if icon_count > 0:
            letter_distractors = rotate(
                configured_distractors,
                0,
                letter_distractor_count,
            )
        else:
            letter_distractors = [
                configured_distractors[0]
            ] * letter_distractor_count
        items += [
            {"type": "letter", "value": value, "is_target": False}
            for value in letter_distractors
        ]
        items += [
            {"type": "letter", "value": value, "is_target": True}
            for value in rendered_targets
        ]
        return {
            "prompt": skill2_activity1_prompt(rendered_targets),
            "items": items,
        }

    if skill == 2 and activity == 2:
        return {"letters": list(SKILL2_ACTIVITY2_VARIANTS[slot])}

    if skill == 2 and activity == 3:
        target, options, _ = SKILL2_ACTIVITY3_VARIANTS[slot]
        return {
            "prompt": "ශබ්දයට සවන් දී අකුර තෝරන්න",
            "audio_text": target,
            "options": list(options),
            "correctOption": target,
            "correct_index": options.index(target),
        }

    if skill == 2 and activity == 4:
        return skill2_activity4_content(SKILL2_ACTIVITY4_VARIANTS[slot])

    if skill == 2 and activity == 5:
        return skill2_activity5_content(SKILL2_ACTIVITY5_VARIANTS[slot])

    if skill == 3 and activity == 1:
        image, target = PICTURE_WORDS[slot % len(PICTURE_WORDS)]
        count = option_count or 3
        labels = [entry[1] for entry in rotate(PICTURE_WORDS, slot + 1, count - 1)]
        options = [target, *[label for label in labels if label != target]][:count]
        return {"prompt": "පින්තූරයට ගැලපෙන වචනය තෝරන්න", "image_url": image,
                "options": options, "correctOption": target, "correct_index": options.index(target)}

    if skill == 3 and activity == 2:
        parts, target = WORD_PARTS[slot % len(WORD_PARTS)]
        count = option_count or 3
        other_words = [word for _, word in rotate(WORD_PARTS, slot + 1, count) if word != target]
        options = [target, *other_words][:count]
        joined = " + ".join(f"'{part}'" for part in parts)
        return {"prompt": f"{joined} එකතු වූ විට හැදෙන වචනය කුමක්ද?", "options": options,
                "correctOption": target, "correct_index": options.index(target)}

    if skill == 3 and activity == 3:
        _, target = WORD_PARTS[slot % len(WORD_PARTS)]
        count = option_count or 3
        others = [word for _, word in rotate(WORD_PARTS, slot + 2, count) if word != target]
        options = [target, *others][:count]
        return {"prompt": "ශබ්දයට සවන් දී නිවැරදි වචනය තෝරන්න", "audio_text": target,
                "options": options, "correctOption": target, "correct_index": options.index(target)}

    if skill == 3 and activity == 4:
        parts, word = WORD_PARTS[slot % len(WORD_PARTS)]
        blank = slot % len(parts)
        target = parts[blank]
        sequence = list(parts)
        sequence[blank] = None
        count = option_count or 3
        candidates = [target, "ක", "ම", "ය", "ව", "ස"]
        options = rotate(candidates, variant, count)
        if target not in options:
            options[-1] = target
        return {"prompt": f"'{word}' වචනයේ අඩු අකුර තෝරන්න", "sequence": sequence,
                "options": options, "correctOption": target, "correct_index": options.index(target)}

    if skill == 3 and activity == 5:
        core_length = len(core.get("scrambled_letters") or [])
        desired = max(2, core_length - 1) if variant == 1 else core_length
        eligible = [entry for entry in WORD_PARTS if len(entry[0]) == desired]
        parts, word = eligible[slot % len(eligible)]
        return {"prompt": "අකුරු පිළිවෙළට සකසා වචනය හදන්න", "correct_word": word,
                "scrambled_letters": list(reversed(parts))}

    if skill == 4 and activity == 1:
        image, sentence = SENTENCES[slot % len(SENTENCES)]
        count = option_count or 3
        others = [value for _, value in rotate(SENTENCES, slot + 1, count) if value != sentence]
        options = [sentence, *others][:count]
        return {"prompt": "පින්තූරයට ගැලපෙන වාක්‍යය තෝරන්න", "image_url": image,
                "options": options, "correctOption": sentence, "correct_index": options.index(sentence)}

    if skill == 4 and activity == 2:
        image, sentence = SENTENCES[slot % len(SENTENCES)]
        words = sentence.rstrip(".").split()
        blank = 0 if round_index <= 2 else min(1, len(words) - 1)
        target = words[blank]
        sequence: List[Any] = list(words)
        sequence[blank] = None
        count = option_count or 3
        distractors = ["පොත", "මල්", "කෑම", "පාසල්", "බෝලය", "හඳ"]
        options = [target, *[word for word in rotate(distractors, slot, count) if word != target]][:count]
        return {"prompt": "හිස්තැනට සුදුසු වචනය තෝරන්න", "sequence": sequence, "image_url": image,
                "options": options, "correctOption": target, "correct_index": options.index(target)}

    if skill == 4 and activity == 3:
        _, sentence = SENTENCES[slot % len(SENTENCES)]
        words = sentence.rstrip(".").split()
        count = option_count or 3
        wrong = [" ".join(reversed(words)) + "."]
        if len(words) >= 3:
            wrong.append(" ".join([words[1], words[0], *words[2:]]) + ".")
            wrong.append(" ".join([*words[:-2], words[-1], words[-2]]) + ".")
        options = [sentence, *wrong]
        while len(options) < count:
            options.append(SENTENCES[(slot + len(options)) % len(SENTENCES)][1])
        options = options[:count]
        return {"prompt": "ශබ්දයට සවන් දී නිවැරදි වාක්‍ය තෝරන්න", "audio_text": sentence,
                "options": options, "correctOption": sentence, "correct_index": options.index(sentence)}

    if skill == 4 and activity == 4:
        core_length = len((core.get("scrambled_words") or []))
        desired = max(2, core_length - 1) if variant == 1 else core_length
        eligible = [entry for entry in SENTENCES if len(entry[1].rstrip(".").split()) == desired]
        image, sentence = eligible[slot % len(eligible)]
        words = sentence.rstrip(".").split()
        return {"prompt": "පින්තූරයට අදාළ වාක්‍යය සාදන්න", "image_url": image,
                "correct_sentence": " ".join(words) + ".", "scrambled_words": list(reversed(words))}

    raise ValueError(f"No variant generator for Skill {skill} Activity {activity}")


def build() -> None:
    skill1 = skill1_rounds()
    for skill in range(1, 5):
        path = CURRICULUM / f"skill_{skill}.json"
        decoded = json.loads(path.read_text(encoding="utf-8"))
        root = decoded[0] if isinstance(decoded, list) else decoded
        for activity in root["activities"]:
            activity_number = int(re.search(r"\d+", activity["id"]).group())
            if skill == 1 and activity["id"] in skill1:
                activity["rounds"] = skill1[activity["id"]]
                activity["file_path"] = ""
            if skill == 1:
                research = activity.setdefault("research_metadata", {})
                research["knowledge_component_id"] = SKILL1_ACTIVITY_KCS[
                    activity_number
                ]
            elif skill == 2:
                research = activity.setdefault("research_metadata", {})
                research["knowledge_component_id"] = SKILL2_ACTIVITY_KCS[
                    activity_number
                ]
            rounds = activity.get("rounds") or activity.get("core_rounds") or []
            for round_index, round_data in enumerate(rounds, start=1):
                if skill == 2 and activity_number == 3:
                    target, options, strategy = (
                        SKILL2_ACTIVITY3_CORE_ITEMS[round_index - 1]
                    )
                    round_data.update({
                        "prompt": "ශබ්දයට සවන් දී අකුර තෝරන්න",
                        "audio_text": target,
                        "options": list(options),
                        "correctOption": target,
                        "correct_index": options.index(target),
                        "distractor_strategy": strategy,
                    })
                if skill == 2 and activity_number == 4:
                    content = skill2_activity4_content(
                        SKILL2_ACTIVITY4_CORE_ITEMS[round_index - 1]
                    )
                    for key in (
                        "prompt", "target_word", "word_units", "pilla_count",
                        "target_position", "options", "correctOption",
                        "correct_index", "correct_indices",
                    ):
                        round_data.pop(key, None)
                    round_data.update(content)
                    round_data["difficulty_features"] = {
                        "word_unit_count": len(content["word_units"]),
                        "pilla_count": content["pilla_count"],
                        "answer_pool_size": len(content["options"]),
                        "target_position": content["target_position"],
                    }
                if skill == 2 and activity_number == 5:
                    content = skill2_activity5_content(
                        SKILL2_ACTIVITY5_CORE_ITEMS[round_index - 1]
                    )
                    for key in (
                        "target_word", "pattern", "pilla_count", "options",
                        "show_seconds",
                    ):
                        round_data.pop(key, None)
                    round_data.update(content)
                    reviewed_difficulty = [-1.0, -0.5, 0.0, 0.5, 1.0][
                        round_index - 1
                    ]
                    round_data["difficulty_b"] = reviewed_difficulty
                    round_data["difficulty_label"] = difficulty_label(
                        reviewed_difficulty
                    )
                    round_data["difficulty_features"] = {
                        "pattern_length": len(content["pattern"]),
                        "pilla_count": content["pilla_count"],
                        "answer_pool_size": len(content["options"]),
                        "show_seconds": content["show_seconds"],
                    }
                item_id = canonical(round_data.get("item_id") or f"S{skill}A{activity_number}R{round_index:02d}")
                round_data["item_id"] = item_id
                round_data["item_version"] = (
                    6
                    if skill == 2 and activity_number == 4
                    else 3
                    if skill == 2 and activity_number == 5
                    else 3
                    if skill == 2 and activity_number == 3
                    else max(2, int(round_data.get("item_version", 1)))
                )
                round_data["equivalent_group_id"] = item_id
                if round_data.get("difficulty_b") is None:
                    round_data["difficulty_b"] = round(
                        -1.0 + (2.0 * (round_index - 1) / max(1, len(rounds) - 1)),
                        2,
                    )
                if not round_data.get("difficulty_label"):
                    difficulty = float(round_data["difficulty_b"])
                    round_data["difficulty_label"] = (
                        "easy" if difficulty < -0.25 else
                        "hard" if difficulty > 0.75 else "medium"
                    )
                round_data.setdefault("is_anchor", round_index == 4)
                variants = []
                has_reduced_remediation = False
                for variant_number, role in ((1, "REMEDIATION"), (2, "CONFIRMATION")):
                    content = variant_content(skill, activity_number, round_index, variant_number, round_data)
                    reduced = False
                    if variant_number == 1:
                        content, reduced = reduce_remediation_load(
                            skill, activity_number, content, round_data
                        )
                        has_reduced_remediation = reduced
                    variant_difficulty = float(round_data.get("difficulty_b", 0.0))
                    if variant_number == 1 and reduced:
                        if skill == 2 and activity_number in {1, 2, 3, 4, 5}:
                            variant_difficulty = (
                                max(-3.0, round(variant_difficulty - 0.5, 2))
                                if round_index == 1
                                else float(rounds[round_index - 2].get(
                                    "difficulty_b", variant_difficulty
                                ))
                            )
                        else:
                            variant_difficulty = max(
                                -3.0, round(variant_difficulty - 0.5, 2)
                            )
                    variant_record = {
                        "variant_id": f"V{variant_number}",
                        "item_id": f"{item_id}V{variant_number}",
                        # V1 now follows the preceding round's difficulty
                        # structure; V2 retains the current round structure.
                        # Version 5 separates this reviewed sequence from the
                        # superseded same-level V1 content.
                        "item_version": (
                            5 if skill == 2 and activity_number == 1
                            else 6 if skill == 2 and activity_number == 4
                            else 3 if skill == 2 and activity_number == 5
                            else 3 if skill == 2 and activity_number in {2, 3}
                            else 2
                        ),
                        "item_role": role,
                        "difficulty_b": variant_difficulty,
                        "difficulty_label": difficulty_label(variant_difficulty),
                        "response_load_relation": "reduced" if reduced else "equivalent",
                        "content": content,
                    }
                    if skill == 2 and activity_number == 3:
                        variant_record["distractor_strategy"] = (
                            SKILL2_ACTIVITY3_VARIANTS[
                                (round_index - 1) * 2 + (variant_number - 1)
                            ][2]
                        )
                    if skill == 2 and activity_number == 4:
                        variant_record["difficulty_features"] = {
                            "word_unit_count": len(content["word_units"]),
                            "pilla_count": content["pilla_count"],
                            "answer_pool_size": len(content["options"]),
                            "target_position": content["target_position"],
                        }
                    if skill == 2 and activity_number == 5:
                        variant_record["difficulty_features"] = {
                            "pattern_length": len(content["pattern"]),
                            "pilla_count": content["pilla_count"],
                            "answer_pool_size": len(content["options"]),
                            "show_seconds": content["show_seconds"],
                        }
                    if (
                        skill == 2
                        and activity_number in {1, 2, 3, 4, 5}
                        and variant_number == 1
                    ):
                        variant_record["remediation_source_round"] = (
                            round_index - 1 if round_index > 1 else None
                        )
                        variant_record["remediation_strategy"] = (
                            "PREVIOUS_DIFFICULTY_LEVEL"
                            if round_index > 1
                            else (
                                "FLOOR_REDUCED_CHOICES"
                                if activity_number == 1
                                else "FLOOR_EXTENDED_EXPOSURE"
                                if activity_number == 5
                                else "FLOOR_EQUIVALENT_TASK"
                            )
                        )
                    variants.append(variant_record)
                round_data["has_reduced_remediation"] = has_reduced_remediation
                if skill == 2 and activity_number == 4:
                    round_data["has_floor_remediation"] = round_index == 1
                else:
                    round_data.pop("has_floor_remediation", None)
                round_data.pop("has_equivalent_remediation", None)
                round_data["adaptive_variants"] = variants
        path.write_text(json.dumps(decoded, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    build()
