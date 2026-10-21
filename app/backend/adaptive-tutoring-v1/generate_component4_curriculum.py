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
import unicodedata
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

SKILL1_CATEGORY_ASSETS = {
    "animals": [asset for asset in ASSETS if asset.startswith("animals/")],
    "fruits": list(FRUIT_ASSETS),
    "flowers": [asset for asset in ASSETS if asset.startswith("flowers/")],
    "vehicles": [asset for asset in ASSETS if asset.startswith("vehicles/")],
}

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
    """Normalize curriculum item IDs to the canonical Component 4 format."""
    compact = value.replace("_", "").replace("-", "")
    match = re.fullmatch(r"S(\d+)A(\d+)R(\d+)(V\d+)?", compact, re.I)
    if not match:
        return value
    return f"S{match.group(1)}A{match.group(2)}R{int(match.group(3)):02d}{match.group(4) or ''}".upper()


def targeted_letter_variant_content(
    activity_number: int,
    core: Dict[str, Any],
    authored_variant: Dict[str, Any],
    *,
    confirmation: bool,
) -> Dict[str, Any]:
    """Create a reviewed-template task that retains the exact letter target.

    Only Skill 2's letter-safe templates use this helper. It never substitutes
    a word/sentence under an unrelated image. Word and sentence activities use
    pooled educator-authored near-transfer tasks instead.
    """
    content = copy.deepcopy(authored_variant)
    if activity_number == 1:
        core_targets = [
            str(item.get("value"))
            for item in core.get("items", [])
            if isinstance(item, dict) and item.get("is_target") is True
        ]
        if not core_targets:
            return content
        target_index = 0
        distractor_index = 0
        distractor_letters = [
            letter for _, pool in LETTER_SETS for letter in pool
            if letter not in core_targets
        ]
        if confirmation and distractor_letters:
            distractor_letters = distractor_letters[5:] + distractor_letters[:5]
        for item in content.get("items", []):
            if isinstance(item, dict) and item.get("is_target") is True:
                item["value"] = core_targets[target_index % len(core_targets)]
                target_index += 1
            elif (
                isinstance(item, dict)
                and item.get("type") == "letter"
                and distractor_letters
            ):
                item["value"] = distractor_letters[
                    distractor_index % len(distractor_letters)
                ]
                distractor_index += 1
        displayed_targets = core_targets[:max(1, target_index)]
        content["prompt"] = skill2_activity1_prompt(displayed_targets)
        return content

    if activity_number == 2:
        letters = list(core.get("letters") or [])
        if not letters:
            return content
        if confirmation:
            content["letters"] = list(reversed(letters))
        else:
            desired = max(2, min(len(letters), len(content.get("letters") or letters)))
            content["letters"] = letters[:desired]
        return content

    if activity_number == 3:
        target = str(core.get("correctOption") or core.get("audio_text") or "")
        if not target:
            return content
        old_target = str(content.get("correctOption") or "")
        desired_count = len(content.get("options") or [])
        options = []
        for option in content.get("options") or []:
            value = target if str(option) == old_target else str(option)
            if value not in options:
                options.append(value)
        fallback_letters = [
            letter for _, pool in LETTER_SETS for letter in pool
            if letter != target
        ]
        for letter in fallback_letters:
            if letter not in options:
                options.append(letter)
            if len(options) >= desired_count:
                break
        options = options[:desired_count]
        if target not in options:
            options[-1 if options else 0] = target
        content["options"] = options
        content["correctOption"] = target
        content["correct_index"] = options.index(target)
        content["audio_text"] = target
        # Keep the visible question identical to the reviewed core task. The
        # screen derives the spoken target from audio_text, so targeted
        # practice must not expose the answer in the question card.
        content["prompt"] = str(
            core.get("prompt") or "ශබ්දයට සවන් දී අකුර තෝරන්න"
        )
        return content

    return content


def _reviewed_asset_fill(
    *,
    count: int,
    required: List[str],
    excluded: List[str],
    seed: int,
    pool: List[str] | None = None,
) -> List[str]:
    """Return a deterministic reviewed asset set containing every requirement."""
    result: List[str] = []
    for asset in required:
        if asset and asset not in result:
            result.append(asset)
    candidates = list(pool or ASSETS)
    ordered = rotate(candidates, seed, len(candidates))
    for asset in [*ordered, *candidates]:
        if asset in result or asset in excluded:
            continue
        result.append(asset)
        if len(result) >= count:
            return result[:count]
    for asset in candidates:
        if asset not in result:
            result.append(asset)
        if len(result) >= count:
            break
    return result[:count]


def _targeted_pattern_content(
    base: Dict[str, Any],
    target: str,
    *,
    seed: int,
) -> Dict[str, Any]:
    """Create a pattern task that preserves one diagnosed visual target."""
    content = copy.deepcopy(base)
    sequence = list(content.get("sequence") or [])
    old_correct = str(content.get("correct_answer") or "")
    symbols: List[str] = []
    for value in sequence:
        if value is not None and str(value) not in symbols:
            symbols.append(str(value))
    mapping = {old_correct: target}
    fillers = _reviewed_asset_fill(
        count=max(0, len(symbols) - 1),
        required=[],
        excluded=[target],
        seed=seed,
    )
    filler_index = 0
    for symbol in symbols:
        if symbol == old_correct:
            continue
        mapping[symbol] = fillers[filler_index]
        filler_index += 1
    content["sequence"] = [
        mapping.get(str(value), value) if value is not None else None
        for value in sequence
    ]
    content["correct_answer"] = target
    option_count = len(content.get("options") or [])
    content["options"] = _reviewed_asset_fill(
        count=option_count,
        required=[target],
        excluded=[value for value in mapping.values() if value != target],
        seed=seed + 7,
    )
    content["targeted_unit"] = target
    return content


def targeted_skill1_variant_contents(
    activity_number: int,
    core: Dict[str, Any],
    remediation_base: Dict[str, Any],
    confirmation_base: Dict[str, Any],
    *,
    seed: int,
) -> List[tuple[str, Dict[str, Any], Dict[str, Any]]]:
    """Build exact-target Skill 1 practice from reviewed task structures.

    Each returned tuple is one diagnosed visual unit plus a lower-load
    remediation and an equivalent-load independent confirmation. No runtime
    task generation is required and every image comes from the reviewed bank.
    """
    results: List[tuple[str, Dict[str, Any], Dict[str, Any]]] = []

    if activity_number == 1:
        for target_index, target in enumerate(core.get("targets") or []):
            target = str(target)
            pair: List[Dict[str, Any]] = []
            for offset, base in enumerate((remediation_base, confirmation_base)):
                content = copy.deepcopy(base)
                distractor_count = int(content.get("distractor_count", 1))
                content["targets"] = [target]
                content["distractors"] = _reviewed_asset_fill(
                    count=distractor_count,
                    required=[],
                    excluded=[target],
                    seed=seed + target_index * 13 + offset * 5,
                )
                content["distractor_count"] = len(content["distractors"])
                content["instruction"] = (
                    f"{ASSET_NAMES.get(target, 'පින්තූරය')} සොයන්න!"
                )
                content["targeted_unit"] = target
                pair.append(content)
            results.append((target, pair[0], pair[1]))
        return results

    if activity_number == 2:
        core_assets = list(core.get("target_assets") or [])
        for target_index, raw_target in enumerate(core_assets):
            target = str(raw_target)
            pair = []
            for offset, base in enumerate((remediation_base, confirmation_base)):
                content = copy.deepcopy(base)
                desired = len(content.get("target_assets") or [])
                content["target_assets"] = _reviewed_asset_fill(
                    count=desired,
                    required=[target],
                    excluded=[asset for asset in core_assets if asset != target],
                    seed=seed + target_index * 17 + offset * 7,
                )
                content["targeted_unit"] = target
                pair.append(content)
            results.append((target, pair[0], pair[1]))
        return results

    if activity_number == 3:
        core_categories = core.get("categories") or {}
        all_core_assets = [
            str(asset)
            for assets in core_categories.values()
            for asset in assets
        ]
        target_index = 0
        for target_category, assets in core_categories.items():
            for raw_target in assets:
                target = str(raw_target)
                pair = []
                for offset, base in enumerate(
                    (remediation_base, confirmation_base)
                ):
                    content = copy.deepcopy(base)
                    base_categories = content.get("categories") or {}
                    targeted_categories: Dict[str, List[str]] = {}
                    for category, core_values in core_categories.items():
                        desired = max(
                            1,
                            len(
                                base_categories.get(category)
                                or core_values
                            ),
                        )
                        required = [target] if category == target_category else []
                        targeted_categories[category] = _reviewed_asset_fill(
                            count=desired,
                            required=required,
                            excluded=[
                                asset for asset in all_core_assets
                                if asset != target
                            ],
                            seed=(
                                seed
                                + target_index * 19
                                + offset * 7
                                + list(core_categories).index(category) * 3
                            ),
                            pool=SKILL1_CATEGORY_ASSETS.get(category, ASSETS),
                        )
                    content["categories"] = targeted_categories
                    content["targeted_unit"] = target
                    content["targeted_category"] = target_category
                    pair.append(content)
                results.append((target, pair[0], pair[1]))
                target_index += 1
        return results

    if activity_number == 4:
        target = str(core.get("correct_answer") or "")
        if target:
            results.append((
                target,
                _targeted_pattern_content(remediation_base, target, seed=seed),
                _targeted_pattern_content(
                    confirmation_base, target, seed=seed + 11
                ),
            ))
        return results

    if activity_number == 5:
        target = str(core.get("target_asset") or "")
        if not target:
            return results
        core_assets = list(core.get("assets") or [])
        pair = []
        for offset, base in enumerate((remediation_base, confirmation_base)):
            content = copy.deepcopy(base)
            desired = len(content.get("assets") or [])
            content["assets"] = _reviewed_asset_fill(
                count=desired,
                required=[target],
                excluded=[asset for asset in core_assets if asset != target],
                seed=seed + offset * 13,
            )
            content["target_asset"] = target
            content["targeted_unit"] = target
            pair.append(content)
        results.append((target, pair[0], pair[1]))
    return results


