"""Derive auditable micro-skill metadata from reviewed curriculum items.

The adaptive tutor never edits Sinhala text or invents a task at runtime.  It
uses this metadata to find already-reviewed items that exercise the same
letter, word, image relation, or sentence skill as the learner's error.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import PurePosixPath
from typing import Any, Dict, Iterable, List


_META_KEYS = {
    "item_id", "item_version", "difficulty_label", "difficulty_b",
    "is_anchor", "equivalent_group_id", "adaptive_variants",
    "has_reduced_remediation", "has_floor_remediation",
    "difficulty_features", "remediation_strategy", "response_load_relation",
}


def _strings(value: Any) -> List[str]:
    """Flatten meaningful strings from nested curriculum content."""
    if value is None:
        return []
    if isinstance(value, str):
        stripped = value.strip()
        return [stripped] if stripped else []
    if isinstance(value, dict):
        values: List[str] = []
        for key, nested in value.items():
            if str(key) in _META_KEYS:
                continue
            values.extend(_strings(nested))
        return values
    if isinstance(value, Iterable):
        values = []
        for nested in value:
            values.extend(_strings(nested))
        return values
    return []


def _unique(values: Iterable[str]) -> List[str]:
    """NFC-normalize strings and preserve their first occurrence order."""
    seen = set()
    result = []
    for raw in values:
        value = unicodedata.normalize("NFC", str(raw)).strip()
        if not value or value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def _basename(value: str) -> str:
    """Convert an asset path to a human-comparable semantic value."""
    if "/" not in value or "." not in value:
        return value
    return PurePosixPath(value).stem.replace("_", " ")


def normalize_target_unit(value: Any) -> str:
    """Normalize a client-reported semantic unit like curriculum metadata."""
    normalized = unicodedata.normalize("NFC", str(value)).strip()
    return _basename(normalized) if normalized else ""


def _sinhala_base_letters(value: str) -> List[str]:
    """Extract Sinhala base letters while excluding combining marks."""
    # Sinhala combining marks are intentionally excluded.  This produces
    # useful component tags such as `ව` without pretending that a Unicode code
    # point is by itself a pedagogically valid word or question.
    return _unique(
        char for char in value
        if "SINHALA LETTER" in unicodedata.name(char, "")
    )


def _correct_values(content: Dict[str, Any]) -> List[str]:
    """Collect reviewed correct targets across supported task templates."""
    values: List[str] = []
    for key in (
        "correctOption", "correct_option", "correct_answer", "correct_word",
        "correct_sentence", "target_word", "target_letter", "target_asset",
        "audio_text", "targeted_unit", "pattern",
    ):
        values.extend(_strings(content.get(key)))

    for key in ("targets", "target_assets"):
        values.extend(_strings(content.get(key)))

    items = content.get("items")
    if isinstance(items, list):
        for item in items:
            if isinstance(item, dict) and item.get("is_target") is True:
                values.extend(_strings(item.get("value")))

    # Identical-letter matching requires every displayed letter, not one
    # conventional answer option.
    if isinstance(content.get("letters"), list):
        values.extend(_strings(content.get("letters")))

    options = content.get("options")
    correct_index = content.get("correct_index")
    correct_indices = content.get("correct_indices") or []
    if isinstance(options, list):
        indices = []
        if isinstance(correct_index, int):
            indices.append(correct_index)
        indices.extend(index for index in correct_indices if isinstance(index, int))
        for index in indices:
            if 0 <= index < len(options):
                values.extend(_strings(options[index]))
    return _unique(values)


def _micro_skill_tags(template: str, content: Dict[str, Any]) -> List[str]:
    """Derive stable matching tags from template and difficulty metadata."""
    tags: List[str] = []
    mapping = {
        "visual_hidden_search": ("visual_search", "visual_discrimination"),
        "visual_odd_one_out": ("visual_matching", "visual_discrimination"),
        "visual_sorting_adventure": ("visual_categorization", "semantic_sorting"),
        "visual_pattern_adventure": ("visual_pattern", "sequence_reasoning"),
        "visual_memory_hats": ("visual_memory", "spatial_memory"),
        "skill2_odd_one_out": ("letter_identification", "orthographic_discrimination"),
        "skill2_identical_match": ("letter_matching", "orthographic_discrimination"),
        "skill2_audio": ("phoneme_grapheme_mapping", "auditory_discrimination"),
        "skill2_mcq": ("letter_decoding", "word_boundary"),
        "skill2_pattern_memory": ("letter_memory", "sequence_memory"),
        "skill3_image_mcq": ("image_word_mapping", "word_recognition"),
        "skill3_fill_blank": ("word_completion", "orthographic_completion"),
        "skill3_audio_mcq": ("spoken_word_recognition", "auditory_discrimination"),
        "skill3_word_formation": ("word_formation", "orthographic_sequence"),
        "skill3_jumbled_word": ("word_sequence", "orthographic_sequence"),
        "skill4_act1_mcq": ("image_sentence_mapping", "sentence_comprehension"),
        "skill4_act2_fill_blank": ("sentence_completion", "word_selection"),
        "skill4_act3_mcq": ("spoken_sentence_recognition", "sentence_comprehension"),
        "skill4_act4_jumbled_sentence": ("sentence_sequence", "word_order"),
    }
    tags.extend(mapping.get(template, (template or "unknown_template",)))
    features = content.get("difficulty_features")
    if isinstance(features, dict):
        for key, value in features.items():
            if isinstance(value, bool) and value:
                tags.append(str(key))
            elif isinstance(value, (str, int, float)):
                tags.append(f"{key}:{value}")
    pilla_count = content.get("pilla_count")
    if isinstance(pilla_count, (int, float)):
        tags.append("contains_pillam" if pilla_count > 0 else "no_pillam")
    return _unique(tags)


def derive_practice_metadata(item: Dict[str, Any]) -> Dict[str, Any]:
    """Return stable target and error-matching metadata for one bank item."""
    raw_content = (
        item.get("content") if isinstance(item.get("content"), dict) else item
    )
    content = dict(raw_content)
    # Difficulty structure is often stored beside `content` in curriculum
    # metadata. Bring it into the derivation view without changing the task.
    for key in ("difficulty_features", "pilla_count"):
        if key not in content and item.get(key) is not None:
            content[key] = item[key]
    template = str(item.get("template_type") or content.get("template_type") or "")
    primary = [normalize_target_unit(value) for value in _correct_values(content)]

    # Sorting has several valid target assets/categories rather than one
    # conventional correct option.
    if template == "visual_sorting_adventure":
        primary.extend(_basename(value) for value in _strings(content.get("categories")))
        primary.extend(_strings(content.get("category_labels")))

    primary = _unique(primary)
    component_units: List[str] = []
    for value in primary:
        component_units.extend(part for part in re.split(r"\s+", value) if part)
        component_units.extend(_sinhala_base_letters(value))
    component_units = _unique(component_units)
    tags = _micro_skill_tags(template, content)
    load_relation = item.get("response_load_relation")
    if load_relation:
        tags = _unique([*tags, f"response_load:{load_relation}"])
    primary_key = primary[0] if primary else str(item.get("knowledge_component_id") or template)
    return {
        "primary_targets": primary,
        "component_units": component_units,
        "micro_skill_tags": tags,
        "micro_kc_id": (
            f"{item.get('knowledge_component_id', 'KC_UNKNOWN')}::"
            f"{template or 'unknown'}::{primary_key}"
        ),
        "content_review_status": (
            (item.get("validation") or {}).get("review_status")
            if isinstance(item.get("validation"), dict)
            else item.get("content_review_status")
        ) or "reviewed_curriculum",
    }
