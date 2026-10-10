"""Build and validate the Component 4 research item bank from curriculum data.

This module is intentionally free of database imports so it can be tested in
CI. `seed_item_bank.py` is the small MongoDB writer entry point.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from curriculum_mapping import ACTIVITY_TO_KC


APP_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CURRICULUM_DIR = APP_ROOT / "frontend" / "assets" / "data" / "curriculum"
RUNTIME_GENERATED_ROUNDS = 5


def normalize_item_id(value: str) -> str:
    compact = value.replace("_", "").replace("-", "")
    match = re.fullmatch(r"S(\d+)A(\d+)R(\d+)(V\d+)?", compact, re.IGNORECASE)
    if not match:
        return value
    return (
        f"S{match.group(1)}A{match.group(2)}"
        f"R{int(match.group(3)):02d}{match.group(4) or ''}"
    ).upper()


def _activity_id(skill_id: str, activity_id: str) -> str:
    skill = re.search(r"\d+", skill_id)
    activity = re.search(r"\d+", activity_id)
    return f"{skill.group() if skill else '0'}.{activity.group() if activity else '0'}"


def _number(value: str) -> str:
    match = re.search(r"\d+", value)
    return match.group() if match else "0"


def _content_hash(content: Dict[str, Any]) -> str:
    encoded = json.dumps(content, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()[:16]


def _capabilities(template: str) -> List[str]:
    if "jumbled" in template or "pattern" in template or "memory" in template:
        return ["HIGHLIGHT_OPTION", "REVEAL_FIRST_TOKEN", "REPLAY_INSTRUCTION"]
    if "sorting" in template:
        return ["HIGHLIGHT_DESTINATION", "SHOW_WORKED_EXAMPLE", "REPLAY_INSTRUCTION"]
    if "matching" in template or "match" in template:
        return ["REMOVE_OPTION", "HIGHLIGHT_OPTION", "REPLAY_INSTRUCTION"]
    if "story" in template or "reading" in template:
        return ["REPLAY_INSTRUCTION", "SLOW_AUDIO", "SHOW_WORKED_EXAMPLE"]
    return ["REMOVE_OPTION", "HIGHLIGHT_OPTION", "REPLAY_INSTRUCTION"]


def _difficulty(round_number: int, total: int) -> float:
    if total <= 1:
        return 0.0
    return round(-1.0 + (2.0 * (round_number - 1) / (total - 1)), 2)


def _option_records(item_id: str, content: Dict[str, Any]) -> List[Dict[str, Any]]:
    sequence_key = next(
        (key for key in ("pattern", "scrambled_letters", "scrambled_words") if content.get(key)),
        None,
    )
    raw_options = (
        content.get("options") or content.get("letters") or
        content.get("items") or (content.get(sequence_key) if sequence_key else []) or []
    )
    if not raw_options and content.get("targets"):
        raw_targets = content.get("targets") or []
        raw_distractors = content.get("distractors") or []
        targets = list(raw_targets) if isinstance(raw_targets, list) else [raw_targets]
        distractors = (
            list(raw_distractors)
            if isinstance(raw_distractors, list)
            else [raw_distractors]
        )
        target_count = max(1, int(content.get("target_count", len(targets)) or 1))
        records = []
        for index in range(target_count):
            records.append({
                "option_id": f"{item_id}_T{index + 1}",
                "value": targets[index % len(targets)],
                "role": "target",
                "distractor_type": None,
            })
        for index, value in enumerate(distractors):
            records.append({
                "option_id": f"{item_id}_D{index + 1}",
                "value": value,
                "role": "distractor",
                "distractor_type": "visual",
            })
        return records
    if not isinstance(raw_options, list):
        return []
    correct_value = content.get("correctOption") or content.get("correct_option")
    correct_index = content.get("correct_index")
    correct_indices = set(content.get("correct_indices") or [])
    records = []
    for index, raw in enumerate(raw_options):
        value = raw.get("value") if isinstance(raw, dict) else raw
        is_target = bool(raw.get("is_target")) if isinstance(raw, dict) else False
        is_target = is_target or index == correct_index or index in correct_indices or value == correct_value
        role = "target" if is_target else "distractor"
        if content.get("letters") is raw_options:
            role = "pair_target"
        elif sequence_key is not None:
            role = "sequence_token"
        records.append({
            "option_id": f"{item_id}_O{index + 1}",
            "value": value,
            "role": role,
            "distractor_type": (
                raw.get("distractor_type", "unspecified")
                if isinstance(raw, dict) and not is_target
                else None
            ),
        })
    return records


def _item_document(
    *,
    skill_id: str,
    activity: Dict[str, Any],
    round_number: int,
    total_rounds: int,
    round_data: Dict[str, Any],
    content: Dict[str, Any],
    item_id: str,
    item_role: str,
    equivalent_group_id: str,
    source: str,
    base_hash: Optional[str] = None,
) -> Dict[str, Any]:
    research = activity.get("research_metadata") or {}
    canonical_activity_id = _activity_id(skill_id, activity.get("id", "act_0"))
    difficulty_b = float(round_data.get("difficulty_b", _difficulty(round_number, total_rounds)))
    content_hash = _content_hash(content)
    duplicate_of_core = base_hash is not None and content_hash == base_hash
    options = _option_records(item_id, content)
    option_count = len(options)
    return {
        "item_id": normalize_item_id(item_id),
        "item_version": int(round_data.get("item_version", 1)),
        "skill_id": skill_id,
        "activity_id": canonical_activity_id,
        "template_type": activity.get("template_type", "unknown"),
        "knowledge_component_id": ACTIVITY_TO_KC.get(
            canonical_activity_id,
            research.get("knowledge_component_id", "KC_UNKNOWN"),
        ),
        "prompt_modality": research.get("prompt_modality", "visual"),
        "response_modality": research.get("response_modality", "tap"),
        "round": round_number,
        "difficulty_label": round_data.get("difficulty_label", "medium"),
        "difficulty_b": difficulty_b,
        "difficulty_source": "expert_provisional",
        "calibration_status": "not_empirically_calibrated",
        "calibration_sample_count": 0,
        "discrimination_a": float(round_data.get("discrimination_a", 1.0)),
        "guessing_c": round(1.0 / option_count, 3) if option_count else 0.0,
        "is_anchor": bool(round_data.get("is_anchor", False)),
        "is_core": item_role == "CORE",
        "item_role": item_role,
        "equivalent_group_id": equivalent_group_id,
        "has_reduced_remediation": bool(
            round_data.get("has_reduced_remediation", False)
        ),
        **(
            {
                "has_floor_remediation": bool(
                    round_data.get("has_floor_remediation", False)
                )
            }
            if "has_floor_remediation" in round_data
            else {}
        ),
        "remediation_source_round": round_data.get(
            "remediation_source_round"
        ),
        "remediation_strategy": round_data.get("remediation_strategy"),
        "response_load_relation": round_data.get(
            "response_load_relation",
            "core" if item_role == "CORE" else "equivalent",
        ),
        "distractor_strategy": round_data.get("distractor_strategy"),
        "difficulty_features": round_data.get("difficulty_features"),
        "allowed_scaffolds": _capabilities(activity.get("template_type", "")),
        "minimum_visible_options": 2,
        "options": options,
        "content": content,
        "content_hash": content_hash,
        "source": source,
        "requires_runtime_snapshot": source == "runtime_generator",
        "validation": {
            "duplicate_of_core": duplicate_of_core,
            "review_status": "needs_content_revision" if duplicate_of_core else "structure_validated",
            "age_band": "Grade 1",
            "language": "si-LK",
        },
        # Exact duplicate variants remain traceable but are excluded from
        # ordinary candidate selection until an educator replaces the content.
        "is_active": not duplicate_of_core,
    }


def build_items(curriculum_dir: Optional[Path] = None) -> List[Dict[str, Any]]:
    curriculum_dir = Path(curriculum_dir or DEFAULT_CURRICULUM_DIR)
    documents: List[Dict[str, Any]] = []
    for path in sorted(curriculum_dir.glob("skill_*.json")):
        decoded = json.loads(path.read_text(encoding="utf-8"))
        skill = decoded[0] if isinstance(decoded, list) else decoded
        skill_id = skill.get("id", path.stem)
        for activity in skill.get("activities", []):
            rounds = activity.get("rounds") or activity.get("core_rounds") or []
            source = "curriculum_json"
            if not rounds:
                source = "runtime_generator"
                rounds = [
                    {
                        "item_id": (
                            f"S{_number(skill_id)}"
                            f"A{_number(activity.get('id', '0'))}R{index:02d}"
                        ),
                        "difficulty_b": _difficulty(index, RUNTIME_GENERATED_ROUNDS),
                        "difficulty_label": (
                            "easy" if index <= 2 else "medium" if index <= 4 else "hard"
                        ),
                        "generator_seed": f"{skill_id}:{activity.get('id')}:{index}:v1",
                    }
                    for index in range(1, RUNTIME_GENERATED_ROUNDS + 1)
                ]

            total = len(rounds)
            for round_index, round_data in enumerate(rounds, start=1):
                content = round_data.get("content") or round_data
                base_id = normalize_item_id(
                    str(round_data.get("item_id") or
                        f"S{_number(skill_id)}"
                        f"A{_number(activity.get('id', '0'))}R{round_index:02d}")
                )
                group_id = str(round_data.get("equivalent_group_id") or base_id)
                core = _item_document(
                    skill_id=skill_id,
                    activity=activity,
                    round_number=round_index,
                    total_rounds=total,
                    round_data=round_data,
                    content=content,
                    item_id=base_id,
                    item_role="CORE",
                    equivalent_group_id=group_id,
                    source=source,
                )
                documents.append(core)

                for variant_index, variant in enumerate(round_data.get("adaptive_variants") or [], start=1):
                    variant_name = str(variant.get("variant_id") or f"V{variant_index}")
                    variant_id = normalize_item_id(str(variant.get("item_id") or f"{base_id}{variant_name}"))
                    variant_content = variant.get("content") or variant
                    role = str(variant.get("item_role") or (
                        "REMEDIATION" if variant_index == 1 else "CONFIRMATION"
                    )).upper()
                    documents.append(_item_document(
                        skill_id=skill_id,
                        activity=activity,
                        round_number=round_index,
                        total_rounds=total,
                        round_data={**round_data, **variant},
                        content=variant_content,
                        item_id=variant_id,
                        item_role=role,
                        equivalent_group_id=group_id,
                        source=source,
                        base_hash=core["content_hash"],
                    ))

    seen = set()
    duplicates = []
    for document in documents:
        if document["item_id"] in seen:
            duplicates.append(document["item_id"])
        seen.add(document["item_id"])
    if duplicates:
        raise ValueError(f"Duplicate canonical item IDs: {sorted(set(duplicates))}")
    return documents


def validation_summary(items: Iterable[Dict[str, Any]]) -> Dict[str, Any]:
    items = list(items)
    return {
        "total_items": len(items),
        "active_items": sum(1 for item in items if item["is_active"]),
        "core_items": sum(1 for item in items if item["is_core"]),
        "equivalent_variants": sum(1 for item in items if not item["is_core"]),
        "duplicate_variants": sum(
            1 for item in items if item["validation"]["duplicate_of_core"]
        ),
        "unknown_kc": sum(
            1 for item in items if item["knowledge_component_id"] == "KC_UNKNOWN"
        ),
        "runtime_generated_items": sum(
            1 for item in items if item["source"] == "runtime_generator"
        ),
    }