def skill2_activity1_prompt(targets: List[str]) -> str:
    """Create the Sinhala prompt for one or more target letters."""
    if len(targets) <= 1:
        return f"'{targets[0]}' අකුර සොයන්න."
    if len(set(targets)) == 1:
        count_label = {2: "දෙක"}.get(len(targets), str(len(targets)))
        return f"'{targets[0]}' අකුරු {count_label} සොයන්න."
    joined = " සහ ".join(f"'{target}'" for target in targets)
    return f"{joined} අකුරු සොයන්න."


def metadata(round_number: int, difficulty: float, *, anchor: bool = False) -> Dict[str, Any]:
    """Return shared research metadata for one authored core round."""
    return {
        "item_version": 2,
        "difficulty_label": "easy" if difficulty < -0.25 else "hard" if difficulty > 0.75 else "medium",
        "difficulty_b": difficulty,
        "is_anchor": anchor,
        "equivalent_group_id": "",
    }


def skill1_rounds() -> Dict[str, List[Dict[str, Any]]]:
    """Build the reviewed Skill 1 core-round content definitions."""
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


# Exact-target near-transfer tasks for Activity 4. Remediation retains the
# diagnosed boundary letter while reducing the word/pilla/answer-pool load;
# confirmation retains it at the origin round's load in a different familiar
# word. R5 is split by boundary because its UI can diagnose the next missing
# boundary (first, then last).
SKILL2_ACTIVITY4_TARGETED_VARIANTS = {
    (1, "අ"): (
        ("අඹ", ["අ", "ඹ"], 0, "first", ["අ", "ම"]),
        ("අල", ["අ", "ල"], 0, "first", ["ය", "අ"]),
    ),
    (2, "ම"): (
        ("මග", ["ම", "ග"], 0, "first", ["ම", "න"]),
        ("මඩ", ["ම", "ඩ"], 0, "first", ["ය", "ම", "ර"]),
    ),
    (3, "ත"): (
        ("තල", ["ත", "ල"], 0, "first", ["ත", "න", "ල"]),
        ("සිත", ["සි", "ත"], 1, "last", ["සි", "ව", "ත"]),
    ),
    (4, "ස"): (
        ("පස", ["ප", "ස"], 0, "last", ["ප", "ය", "ස"]),
        ("දවස", ["ද", "ව", "ස"], 0, "last", ["ද", "ව", "ය", "ස"]),
    ),
    (5, "බ"): (
        ("බලය", ["බ", "ල", "ය"], 0, "first", ["බ", "ම", "ඔ", "ය"]),
        ("බළලා", ["බ", "ළ", "ලා"], 1, "first", ["ම", "ලා", "ඩ", "බ", "ඔ", "ය"]),
    ),
    (5, "ලා"): (
        ("නටලා", ["න", "ට", "ලා"], 1, "last", ["න", "ම", "ඔ", "ලා"]),
        ("දුවලා", ["දු", "ව", "ලා"], 2, "last", ["ම", "ලා", "ඩ", "දු", "ඔ", "ය"]),
    ),
}


# Exact-token near-transfer tasks for Activity 5. Each pair contains the token
# that was expected at the moment of the sequence error. Remediation reduces
# surrounding complexity and/or increases exposure; confirmation restores the
# core load with a different meaningful word.
SKILL2_ACTIVITY5_TARGETED_VARIANTS = {
    (1, "ර"): (
        ("ඉර", ["ඉ", "ර"], 0, ["ඉ", "ර", "ක"], 8),
        ("රස", ["ර", "ස"], 0, ["ර", "ස", "ප"], 6),
    ),
    (1, "ට"): (
        ("අට", ["අ", "ට"], 0, ["අ", "ට", "ක"], 8),
        ("කට", ["ක", "ට"], 0, ["ක", "ට", "ම"], 6),
    ),
    (2, "ම"): (
        ("මල", ["ම", "ල"], 0, ["ම", "ල", "ක"], 7),
        ("මගේ", ["ම", "ගේ"], 1, ["ම", "ගේ", "ත"], 5),
    ),
    (2, "ල්"): (
        ("ගල්", ["ග", "ල්"], 1, ["ග", "ල්", "ත"], 7),
        ("කල්", ["ක", "ල්"], 1, ["ක", "ල්", "ම"], 5),
    ),
    (3, "ග"): (
        ("ගස", ["ග", "ස"], 0, ["ග", "ස", "ක"], 7),
        ("ගමට", ["ග", "ම", "ට"], 0, ["ග", "ම", "ට", "ව"], 5),
    ),
    (3, "ම"): (
        ("මල", ["ම", "ල"], 0, ["ම", "ල", "ක"], 7),
        ("මහත", ["ම", "හ", "ත"], 0, ["ම", "හ", "ත", "න"], 5),
    ),
    (3, "න"): (
        ("නල", ["න", "ල"], 0, ["න", "ල", "ක"], 7),
        ("නවය", ["න", "ව", "ය"], 0, ["න", "ව", "ය", "ම"], 5),
    ),
    (4, "ග"): (
        ("ගමට", ["ග", "ම", "ට"], 0, ["ග", "ම", "ට", "ව"], 6),
        ("ගලක්", ["ග", "ල", "ක්"], 1, ["ග", "ල", "ක්", "ට්"], 4),
    ),
    (4, "ස"): (
        ("සරම", ["ස", "ර", "ම"], 0, ["ස", "ර", "ම", "ක"], 6),
        ("රසක්", ["ර", "ස", "ක්"], 1, ["ර", "ස", "ක්", "ට්"], 4),
    ),
    (4, "ක්"): (
        ("රටක්", ["ර", "ට", "ක්"], 1, ["ර", "ට", "ක්", "ම"], 6),
        ("මලක්", ["ම", "ල", "ක්"], 1, ["ම", "ල", "ක්", "ට්"], 4),
    ),
    (5, "මි"): (
        ("මිදුල", ["මි", "දු", "ල"], 2, ["මි", "දු", "ල", "ක"], 6),
        ("මිනිසා", ["මි", "නි", "සා"], 3, ["මි", "නි", "සා", "වි"], 4),
    ),
    (5, "හි"): (
        ("හිනාව", ["හි", "නා", "ව"], 2, ["හි", "නා", "ව", "ක"], 6),
        ("හිතුවා", ["හි", "තු", "වා"], 3, ["හි", "තු", "වා", "රි"], 4),
    ),
    (5, "රි"): (
        ("රිදෙන", ["රි", "දෙ", "න"], 2, ["රි", "දෙ", "න", "ක"], 6),
        ("රිළවා", ["රි", "ළ", "වා"], 2, ["රි", "ළ", "වා", "මි"], 4),
    ),
}


def skill2_activity5_content(spec) -> Dict[str, Any]:
    """Expand an S2A5 reviewed word-pattern specification."""
    word, pattern, pilla_count, options, show_seconds = spec
    return {
        "target_word": word,
        "pattern": list(pattern),
        "pilla_count": pilla_count,
        "options": list(options),
        "show_seconds": show_seconds,
    }


def skill2_activity4_content(spec) -> Dict[str, Any]:
    """Expand an S2A4 reviewed first/last-letter specification."""
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


SKILL2_SIMPLE_BASE_UNITS = [
    "අ", "ඉ", "ක", "ග", "ත", "ද", "න", "ප", "බ", "ම", "ය", "ර", "ල", "ව", "ස", "හ", "ට",
]
SKILL2_SIMPLE_PILLA_UNITS = [
    "කා", "ගි", "ටු", "පා", "බි", "මු", "ලි", "දු", "නා", "සු",
]


def _has_pillam(value: str) -> bool:
    """Return whether Sinhala text contains a combining vowel mark."""
    return any(unicodedata.category(char).startswith("M") for char in value)


def _sinhala_letter_bases(value: str) -> set[str]:
    """Extract base Sinhala letters while excluding combining marks."""
    return {
        char
        for char in value
        if "SINHALA LETTER" in unicodedata.name(char, "")
    }


def _skill2_activity2_target_content(
    *,
    target: str,
    base: Dict[str, Any],
    core: Dict[str, Any],
    confirmation: bool,
    seed: int,
) -> Dict[str, Any]:
    """Keep one failed grapheme while lowering/restoring its context load.

    A pilla-bearing target is never simplified into another grapheme: the
    remediation still contains that exact form (for example `කා`) but pairs it
    with fewer and simpler unmodified letters. This is the distinction between
    *target difficulty* and the *surrounding task load* requested by the study.
    """
    count = max(2, len(base.get("letters") or []))
    core_letters = [str(value) for value in core.get("letters") or []]
    desired_pilla_count = (
        sum(1 for value in core_letters if _has_pillam(value))
        if confirmation
        else int(_has_pillam(target))
    )
    letters = [target]
    pillam_needed = max(0, desired_pilla_count - int(_has_pillam(target)))
    target_bases = _sinhala_letter_bases(target)
    pilla_pool = rotate(
        [
            value
            for value in SKILL2_SIMPLE_PILLA_UNITS
            if value != target
            and not target_bases.intersection(_sinhala_letter_bases(value))
        ],
        seed + 3,
        len(SKILL2_SIMPLE_PILLA_UNITS),
    )
    base_pool = rotate(
        [
            value
            for value in SKILL2_SIMPLE_BASE_UNITS
            if value != target
            and not target_bases.intersection(_sinhala_letter_bases(value))
        ],
        seed + 7,
        len(SKILL2_SIMPLE_BASE_UNITS),
    )
    for value in [*pilla_pool[:pillam_needed], *base_pool, *pilla_pool]:
        if value not in letters:
            letters.append(value)
        if len(letters) >= count:
            break
    # Change target position without changing content so confirmation cannot
    # be solved by remembering where the target appeared in remediation.
    if confirmation and len(letters) > 1:
        letters = [*letters[1:], letters[0]]
    return {"letters": letters[:count], "targeted_unit": target}


def targeted_skill2_variant_contents(
    activity_number: int,
    round_number: int,
    core: Dict[str, Any],
    remediation_base: Dict[str, Any],
    confirmation_base: Dict[str, Any],
    *,
    seed: int,
) -> List[tuple[str, Dict[str, Any], Dict[str, Any]]]:
    """Return educator-authored exact-target pairs for Skill 2 A2/A4/A5."""
    results: List[tuple[str, Dict[str, Any], Dict[str, Any]]] = []
    if activity_number == 2:
        for index, raw_target in enumerate(dict.fromkeys(core.get("letters") or [])):
            target = str(raw_target)
            results.append((
                target,
                _skill2_activity2_target_content(
                    target=target,
                    base=remediation_base,
                    core=core,
                    confirmation=False,
                    seed=seed + index * 17,
                ),
                _skill2_activity2_target_content(
                    target=target,
                    base=confirmation_base,
                    core=core,
                    confirmation=True,
                    seed=seed + index * 17 + 9,
                ),
            ))
        return results

    if activity_number == 4:
        for (mapped_round, target), pair in (
            SKILL2_ACTIVITY4_TARGETED_VARIANTS.items()
        ):
            if mapped_round != round_number:
                continue
            remediation = skill2_activity4_content(pair[0])
            confirmation = skill2_activity4_content(pair[1])
            remediation["targeted_unit"] = target
            confirmation["targeted_unit"] = target
            results.append((target, remediation, confirmation))
        return results

    if activity_number == 5:
        for (mapped_round, target), pair in (
            SKILL2_ACTIVITY5_TARGETED_VARIANTS.items()
        ):
            if mapped_round != round_number:
                continue
            remediation = skill2_activity5_content(pair[0])
            confirmation = skill2_activity5_content(pair[1])
            remediation["targeted_unit"] = target
            confirmation["targeted_unit"] = target
            results.append((target, remediation, confirmation))
    return results

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


def skill3_image_word(image: str, target: str, options: List[str]) -> Dict[str, Any]:
    """Build a Skill 3 image-to-word choice task."""
    return {
        "prompt": "පින්තූරයට ගැලපෙන වචනය තෝරන්න",
        "image_url": image,
        "options": list(options),
        "correctOption": target,
        "correct_index": options.index(target),
    }


def skill3_word_formation(
    parts: List[str], target: str, options: List[str]
) -> Dict[str, Any]:
    """Build a Skill 3 word-formation choice task."""
    joined = " + ".join(f"'{part}'" for part in parts)
    return {
        "prompt": f"{joined} එකතු වූ විට හැදෙන වචනය කුමක්ද?",
        "options": list(options),
        "correctOption": target,
        "correct_index": options.index(target),
    }


def skill3_audio_word(target: str, options: List[str]) -> Dict[str, Any]:
    """Build a Skill 3 audio-to-word choice task."""
    return {
        "prompt": "ශබ්දයට සවන් දී නිවැරදි වචනය තෝරන්න",
        "audio_text": target,
        "options": list(options),
        "correctOption": target,
        "correct_index": options.index(target),
    }


def skill3_fill_blank(
    word: str,
    image: str,
    sequence: List[Any],
    options: List[str],
    target: str,
) -> Dict[str, Any]:
    """Build a Skill 3 missing-letter task with matching image."""
    return {
        "prompt": f"'{word}' වචනයේ අඩු අකුර තෝරන්න",
        "image_url": image,
        "sequence": list(sequence),
        "options": list(options),
        "correctOption": target,
        "correct_index": options.index(target),
    }


def skill3_jumbled_word(
    image: str, word: str, parts: List[str]
) -> Dict[str, Any]:
    """Build a Skill 3 ordered-word construction task."""
    return {
        "prompt": "පින්තූරයට අදාළ වචනය සාදන්න",
        "image_url": image,
        "correct_word": word,
        "scrambled_letters": list(reversed(parts)),
    }


# Explicitly reviewed Grade 1 Skill 3 equivalents. Entries are ordered
# R1V1, R1V2, ... R5V2. V1 follows the preceding core task structure (or the
# floor structure at R1); V2 preserves the current core structure. Image tasks
# always carry their own matching asset so variant rendering cannot inherit a
# semantically incorrect core image.
SKILL3_ACTIVITY1_VARIANTS = [
    skill3_image_word("assets/images/activity_icons/plants/tree.png", "ගස", ["ගස", "මල"]),
    skill3_image_word("assets/images/activity_icons/flowers/flower_05.png", "මල", ["මල", "ගස"]),
    skill3_image_word("assets/images/activity_icons/body_parts/ear.png", "කන", ["කන", "මල"]),
    skill3_image_word("assets/images/activity_icons/body_parts/mouth.png", "කට", ["කට", "මල", "ගස"]),
    skill3_image_word("assets/images/activity_icons/body_parts/tooth.png", "දත", ["දත", "මල", "ගස"]),
    skill3_image_word("assets/images/activity_icons/everyday_objects/oil_lamp.png", "පහන", ["පහන", "කඩය", "වහල", "බසය"]),
    skill3_image_word("assets/images/activity_icons/places/shop.png", "කඩය", ["කඩය", "පහන", "වහල", "බසය"]),
    skill3_image_word("assets/images/activity_icons/everyday_objects/umbrella.png", "කුඩය", ["කුඩය", "තරුව", "පනාව", "පාසල"]),
    skill3_image_word("assets/images/activity_icons/places/school.png", "පාසල", ["පාසල", "කුඩය", "තරුව", "පනාව"]),
    skill3_image_word(
        "assets/images/activity_icons/everyday_objects/chair.png",
        "පුටුව",
        ["පුටුව", "සීනුව", "එළුවා", "බල්ලා", "ඉබ්බා"],
    ),
]

SKILL3_ACTIVITY2_VARIANTS = [
    skill3_word_formation(["අ", "ත"], "අත", ["අත", "ගස"]),
    skill3_word_formation(["ග", "ස"], "ගස", ["ගස", "ඉර"]),
    skill3_word_formation(["ඉ", "ර"], "ඉර", ["ඉර", "මල"]),
    skill3_word_formation(["පා", "ට"], "පාට", ["පාට", "පෑන", "කෑම"]),
    skill3_word_formation(["පො", "ත"], "පොත", ["පොත", "පාර", "පාට"]),
    skill3_word_formation(["කු", "ඩ", "ය"], "කුඩය", ["කුඩය", "තරුව", "පනාව"]),
    skill3_word_formation(["පා", "ස", "ල"], "පාසල", ["පාසල", "තරුව", "පනාව"]),
    skill3_word_formation(["බ", "ල්", "ලා"], "බල්ලා", ["බල්ලා", "එළුවා", "සීනුව", "තරුව"]),
    skill3_word_formation(["අ", "ක්", "කා"], "අක්කා", ["අක්කා", "බල්ලා", "ඉබ්බා", "එළුවා"]),
    skill3_word_formation(
        ["සී", "නු", "ව"],
        "සීනුව",
        ["සීනුව", "එළුවා", "ඉබ්බා", "අක්කා", "බල්ලා"],
    ),
]

# Keep every Activity 2 answer pool orthographically comparable: the target
# and all distractors have the same number of Sinhala letter units. Targets are
# also unique across the five core tasks and ten adaptive equivalents.
SKILL3_ACTIVITY2_CORE_OPTIONS = [
    ["කට", "මල"],
    ["පෑන", "කෑම", "පාට"],
    ["තරුව", "කුඩය", "පනාව"],
    ["මල්ලි", "අක්කා", "බල්ලා", "සීනුව"],
    ["පුටුව", "සීනුව", "එළුවා", "ඉබ්බා", "අක්කා"],
]

SKILL3_ACTIVITY3_VARIANTS = [
    skill3_audio_word("ඉර", ["ඉර", "මල"]),
    skill3_audio_word("ගස", ["ගස", "අත"]),
    skill3_audio_word("මල", ["මල", "අත"]),
    skill3_audio_word("වැව", ["වැව", "පාර"]),
    skill3_audio_word("පාට", ["පාට", "පෑන"]),
    skill3_audio_word("කුඩය", ["කුඩය", "තරුව", "පනාව"]),
    skill3_audio_word("පනාව", ["පනාව", "කුඩය", "තරුව"]),
    skill3_audio_word("ඉබ්බා", ["ඉබ්බා", "බල්ලා", "එළුවා"]),
    skill3_audio_word("මල්ලි", ["මල්ලි", "අක්කා", "අයියා"]),
    skill3_audio_word("පුටුව", ["පුටුව", "සීනුව", "එළුවා", "ඉබ්බා"]),
]

# Activity 3 is auditory discrimination, so visible word length must not reveal
# the answer. Every distractor has the same Sinhala letter-unit count as the
# spoken target; later pools also preserve familiar Grade 1 vocabulary.
SKILL3_ACTIVITY3_CORE_OPTIONS = [
    ["අත", "පය"],
    ["පාර", "වැව"],
    ["පාසල", "ගෙදර", "වත්ත"],
    ["අම්මා", "අක්කා", "අයියා"],
    ["කපුටා", "එළුවා", "ඉබ්බා", "බල්ලා"],
]

SKILL3_ACTIVITY4_VARIANTS = [
    skill3_fill_blank("මල", "assets/images/activity_icons/flowers/flower_05.png", [None, "ල"], ["ම", "ග"], "ම"),
    skill3_fill_blank("කන", "assets/images/activity_icons/body_parts/ear.png", [None, "න"], ["ක", "ග"], "ක"),
    skill3_fill_blank("ඉර", "assets/images/activity_icons/nature/sun.png", [None, "ර"], ["ඉ", "අ"], "ඉ"),
    skill3_fill_blank("නැව", "assets/images/activity_icons/vehicles/boat.png", ["නැ", None], ["ව", "ර", "ල"], "ව"),
    skill3_fill_blank("පාර", "assets/images/activity_icons/places/road.png", ["පා", None], ["ර", "ල", "ත"], "ර"),
    skill3_fill_blank("කුඩය", "assets/images/activity_icons/everyday_objects/umbrella.png", ["කු", None, "ය"], ["ඩ", "ට", "ද"], "ඩ"),
    skill3_fill_blank("පනාව", "assets/images/activity_icons/everyday_objects/comb.png", ["ප", None, "ව"], ["නා", "මා", "ලා"], "නා"),
    skill3_fill_blank("ඉබ්බා", "assets/images/activity_icons/animals/turtle.png", ["ඉ", None, "බා"], ["ක්", "ම්", "න්", "බ්"], "බ්"),
    skill3_fill_blank("බල්ලා", "assets/images/activity_icons/animals/dog.png", ["බ", None, "ලා"], ["ක්", "ම්", "න්", "ල්"], "ල්"),
    skill3_fill_blank("ගෙම්බා", "assets/images/activity_icons/animals/frog.png", ["ගෙ", None, "බා"], ["ක්", "ම්", "න්", "ල්"], "ම්"),
]

SKILL3_ACTIVITY5_VARIANTS = [
    skill3_jumbled_word("assets/images/activity_icons/plants/tree.png", "ගස", ["ග", "ස"]),
    # The floor task uses one unseen tree item once, regardless of whether the
    # policy reaches it through the V1 or V2 identifier.
    skill3_jumbled_word("assets/images/activity_icons/plants/tree.png", "ගස", ["ග", "ස"]),
    skill3_jumbled_word("assets/images/activity_icons/body_parts/ear.png", "කන", ["ක", "න"]),
    skill3_jumbled_word("assets/images/activity_icons/places/road.png", "පාර", ["පා", "ර"]),
    skill3_jumbled_word("assets/images/activity_icons/vehicles/boat.png", "නැව", ["නැ", "ව"]),
    skill3_jumbled_word("assets/images/activity_icons/vehicles/bus.png", "බසය", ["බ", "ස", "ය"]),
    skill3_jumbled_word("assets/images/activity_icons/places/shop.png", "කඩය", ["ක", "ඩ", "ය"]),
    skill3_jumbled_word("assets/images/activity_icons/everyday_objects/umbrella.png", "කුඩය", ["කු", "ඩ", "ය"]),
    skill3_jumbled_word("assets/images/activity_icons/places/school.png", "පාසල", ["පා", "ස", "ල"]),
    skill3_jumbled_word("assets/images/activity_icons/everyday_objects/bell.png", "සීනුව", ["සී", "නු", "ව"]),
]

SKILL3_VARIANTS = {
    1: SKILL3_ACTIVITY1_VARIANTS,
    2: SKILL3_ACTIVITY2_VARIANTS,
    3: SKILL3_ACTIVITY3_VARIANTS,
    4: SKILL3_ACTIVITY4_VARIANTS,
    5: SKILL3_ACTIVITY5_VARIANTS,
}


def skill3_difficulty_features(
    activity: int, content: Dict[str, Any]
) -> Dict[str, Any]:
    """Measure response load and orthographic complexity for Skill 3."""
    if activity == 4:
        match = re.search(r"'([^']+)'", str(content.get("prompt", "")))
        target_word = match.group(1) if match else "".join(
            str(content.get("correctOption", "")) if unit is None else str(unit)
            for unit in content.get("sequence", [])
        )
    else:
        target_word = str(
            content.get("correct_word")
            or content.get("audio_text")
            or content.get("correctOption")
            or ""
        )
    sinhala_letters = [
        char
        for char in target_word
        if "\u0d80" <= char <= "\u0dff"
        and unicodedata.category(char).startswith("L")
    ]
    pilla_count = sum(
        1
        for char in target_word
        if "\u0d80" <= char <= "\u0dff"
        and unicodedata.category(char).startswith("M")
    )
    features = {
        "word_unit_count": len(sinhala_letters),
        "pilla_count": pilla_count,
    }
    if content.get("options") is not None:
        features["answer_pool_size"] = len(content["options"])
    if content.get("scrambled_letters") is not None:
        features["answer_pool_size"] = len(content["scrambled_letters"])
    if content.get("image_url"):
        features["has_matching_image"] = True
    return features

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


def skill4_sentence_choice(
    image_url: str,
    correct_option: str,
    options: List[str],
) -> Dict[str, Any]:
    """Build one reviewed picture-to-sentence item for Skill 4 Activity 1."""
    if correct_option not in options:
        raise ValueError(f"Correct sentence missing from options: {correct_option}")
    return {
        "prompt": "පින්තූරයට ගැලපෙන වාක්‍යය තෝරන්න",
        "image_url": image_url,
        "options": list(options),
        "correctOption": correct_option,
        "correct_index": options.index(correct_option),
    }


def skill4_activity1_difficulty_features(
    content: Dict[str, Any],
) -> Dict[str, Any]:
    """Measure sentence-choice difficulty features for S4A1."""
    return {
        "sentence_word_count": len(
            str(content.get("correctOption", "")).rstrip(".?!").split()
        ),
        "answer_pool_size": len(content.get("options") or []),
        "has_matching_image": bool(content.get("image_url")),
    }


# Educator-reviewed four-task progression. The first task deliberately has one
# visible floor retry: V1 and V2 retain stable research IDs, but V1 is inactive
# and the learner sees the shared sun task only once through active V2.
SKILL4_ACTIVITY1_CORE_ITEMS = {
    1: skill4_sentence_choice(
        "assets/images/games/moon_shining.png",
        "හඳ පායනවා.",
        ["හඳ පායනවා.", "ඉර පායනවා."],
    ),
    2: skill4_sentence_choice(
        "assets/images/games/mother_cooking.png",
        "අම්මා උයනවා.",
        ["අම්මා උයනවා.", "අම්මා නිදියනවා.", "අම්මා කියවනවා."],
    ),
    3: skill4_sentence_choice(
        "assets/images/games/girl_going_to_school.png",
        "පවනි පාසල් යනවා.",
        [
            "පවනි පාසල් යනවා.",
            "පවනි පොත කියවනවා.",
            "කෝසල පාසල් යනවා.",
        ],
    ),
    4: skill4_sentence_choice(
        "assets/images/games/boy_flying_kite.png",
        "කෝසල සරුංගලය යවනවා.",
        [
            "කෝසල සරුංගලය යවනවා.",
            "කෝසල බෝලය ගහනවා.",
            "පවනි පොත කියවනවා.",
        ],
    ),
}


SKILL4_ACTIVITY1_VARIANTS = {
    (1, 1): skill4_sentence_choice(
        "assets/images/games/sun_shining.png",
        "ඉර පායනවා.",
        ["ඉර පායනවා.", "හඳ පායනවා."],
    ),
    (1, 2): skill4_sentence_choice(
        "assets/images/games/sun_shining.png",
        "ඉර පායනවා.",
        ["ඉර පායනවා.", "හඳ පායනවා."],
    ),
    (2, 1): skill4_sentence_choice(
        "assets/images/games/rowing_boat.png",
        "ඔරුව පදිනවා.",
        ["ඔරුව පදිනවා.", "බෝලය ගහනවා."],
    ),
    (2, 2): skill4_sentence_choice(
        "assets/images/games/boy_reading.png",
        "පොත කියවනවා.",
        ["පොත කියවනවා.", "පොත ලියනවා.", "පොත වහනවා."],
    ),
    (3, 1): skill4_sentence_choice(
        "assets/images/games/flower_blooming.png",
        "මල් පිපෙනවා.",
        ["මල් පිපෙනවා.", "හඳ පායනවා.", "ඉර පායනවා."],
    ),
    (3, 2): skill4_sentence_choice(
        "assets/images/games/girl_reading_tree.jpg",
        "පවනි පොත කියවනවා.",
        [
            "පවනි පොත කියවනවා.",
            "පවනි පාසල් යනවා.",
            "කෝසල පොත කියවනවා.",
        ],
    ),
    (4, 1): skill4_sentence_choice(
        "assets/images/games/children_playing_ball.jpg",
        "පවනි සෙල්ලම් කරනවා.",
        [
            "පවනි සෙල්ලම් කරනවා.",
            "පවනි පාසල් යනවා.",
            "කෝසල පොත කියවනවා.",
        ],
    ),
    (4, 2): skill4_sentence_choice(
        "assets/images/games/teacher_writing.png",
        "ගුරුතුමී අකුරු ලියනවා.",
        [
            "ගුරුතුමී අකුරු ලියනවා.",
            "ගුරුතුමී පොත බලනවා.",
            "ගුරුතුමී කවි කියනවා.",
        ],
    ),
}


def skill4_fill_blank(
    image_url: str,
    sequence: List[Optional[str]],
    correct_option: str,
    options: List[str],
) -> Dict[str, Any]:
    """Build one educator-reviewed image-supported sentence-completion item."""
    if sequence.count(None) != 1:
        raise ValueError("Skill 4 Activity 2 requires exactly one blank")
    if correct_option not in options:
        raise ValueError(f"Correct completion missing from options: {correct_option}")
    return {
        "prompt": "හිස්තැනට සුදුසු වචනය තෝරන්න",
        "sequence": list(sequence),
        "image_url": image_url,
        "options": list(options),
        "correctOption": correct_option,
        "correct_index": options.index(correct_option),
    }


def skill4_activity2_difficulty_features(
    content: Dict[str, Any],
) -> Dict[str, Any]:
    """Measure fill-the-blank sentence difficulty features for S4A2."""
    sequence = list(content.get("sequence") or [])
    return {
        "sentence_word_count": len(sequence),
        "answer_pool_size": len(content.get("options") or []),
        "blank_position": sequence.index(None) if None in sequence else None,
        "has_matching_image": bool(content.get("image_url")),
    }


# Educator-reviewed four-task progression for sentence completion. Task 1 is
# already at the two-word/two-choice floor, so it exposes one shared retry:
# V1 remains as inactive lineage and active V2 is served once. Task 2 has two
# distinct floor-level practice items and therefore uses V1 followed by V2.
SKILL4_ACTIVITY2_CORE_ITEMS = {
    1: skill4_fill_blank(
        "assets/images/games/sun_shining.png",
        [None, "පායනවා"],
        "ඉර",
        ["ඉර", "හඳ"],
    ),
    2: skill4_fill_blank(
        "assets/images/games/flower_blooming.png",
        [None, "පිපෙනවා"],
        "මල්",
        ["මල්", "ගල්"],
    ),
    3: skill4_fill_blank(
        "assets/images/games/girl_going_to_school.png",
        ["පවනි", None, "යනවා"],
        "පාසල්",
        ["පාසල්", "ගෙදර", "වත්තට"],
    ),
    4: skill4_fill_blank(
        "assets/images/games/mother_cooking.png",
        ["අම්මා", None, "උයයි"],
        "කෑම",
        ["කෑම", "පොත", "මල්", "ගල්"],
    ),
}


SKILL4_ACTIVITY2_VARIANTS = {
    # Shared Task 1 floor retry. Both IDs intentionally carry the same content,
    # but only V2 is active and visible to the learner.
    (1, 1): skill4_fill_blank(
        "assets/images/games/moon_shining.png",
        [None, "පායනවා"],
        "හඳ",
        ["හඳ", "ඉර"],
    ),
    (1, 2): skill4_fill_blank(
        "assets/images/games/moon_shining.png",
        [None, "පායනවා"],
        "හඳ",
        ["හඳ", "ඉර"],
    ),
    (2, 1): skill4_fill_blank(
        "assets/images/games/dog_running.png",
        [None, "දුවනවා"],
        "බල්ලා",
        ["බල්ලා", "පූසා"],
    ),
    (2, 2): skill4_fill_blank(
        "assets/images/games/cat_sleeping.png",
        [None, "නිදියනවා"],
        "පූසා",
        ["පූසා", "බල්ලා"],
    ),
    (3, 1): skill4_fill_blank(
        "assets/images/games/bird_flying.png",
        [None, "පියාඹනවා"],
        "කුරුල්ලා",
        ["කුරුල්ලා", "බල්ලා"],
    ),
    (3, 2): skill4_fill_blank(
        "assets/images/games/girl_reading_tree.jpg",
        ["නංගි", None, "කියවනවා"],
        "පොතක්",
        ["පොතක්", "බෝලයක්", "මලක්"],
    ),
    (4, 1): skill4_fill_blank(
        "assets/images/games/boy_drawing.png",
        [None, "චිත්‍රයක්", "අඳිනවා"],
        "මල්ලි",
        ["මල්ලි", "නංගි", "අම්මා", "තාත්තා"],
    ),
    (4, 2): skill4_fill_blank(
        "assets/images/games/boy_feeding_dog.jpg",
        [None, "කෑම", "දෙනවා"],
        "බල්ලාට",
        ["බල්ලාට", "පූසාට", "කුරුල්ලාට", "එළුවාට"],
    ),
}


def skill4_audio_sentence(
    sentence: str,
    options: List[str],
) -> Dict[str, Any]:
    """Build one reviewed listen-and-select sentence item."""
    if sentence not in options:
        raise ValueError(f"Spoken sentence missing from options: {sentence}")
    if len(options) != len(set(options)):
        raise ValueError(f"Duplicate sentence options are not allowed: {sentence}")
    return {
        "prompt": "ශබ්දයට සවන් දී නිවැරදි වාක්‍ය තෝරන්න",
        "audio_text": sentence,
        "options": list(options),
        "correctOption": sentence,
        "correct_index": options.index(sentence),
    }


def _sinhala_base_letter_count(word: str) -> int:
    """Count base Sinhala letters without punctuation or vowel marks."""
    return sum(
        1
        for char in word.rstrip(".?!")
        if "\u0d80" <= char <= "\u0dff"
        and unicodedata.category(char).startswith("L")
    )


def skill4_activity3_difficulty_features(
    content: Dict[str, Any],
) -> Dict[str, Any]:
    """Measure sentence recognition and pilla complexity for S4A3."""
    words = str(content.get("correctOption", "")).rstrip(".?!").split()
    return {
        "sentence_word_count": len(words),
        "answer_pool_size": len(content.get("options") or []),
        "max_word_letter_count": max(
            (_sinhala_base_letter_count(word) for word in words),
            default=0,
        ),
        "pilla_count": sum(
            1
            for word in words
            for char in word
            if "\u0d80" <= char <= "\u0dff"
            and unicodedata.category(char).startswith("M")
        ),
    }


# Four-task auditory sentence progression. The language follows the short,
# concrete subject/action patterns used by the Sri Lankan Grade 1 Sinhala
# reading resources (familiar family members, animals, objects, and actions).
# Every option is a meaningful sentence rather than a deliberately broken word
# order. V1 follows the preceding core response load; V2 returns to the current
# core load for independent confirmation.
SKILL4_ACTIVITY3_CORE_ITEMS = {
    1: skill4_audio_sentence(
        "පාසල් යනවා.",
        ["පාසල් යනවා.", "යනවා පාසල්."],
    ),
    2: skill4_audio_sentence(
        "පොත බලනවා.",
        ["පොත බලනවා.", "බලනවා පොත.", "පොත වහනවා."],
    ),
    3: skill4_audio_sentence(
        "අම්මා බත් උයයි.",
        ["අම්මා බත් උයයි.", "තාත්තා පොත බලයි.", "නංගි මල් නෙළයි."],
    ),
    4: skill4_audio_sentence(
        "සමන් පොතක් කියවයි.",
        [
            "සමන් පොතක් කියවයි.",
            "නදී මලක් නෙළයි.",
            "අම්මා බත් උයයි.",
            "තාත්තා වතුර බොයි.",
        ],
    ),
}


SKILL4_ACTIVITY3_VARIANTS = {
    (1, 1): skill4_audio_sentence(
        "අම්මා උයයි.",
        ["අම්මා උයයි.", "තාත්තා දුවයි."],
    ),
    (1, 2): skill4_audio_sentence(
        "පූසා දුවයි.",
        ["පූසා දුවයි.", "බල්ලා බුරයි."],
    ),
    (2, 1): skill4_audio_sentence(
        "මල් පිපෙයි.",
        ["මල් පිපෙයි.", "හඳ පායයි."],
    ),
    (2, 2): skill4_audio_sentence(
        "හඳ පායයි.",
        ["හඳ පායයි.", "ඉර පායයි.", "මල් පිපෙයි."],
    ),
    (3, 1): skill4_audio_sentence(
        "බල්ලා දුවයි.",
        ["බල්ලා දුවයි.", "පූසා පනියි.", "කුරුල්ලා පියාඹයි."],
    ),
    (3, 2): skill4_audio_sentence(
        "මල්ලි සෙල්ලම් කරයි.",
        ["මල්ලි සෙල්ලම් කරයි.", "නංගි පොත බලයි.", "අම්මා බත් උයයි."],
    ),
    (4, 1): skill4_audio_sentence(
        "තාත්තා ඔරුව පදිනවා.",
        ["තාත්තා ඔරුව පදිනවා.", "අම්මා බත් උයනවා.", "මල්ලි බෝලය ගසනවා."],
    ),
    (4, 2): skill4_audio_sentence(
        "ගුරුතුමී පොත බලනවා.",
        [
            "ගුරුතුමී පොත බලනවා.",
            "නංගි මල් නෙළනවා.",
            "අම්මා බත් උයනවා.",
            "තාත්තා ඔරුව පදිනවා.",
        ],
    ),
}


def skill4_jumbled_sentence(
    image_url: str,
    correct_sentence: str,
    scrambled_words: List[str],
) -> Dict[str, Any]:
    """Build one reviewed image-supported sentence-ordering item."""
    correct_words = correct_sentence.rstrip(".?!").split()
    if sorted(correct_words) != sorted(scrambled_words):
        raise ValueError(
            f"Scrambled words do not match sentence: {correct_sentence}"
        )
    return {
        "prompt": "පින්තූරයට අදාළ වාක්‍යය සාදන්න",
        "image_url": image_url,
        "correct_sentence": correct_sentence,
        "scrambled_words": list(scrambled_words),
    }


def skill4_activity4_difficulty_features(
    content: Dict[str, Any],
) -> Dict[str, Any]:
    """Measure sentence-ordering difficulty features for S4A4."""
    return {
        "sentence_word_count": len(
            str(content.get("correct_sentence", "")).rstrip(".?!").split()
        ),
        "answer_pool_size": len(content.get("scrambled_words") or []),
        "has_matching_image": bool(content.get("image_url")),
    }


# Reviewed variants for the four-task sentence-ordering progression. Task 1 is
# already at the learning floor, so V1 and V2 intentionally retain one shared
# moon retry and only V2 is served. Task 2 explicitly uses a flower remediation
# followed by a different dog confirmation. Tasks 3-4 keep separate reduced-load
# remediation and equivalent confirmation items.
SKILL4_ACTIVITY4_VARIANTS = {
    (1, 1): skill4_jumbled_sentence(
        "assets/images/games/moon_shining.png",
        "හඳ පායනවා.",
        ["පායනවා", "හඳ"],
    ),
    (1, 2): skill4_jumbled_sentence(
        "assets/images/games/moon_shining.png",
        "හඳ පායනවා.",
        ["පායනවා", "හඳ"],
    ),
    (2, 1): skill4_jumbled_sentence(
        "assets/images/games/flower_blooming.png",
        "මල් පිපෙනවා.",
        ["පිපෙනවා", "මල්"],
    ),
    (2, 2): skill4_jumbled_sentence(
        "assets/images/games/dog_running.png",
        "බල්ලා දුවනවා.",
        ["දුවනවා", "බල්ලා"],
    ),
    (3, 1): skill4_jumbled_sentence(
        "assets/images/games/bird_flying.png",
        "කුරුල්ලා පියාඹනවා.",
        ["පියාඹනවා", "කුරුල්ලා"],
    ),
    (3, 2): skill4_jumbled_sentence(
        "assets/images/games/rowing_boat.png",
        "තාත්තා ඔරුව පදිනවා.",
        ["පදිනවා", "තාත්තා", "ඔරුව"],
    ),
    (4, 1): skill4_jumbled_sentence(
        "assets/images/games/mother_cooking.png",
        "අම්මා බත් උයනවා.",
        ["උයනවා", "අම්මා", "බත්"],
    ),
    (4, 2): skill4_jumbled_sentence(
        "assets/images/games/teacher_writing.png",
        "ගුරුතුමී අකුරු ලියනවා.",
        ["ලියනවා", "අකුරු", "ගුරුතුමී"],
    ),
}


def rotate(values: List[Any], start: int, count: int) -> List[Any]:
    """Select a deterministic wrapped slice while deep-copying content."""
    return [copy.deepcopy(values[(start + offset) % len(values)]) for offset in range(count)]


def unique_values(values: List[Any]) -> List[Any]:
    """Preserve display order while removing ambiguous duplicate choices."""
    result = []
    for value in values:
        if value not in result:
            result.append(copy.deepcopy(value))
    return result


def difficulty_label(difficulty: float) -> str:
    """Map a provisional difficulty logit to a readable band."""
    return "easy" if difficulty < -0.25 else "hard" if difficulty > 0.75 else "medium"


def _reduce_choice_options(content: Dict[str, Any]) -> bool:
    """Remove one distractor while retaining targets and a valid choice."""
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

    if skill == 3 and activity in {1, 2, 3, 4}:
        # Skill 3 V1 is explicitly authored at the preceding round's word-unit,
        # pilla, and answer-pool structure. Do not shrink that reviewed pool a
        # second time. R1 is the floor-equivalent exception.
        match = re.search(r"R(\d+)", str(core.get("item_id", "")), re.I)
        return easier, int(match.group(1)) > 1 if match else False

    if skill == 4 and activity == 1:
        match = re.search(r"R(\d+)", str(core.get("item_id", "")), re.I)
        round_number = int(match.group(1)) if match else 1
        if round_number == 1:
            return easier, False
        core_word_count = len(
            str(core.get("correctOption", "")).rstrip(".?!").split()
        )
        easier_word_count = len(
            str(easier.get("correctOption", "")).rstrip(".?!").split()
        )
        return easier, (
            easier_word_count < core_word_count
            or len(easier.get("options") or []) < len(core.get("options") or [])
            # These V1 records are educator-reviewed previous-level tasks.
            # Round 4 reduces semantic/vocabulary load while intentionally
            # retaining the same three-word/three-option response structure.
            or round_number == 4
        )

    if skill == 4 and activity == 2:
        match = re.search(r"R(\d+)", str(core.get("item_id", "")), re.I)
        round_number = int(match.group(1)) if match else 1
        if round_number <= 2:
            # R1 is a one-shot shared floor retry. R2 deliberately keeps two
            # different same-level floor items via has_floor_remediation.
            return easier, False
        if round_number == 3:
            # Reviewed V1 already reduces the three-choice core to two choices.
            return easier, True
        return easier, _reduce_choice_options(easier)

    if skill == 4 and activity == 3:
        match = re.search(r"R(\d+)", str(core.get("item_id", "")), re.I)
        round_number = int(match.group(1)) if match else 1
        # R1 is a same-load floor remediation. R2-R4 V1 records are already
        # authored at the preceding core's answer-pool/sentence load.
        return easier, round_number > 1

    if (skill, activity) in {
        (1, 4),
    }:
        return easier, _reduce_choice_options(easier)

    # Activity 5 V1 content is educator-authored at the preceding round's
    # difficulty. R2 remains a valid remediation even though both R1 and R2
    # contain two word units: it deliberately returns to the simpler,
    # no-pilla floor vocabulary before the one-pilla confirmation.
    if skill == 3 and activity == 5:
        match = re.search(r"R(\d+)", str(core.get("item_id", "")), re.I)
        return easier, int(match.group(1)) > 1 if match else False
    if skill == 4 and activity == 4:
        match = re.search(r"R(\d+)", str(core.get("item_id", "")), re.I)
        round_number = int(match.group(1)) if match else 1
        # R3 returns to the preceding two-word level. R4 retains three words
        # but uses the previous level's familiar vocabulary and image support.
        return easier, round_number > 2

    return easier, False


def variant_content(skill: int, activity: int, round_index: int, variant: int, core: Dict[str, Any]) -> Dict[str, Any]:
    """Return reviewed V1/V2 content for a core curriculum round."""
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

    if skill == 3 and activity in SKILL3_VARIANTS:
        return copy.deepcopy(SKILL3_VARIANTS[activity][slot])

    if skill == 4 and activity == 1:
        reviewed = SKILL4_ACTIVITY1_VARIANTS.get((round_index, variant))
        if reviewed is not None:
            return copy.deepcopy(reviewed)
        image, sentence = SENTENCES[slot % len(SENTENCES)]
        count = option_count or 3
        others = [value for _, value in rotate(SENTENCES, slot + 1, count) if value != sentence]
        options = [sentence, *others][:count]
        return {"prompt": "පින්තූරයට ගැලපෙන වාක්‍යය තෝරන්න", "image_url": image,
                "options": options, "correctOption": sentence, "correct_index": options.index(sentence)}

    if skill == 4 and activity == 2:
        reviewed = SKILL4_ACTIVITY2_VARIANTS.get((round_index, variant))
        if reviewed is not None:
            return copy.deepcopy(reviewed)
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
        reviewed = SKILL4_ACTIVITY3_VARIANTS.get((round_index, variant))
        if reviewed is not None:
            return copy.deepcopy(reviewed)
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
        reviewed = SKILL4_ACTIVITY4_VARIANTS.get((round_index, variant))
        if reviewed is not None:
            return copy.deepcopy(reviewed)

    raise ValueError(f"No variant generator for Skill {skill} Activity {activity}")


def build() -> None:
    """Regenerate all Component 4 curriculum JSON with research metadata."""
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
            if skill == 4 and activity_number in {1, 2, 3, 4}:
                # Skill 4 Activities 1-4 intentionally use four core tasks.
                # Trimming here keeps every deterministic rebuild from
                # restoring the retired fifth task from an older JSON file.
                activity["rounds"] = (activity.get("rounds") or [])[:4]
            rounds = activity.get("rounds") or activity.get("core_rounds") or []
            for round_index, round_data in enumerate(rounds, start=1):
                if (
                    skill == 4
                    and activity_number == 1
                    and round_index in SKILL4_ACTIVITY1_CORE_ITEMS
                ):
                    for key in (
                        "prompt", "image_url", "options", "correctOption",
                        "correct_index",
                    ):
                        round_data.pop(key, None)
                    round_data.update(
                        copy.deepcopy(SKILL4_ACTIVITY1_CORE_ITEMS[round_index])
                    )
                    if round_index == 4:
                        round_data["difficulty_b"] = 1.0
                        round_data["difficulty_label"] = "hard"
                if skill == 4 and activity_number == 1:
                    round_data["difficulty_features"] = (
                        skill4_activity1_difficulty_features(round_data)
                    )
                if (
                    skill == 4
                    and activity_number == 2
                    and round_index in SKILL4_ACTIVITY2_CORE_ITEMS
                ):
                    for key in (
                        "prompt", "sequence", "image_url", "options",
                        "correctOption", "correct_index",
                    ):
                        round_data.pop(key, None)
                    round_data.update(
                        copy.deepcopy(SKILL4_ACTIVITY2_CORE_ITEMS[round_index])
                    )
                    round_data["difficulty_features"] = (
                        skill4_activity2_difficulty_features(round_data)
                    )
                if (
                    skill == 4
                    and activity_number == 3
                    and round_index in SKILL4_ACTIVITY3_CORE_ITEMS
                ):
                    for key in (
                        "prompt", "audio_text", "options", "correctOption",
                        "correct_index",
                    ):
                        round_data.pop(key, None)
                    round_data.update(
                        copy.deepcopy(SKILL4_ACTIVITY3_CORE_ITEMS[round_index])
                    )
                    reviewed_difficulty = {
                        1: -1.0,
                        2: -0.5,
                        3: 0.0,
                        4: 0.5,
                    }[round_index]
                    round_data["difficulty_b"] = reviewed_difficulty
                    round_data["difficulty_label"] = difficulty_label(
                        reviewed_difficulty
                    )
                    round_data["difficulty_features"] = (
                        skill4_activity3_difficulty_features(round_data)
                    )
                if skill == 4 and activity_number == 4:
                    round_data["difficulty_features"] = (
                        skill4_activity4_difficulty_features(round_data)
                    )
                if skill == 3 and activity_number == 1 and round_index == 3:
                    # Keep the reviewed bus target/image unchanged while making
                    # all three distractors match its three-unit, no-pilla load.
                    round_data["options"] = ["බසය", "පහන", "කඩය", "වහල"]
                    round_data["correctOption"] = "බසය"
                    round_data["correct_index"] = 0
                if skill == 3 and activity_number == 1 and round_index == 5:
                    # The final level intentionally measures discrimination
                    # among five equally long, familiar Grade 1 words.
                    round_data["options"] = [
                        "සීනුව", "පුටුව", "එළුවා", "බල්ලා", "ඉබ්බා"
                    ]
                    round_data["correctOption"] = "සීනුව"
                    round_data["correct_index"] = 0
                if skill == 3 and activity_number == 2:
                    options = SKILL3_ACTIVITY2_CORE_OPTIONS[round_index - 1]
                    target = round_data["correctOption"]
                    round_data["options"] = list(options)
                    round_data["correct_index"] = options.index(target)
                if skill == 3 and activity_number == 3:
                    options = SKILL3_ACTIVITY3_CORE_OPTIONS[round_index - 1]
                    target = round_data["correctOption"]
                    round_data["options"] = list(options)
                    round_data["correct_index"] = options.index(target)
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
                    7
                    if skill == 2 and activity_number == 4
                    else 3
                    if skill == 2 and activity_number == 5
                    else 3
                    if skill == 2 and activity_number == 3
                    else 10
                    if skill == 3 and activity_number in {4, 5}
                    else 9
                    if skill == 3
                    else 5
                    if skill == 4 and activity_number == 1
                    else 4
                    if skill == 4 and activity_number == 2
                    else 5
                    if skill == 4 and activity_number == 3
                    else 4
                    if skill == 4 and activity_number == 4
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
                if skill == 3:
                    round_data["difficulty_features"] = (
                        skill3_difficulty_features(activity_number, round_data)
                    )
                core_content = round_data.get("content") or round_data
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
                        if (
                            skill in {2, 3}
                            and activity_number in {1, 2, 3, 4, 5}
                        ):
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
                        # Skill 3 Activities 4-5 version 10 separates revised
                        # adaptive content from previously collected test
                        # evidence. Other Skill 3 activities retain version 9.
                        "item_version": (
                            5 if skill == 2 and activity_number == 1
                            else 7 if skill == 2 and activity_number == 4
                            else 3 if skill == 2 and activity_number == 5
                            else 3 if skill == 2 and activity_number in {2, 3}
                            else 10
                            if skill == 3 and activity_number in {4, 5}
                            else 9 if skill == 3
                            else 5
                            if skill == 4 and activity_number == 1
                            else 4
                            if skill == 4 and activity_number == 2
                            else 5
                            if skill == 4 and activity_number == 3
                            else 4
                            if skill == 4 and activity_number == 4
                            else 2
                        ),
                        "item_role": role,
                        "difficulty_b": variant_difficulty,
                        "difficulty_label": difficulty_label(variant_difficulty),
                        "response_load_relation": "reduced" if reduced else "equivalent",
                        "content": content,
                    }
                    if (
                        skill == 3
                        and activity_number == 5
                        and round_index == 1
                    ):
                        # R1 has no valid easier level. Both identifiers retain
                        # the educator-approved tree content, but only V2 is an
                        # active one-shot retry so the child never sees two
                        # separate floor tasks.
                        variant_record["is_active"] = variant_number == 2
                        variant_record["single_floor_retry"] = True
                    if (
                        skill == 4
                        and activity_number == 1
                        and round_index == 1
                    ):
                        # Task 1 intentionally exposes only one sun retry. V1
                        # remains in the bank for stable lineage but is never
                        # served; active V2 is the single combined
                        # remediation/confirmation opportunity.
                        variant_record["is_active"] = variant_number == 2
                        variant_record["single_floor_retry"] = True
                    if (
                        skill == 4
                        and activity_number == 2
                        and round_index == 1
                    ):
                        # Task 1 is already at the two-word/two-choice floor.
                        # Keep one shared unseen retry instead of presenting
                        # duplicate remediation and confirmation screens.
                        variant_record["is_active"] = variant_number == 2
                        variant_record["single_floor_retry"] = True
                    if (
                        skill == 4
                        and activity_number == 4
                        and round_index == 1
                    ):
                        # Task 1 is the two-word sentence-ordering floor. Both
                        # stable IDs carry the approved moon content, while only
                        # V2 is served as the single shared retry.
                        variant_record["is_active"] = variant_number == 2
                        variant_record["single_floor_retry"] = True
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
                    if skill == 3:
                        variant_record["difficulty_features"] = (
                            skill3_difficulty_features(activity_number, content)
                        )
                    if skill == 4 and activity_number == 1:
                        variant_record["difficulty_features"] = (
                            skill4_activity1_difficulty_features(content)
                        )
                        if variant_number == 1 and round_index <= 4:
                            variant_record["remediation_source_round"] = (
                                round_index - 1 if round_index > 1 else None
                            )
                            variant_record["remediation_strategy"] = (
                                "PREVIOUS_DIFFICULTY_LEVEL"
                                if round_index > 1
                                else "SINGLE_FLOOR_RETRY_ALIAS"
                            )
                    if skill == 4 and activity_number == 2:
                        variant_record["difficulty_features"] = (
                            skill4_activity2_difficulty_features(content)
                        )
                        if variant_number == 1:
                            variant_record["remediation_source_round"] = (
                                round_index - 1 if round_index > 1 else None
                            )
                            variant_record["remediation_strategy"] = (
                                "SAME_LEVEL_FLOOR_PRACTICE"
                                if round_index == 2
                                else "PREVIOUS_DIFFICULTY_LEVEL"
                                if round_index > 2
                                else "SINGLE_FLOOR_RETRY_ALIAS"
                            )
                    if skill == 4 and activity_number == 3:
                        variant_record["difficulty_features"] = (
                            skill4_activity3_difficulty_features(content)
                        )
                        if variant_number == 1:
                            variant_record["remediation_source_round"] = (
                                round_index - 1 if round_index > 1 else None
                            )
                            variant_record["remediation_strategy"] = (
                                "PREVIOUS_DIFFICULTY_LEVEL"
                                if round_index > 1
                                else "SAME_LEVEL_FLOOR_PRACTICE"
                            )
                    if skill == 4 and activity_number == 4:
                        variant_record["difficulty_features"] = (
                            skill4_activity4_difficulty_features(content)
                        )
                        if variant_number == 1:
                            variant_record["remediation_source_round"] = (
                                round_index - 1 if round_index > 1 else None
                            )
                            variant_record["remediation_strategy"] = (
                                "PREVIOUS_DIFFICULTY_LEVEL"
                                if round_index > 2
                                else "SAME_LEVEL_FLOOR_PRACTICE"
                            )
                    if (
                        skill in {2, 3}
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
                                if skill == 2 and activity_number == 1
                                else "FLOOR_EXTENDED_EXPOSURE"
                                if skill == 2 and activity_number == 5
                                else "FLOOR_EQUIVALENT_TASK"
                            )
                        )
                    variants.append(variant_record)

                # Skills 1-2 retain two *local* exact-target items for each
                # diagnosed core-task unit: an easier remediation item and an
                # equivalent independent confirmation item. These variants do
                # not carry a target into another activity; they stay inside
                # this core item's equivalent group.
                if skill == 1 and activity_number in {1, 2, 3, 4, 5}:
                    targeted_pairs = targeted_skill1_variant_contents(
                        activity_number,
                        core_content,
                        variants[0]["content"],
                        variants[1]["content"],
                        seed=skill * 10000 + activity_number * 100 + round_index,
                    )
                    next_variant_number = 3
                    for targeted_unit, remediation, confirmation in targeted_pairs:
                        for role, base_variant, targeted_content in (
                            ("REMEDIATION", variants[0], remediation),
                            ("CONFIRMATION", variants[1], confirmation),
                        ):
                            variants.append({
                                "variant_id": f"V{next_variant_number}",
                                "item_id": f"{item_id}V{next_variant_number}",
                                "item_version": round_data["item_version"],
                                "item_role": role,
                                "difficulty_b": base_variant["difficulty_b"],
                                "difficulty_label": base_variant["difficulty_label"],
                                "response_load_relation": (
                                    "targeted_reduced"
                                    if role == "REMEDIATION"
                                    else "targeted_equivalent"
                                ),
                                "targeted_practice": True,
                                "target_source_item_id": item_id,
                                "targeted_unit": targeted_unit,
                                "content": targeted_content,
                            })
                            next_variant_number += 1

                if skill == 2 and activity_number in {1, 3}:
                    for variant_number, role, base_variant, confirmation in (
                        (3, "REMEDIATION", variants[0], False),
                        (4, "CONFIRMATION", variants[1], True),
                    ):
                        targeted_content = targeted_letter_variant_content(
                            activity_number,
                            core_content,
                            base_variant["content"],
                            confirmation=confirmation,
                        )
                        targeted_record = {
                            "variant_id": f"V{variant_number}",
                            "item_id": f"{item_id}V{variant_number}",
                            "item_version": base_variant["item_version"],
                            "item_role": role,
                            "difficulty_b": base_variant["difficulty_b"],
                            "difficulty_label": base_variant["difficulty_label"],
                            "response_load_relation": (
                                "targeted_reduced"
                                if role == "REMEDIATION"
                                else "targeted_equivalent"
                            ),
                            "targeted_practice": True,
                            "target_source_item_id": item_id,
                            "content": targeted_content,
                        }
                        if activity_number == 3:
                            targeted_record["distractor_strategy"] = (
                                base_variant.get("distractor_strategy")
                            )
                        variants.append(targeted_record)

                if skill == 2 and activity_number in {2, 4, 5}:
                    targeted_pairs = targeted_skill2_variant_contents(
                        activity_number,
                        round_index,
                        core_content,
                        variants[0]["content"],
                        variants[1]["content"],
                        seed=skill * 10000 + activity_number * 100 + round_index,
                    )
                    next_variant_number = 3
                    for targeted_unit, remediation, confirmation in targeted_pairs:
                        for role, base_variant, targeted_content in (
                            ("REMEDIATION", variants[0], remediation),
                            ("CONFIRMATION", variants[1], confirmation),
                        ):
                            targeted_record = {
                                "variant_id": f"V{next_variant_number}",
                                "item_id": f"{item_id}V{next_variant_number}",
                                "item_version": base_variant["item_version"],
                                "item_role": role,
                                "difficulty_b": base_variant["difficulty_b"],
                                "difficulty_label": base_variant["difficulty_label"],
                                "response_load_relation": (
                                    "targeted_reduced"
                                    if role == "REMEDIATION"
                                    else "targeted_equivalent"
                                ),
                                "targeted_practice": True,
                                "target_source_item_id": item_id,
                                "targeted_unit": targeted_unit,
                                "content": targeted_content,
                            }
                            if activity_number == 4:
                                targeted_record["difficulty_features"] = {
                                    "word_unit_count": len(targeted_content["word_units"]),
                                    "pilla_count": targeted_content["pilla_count"],
                                    "answer_pool_size": len(targeted_content["options"]),
                                    "target_position": targeted_content["target_position"],
                                }
                            elif activity_number == 5:
                                targeted_record["difficulty_features"] = {
                                    "pattern_length": len(targeted_content["pattern"]),
                                    "pilla_count": targeted_content["pilla_count"],
                                    "answer_pool_size": len(targeted_content["options"]),
                                    "show_seconds": targeted_content["show_seconds"],
                                }
                            variants.append(targeted_record)
                            next_variant_number += 1
                round_data["has_reduced_remediation"] = has_reduced_remediation
                if (
                    (skill == 2 and activity_number == 4)
                    or (
                        skill == 4
                        and activity_number == 2
                        and round_index == 2
                    )
                    or (
                        skill == 4
                        and activity_number == 3
                        and round_index == 1
                    )
                    or (
                        skill == 4
                        and activity_number == 4
                        and round_index == 2
                    )
                ):
                    round_data["has_floor_remediation"] = round_index == 1
                    if skill == 4:
                        round_data["has_floor_remediation"] = True
                else:
                    round_data.pop("has_floor_remediation", None)
                round_data.pop("has_equivalent_remediation", None)
                round_data["adaptive_variants"] = variants
        path.write_text(json.dumps(decoded, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    build()
