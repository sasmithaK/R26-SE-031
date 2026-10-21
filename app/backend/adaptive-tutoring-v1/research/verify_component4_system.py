"""Offline acceptance check for the Component 4 item and policy pipeline.

This command performs no database writes. It proves that the authored Skills
1–4 bank is structurally complete and that the synthetic research model can
choose and safely translate different supports for different task families.
It is functional verification, not evidence of learning efficacy.
"""

from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from types import SimpleNamespace
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from item_bank_builder import build_items, validation_summary  # noqa: E402
from services.action_policy_model import (  # noqa: E402
    ActionPolicyModel,
    context_features,
)
from services.dynamic_practice_policy import DynamicPracticePolicy  # noqa: E402
from services.item_selector import ItemSelector  # noqa: E402
from services.policy_engine import PolicyEngine  # noqa: E402
from services.practice_metadata import (  # noqa: E402
    derive_practice_metadata,
    normalize_target_unit,
)
from services.practice_selector_model import practice_selector_model  # noqa: E402


SKILLS_IN_SCOPE = {"skill_1", "skill_2", "skill_3", "skill_4"}


def _verify_bank() -> dict[str, Any]:
    """Assert the reviewed item bank has safe equivalent-task coverage."""
    items = build_items()
    summary = validation_summary(items)
    active = [
        item
        for item in items
        if item["is_active"] and item["skill_id"] in SKILLS_IN_SCOPE
    ]
    groups: dict[str, set[str]] = defaultdict(set)
    for item in active:
        groups[item["equivalent_group_id"]].add(item["item_role"])

    missing_confirmation = sorted(
        group_id
        for group_id, roles in groups.items()
        if "CORE" in roles and "CONFIRMATION" not in roles
    )
    invalid_groups = sorted(
        group_id
        for group_id, roles in groups.items()
        if "CORE" not in roles or not roles.issubset(
            {"CORE", "REMEDIATION", "CONFIRMATION"}
        )
    )
    blockers = {
        "duplicate_variants": summary["duplicate_variants"],
        "unknown_kc": summary["unknown_kc"],
        "runtime_generated_items": summary["runtime_generated_items"],
        "missing_confirmation_groups": missing_confirmation,
        "invalid_equivalent_groups": invalid_groups,
    }
    if any(bool(value) for value in blockers.values()):
        raise AssertionError(f"Item-bank acceptance failed: {blockers}")

    role_counts = Counter(item["item_role"] for item in active)
    return {
        "status": "PASS",
        "skills": "1-4",
        "active_items": len(active),
        "core_items": role_counts["CORE"],
        "remediation_items": role_counts["REMEDIATION"],
        "confirmation_items": role_counts["CONFIRMATION"],
        "equivalent_groups": len(groups),
        "shared_floor_retry_groups": sum(
            1
            for roles in groups.values()
            if roles == {"CORE", "CONFIRMATION"}
        ),
        "blockers": blockers,
    }


def _scenario_telemetry(spec: dict[str, Any]) -> SimpleNamespace:
    """Build deterministic telemetry for one scaffold-family scenario."""
    option_count = spec["options"]
    return SimpleNamespace(
        supported_actions=spec["capabilities"],
        original_options_count=option_count,
        minimum_visible_options=2,
        visible_option_ids=[f"OPTION_{index}" for index in range(1, option_count + 1)],
        correct_option_ids=["OPTION_1"],
        total_round_latency_ms=spec["latency_ms"],
        attempt_count=spec.get("attempts", 2),
        incorrect_attempt_count=spec.get("incorrect_attempts", 1),
        hesitation_count=spec["hesitations"],
        misclick_count=1,
        audio_replay_count=spec.get("audio_replays", 0),
    )


def _verify_policy() -> dict[str, Any]:
    """Exercise action ranking and command translation across task families."""
    model = ActionPolicyModel()
    engine = PolicyEngine()
    scenarios = {
        "visual_choice": {
            "capabilities": ["REMOVE_OPTION", "HIGHLIGHT_OPTION"],
            "options": 4,
            "latency_ms": 3500,
            "hesitations": 0,
            "mastery": 0.45,
            "struggle": 2,
            "baseline": "SCAFFOLD_REMOVE_DISTRACTOR",
        },
        "audio_listening": {
            "capabilities": [
                "HIGHLIGHT_OPTION",
                "REPLAY_INSTRUCTION",
                "SLOW_AUDIO",
            ],
            "options": 4,
            "latency_ms": 15000,
            "hesitations": 0,
            "audio_replays": 2,
            "attempts": 3,
            "incorrect_attempts": 2,
            "mastery": 0.10,
            "struggle": 2,
            "fatigue": 0.10,
            "baseline": "SCAFFOLD_HIGHLIGHT_CORRECT",
        },
        "sorting": {
            "capabilities": [
                "HIGHLIGHT_DESTINATION",
                "REPLAY_INSTRUCTION",
            ],
            "options": 3,
            "latency_ms": 15000,
            "hesitations": 0,
            "attempts": 3,
            "incorrect_attempts": 2,
            "mastery": 0.10,
            "struggle": 2,
            "fatigue": 0.50,
            "baseline": "SCAFFOLD_HIGHLIGHT_DESTINATION",
        },
        "sequence": {
            "capabilities": ["REVEAL_FIRST_TOKEN"],
            "options": 5,
            "latency_ms": 9000,
            "hesitations": 1,
            "mastery": 0.50,
            "struggle": 3,
            "baseline": "SCAFFOLD_REVEAL_FIRST_TOKEN",
        },
    }

    results: dict[str, Any] = {}
    for name, spec in scenarios.items():
        telemetry = _scenario_telemetry(spec)
        features = context_features(
            telemetry=telemetry,
            struggle_score=spec["struggle"],
            mastery=spec["mastery"],
            difficulty_b=0.2,
            fatigue=spec.get("fatigue", 0.2),
            behavioral_context={
                "first_attempt_accuracy": 0.40,
                "support_rate": 0.40,
            },
            learner_profile={},
        )
        decision = model.evaluate(
            baseline_action=spec["baseline"],
            telemetry=telemetry,
            features=features,
            requested_mode="simulation_model",
            data_origin="observed",
            assignment_key=f"offline-verification:{name}",
        )
        translated = engine.translate_model_support_action(
            action=decision["applied_action"],
            telemetry=telemetry,
            available_incorrect_ids=telemetry.visible_option_ids[1:],
            adaptive_state={},
        )
        if decision["applied_action"] not in decision["candidate_actions"]:
            raise AssertionError(f"{name}: model selected unsupported action")
        if not decision["controls_live_adaptation"]:
            raise AssertionError(f"{name}: simulation model did not control")
        if translated["decision"] != decision["applied_action"]:
            raise AssertionError(f"{name}: safe translator rejected selected action")
        if not translated["commands"]:
            raise AssertionError(f"{name}: selected support produced no command")

        results[name] = {
            "candidate_actions": decision["candidate_actions"],
            "predicted_success": decision["predicted_next_independent_success"],
            "utility_after_support_cost": decision["action_utilities"],
            "selected_action": decision["applied_action"],
            "rendered_command": translated["commands"][0]["type"],
            "execution_source": decision["execution_source"],
        }

    if len({result["selected_action"] for result in results.values()}) < 4:
        raise AssertionError("Verification contexts did not produce four distinct supports")

    return {
        "status": "PASS",
        "model_version": model.artifact.get("model_version"),
        "validation_status": model.artifact.get("validation_status"),
        "activation_allowed_for_observed_children": model.artifact.get(
            "activation_allowed", False
        ),
        "simulation_disclosure": (
            "Functional synthetic-model verification only; not efficacy evidence."
        ),
        "task_family_results": results,
    }


def _practice_intent(
    core: dict[str, Any],
    *,
    role: str,
) -> dict[str, Any]:
    """Build the diagnosed target contract for practice selection tests."""
    metadata = derive_practice_metadata(core)
    target_units = metadata["primary_targets"]
    component_units = metadata["component_units"]
    # A Skill 1 multi-object task reports the exact failed object at ATTEMPT
    # time. Mirror that runtime contract here instead of asking the verifier's
    # model to rank against every image displayed in the core task at once.
    if core.get("skill_id") == "skill_1" and target_units:
        target_units = target_units[:1]
        component_units = target_units[:]
    return {
        "role": role,
        "origin_item_id": core["item_id"],
        "origin_equivalent_group_id": core["equivalent_group_id"],
        "target_units": target_units,
        "component_units": component_units,
        "error_tags": metadata["micro_skill_tags"],
        "micro_kc_id": metadata["micro_kc_id"],
        "diagnostic_confidence": 0.85,
        "allow_confirmation_as_floor": (
            role == "REMEDIATION"
            and not core.get("has_reduced_remediation", False)
        ),
    }


def _verify_targeted_practice() -> dict[str, Any]:
    """Verify local practice selection without cross-activity target carryover."""
    items = [
        item
        for item in build_items()
        if item["is_active"] and item["skill_id"] in SKILLS_IN_SCOPE
    ]
    cores = [item for item in items if item["is_core"]]
    by_activity: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_id = {item["item_id"]: item for item in items}
    for item in items:
        by_activity[item["activity_id"]].append(item)

    selector = ItemSelector()
    missing_metadata: list[str] = []
    missing_remediation_pool: list[str] = []
    missing_confirmation_pool: list[str] = []
    wrong_scope_selections: list[str] = []
    wrong_difficulty_selections: list[str] = []
    exact_target_selections = 0
    sampled_routes: dict[str, dict[str, Any]] = {}

    for core in cores:
        metadata = derive_practice_metadata(core)
        if not (
            metadata["micro_kc_id"]
            and metadata["micro_skill_tags"]
            and metadata["component_units"]
        ):
            missing_metadata.append(core["item_id"])

        selected_for_core: dict[str, str] = {}
        for role in ("REMEDIATION", "CONFIRMATION"):
            intent = _practice_intent(core, role=role)
            target_b = float(core["difficulty_b"])
            if role == "REMEDIATION" and core.get(
                "has_reduced_remediation", False
            ):
                target_b = max(-3.0, target_b - 0.5)
            result = selector.select_targeted_practice_item(
                current_item_id=core["item_id"],
                current_activity=core["activity_id"],
                knowledge_component_id=core["knowledge_component_id"],
                target_difficulty=target_b,
                candidates=by_activity[core["activity_id"]],
                selection_intent=intent,
                requested_mode="simulation_model",
                data_origin="synthetic",
            )
            selected_id = result.get("selected_item")
            if not selected_id:
                target = (
                    missing_remediation_pool
                    if role == "REMEDIATION"
                    else missing_confirmation_pool
                )
                target.append(core["item_id"])
                continue
            selected = by_id[selected_id]
            selected_for_core[role.lower()] = selected_id
            if (
                selected["activity_id"] != core["activity_id"]
                or selected["knowledge_component_id"]
                != core["knowledge_component_id"]
                or selected["is_core"]
                or selected.get("equivalent_group_id")
                != core.get("equivalent_group_id")
            ):
                wrong_scope_selections.append(
                    f"{core['item_id']}->{selected_id}"
                )
            allowed_roles = {role}
            if intent.get("allow_confirmation_as_floor"):
                allowed_roles.add("CONFIRMATION")
            difficulty_distances = [
                abs(float(candidate["difficulty_b"]) - target_b)
                for candidate in by_activity[core["activity_id"]]
                if candidate["is_active"]
                and not candidate["is_core"]
                and candidate["item_role"] in allowed_roles
                and candidate["item_id"] != core["item_id"]
                and candidate.get("equivalent_group_id")
                == core.get("equivalent_group_id")
            ]
            selected_distance = abs(
                float(selected["difficulty_b"]) - target_b
            )
            reduced_by_reviewed_structure = (
                role == "REMEDIATION"
                and core.get("has_reduced_remediation", False)
                and selected.get("response_load_relation")
                in {"reduced", "targeted_reduced"}
            )
            if not reduced_by_reviewed_structure and (
                not difficulty_distances
                or selected_distance > min(difficulty_distances) + 1e-9
            ):
                wrong_difficulty_selections.append(
                    f"{core['item_id']}->{selected_id}"
                )
            if result.get("selection_reason") == (
                "EXACT_TARGET_REVIEWED_ITEM_SELECTED"
            ):
                exact_target_selections += 1

        if core["item_id"] in {
            "S1A1R02", "S2A2R02", "S3A1R02", "S4A4R03"
        }:
            sampled_routes[core["item_id"]] = selected_for_core

    exact_variants = [
        item
        for item in items
        if item.get("response_load_relation")
        in {"targeted_reduced", "targeted_equivalent"}
    ]
    invalid_exact_variants: list[str] = []
    for variant in exact_variants:
        core = by_id.get(variant["equivalent_group_id"])
        if core is None:
            invalid_exact_variants.append(variant["item_id"])
            continue
        core_metadata = derive_practice_metadata(core)
        variant_metadata = derive_practice_metadata(variant)
        core_targets = set(core_metadata["primary_targets"])
        variant_targets = set(variant_metadata["primary_targets"])
        core_units = core_targets.union(core_metadata["component_units"])
        variant_units = variant_targets.union(
            variant_metadata["component_units"]
        )
        targeted_unit = normalize_target_unit(
            variant.get("targeted_unit")
            or (variant.get("content") or {}).get("targeted_unit")
            or ""
        )
        # Multi-object Skill 1 activities intentionally create one reviewed
        # pair per diagnosed object. Requiring every object from the core task
        # to be repeated in every variant would defeat exact targeting. A
        # targeted variant is valid when its declared unit belongs to both the
        # originating core item and the rendered variant. Sequence-memory
        # errors are positional tokens, so their exact unit can validly live
        # in component_units while the primary target remains the whole word.
        # Legacy variants without the declaration must overlap a core target.
        if targeted_unit:
            valid_target = (
                targeted_unit in core_units
                and targeted_unit in variant_units
            )
        else:
            valid_target = bool(core_targets.intersection(variant_targets))
        if not core_targets or not valid_target:
            invalid_exact_variants.append(variant["item_id"])

    # Exercise the bounded state machine independently of HTTP/MongoDB.
    policy = DynamicPracticePolicy()
    state: dict[str, Any] = {}
    sample_core = by_id["S1A1R02"]
    profile = {
        "equivalent_group_id": sample_core["equivalent_group_id"],
        "micro_kc_id": sample_core["micro_kc_id"],
        "target_units": sample_core["primary_targets"],
        "component_units": sample_core["component_units"],
        "error_tags": sample_core["micro_skill_tags"],
        "diagnostic_confidence": 0.85,
    }
    first = policy.get_next_action(
        activity_id=sample_core["activity_id"],
        current_item_id=sample_core["item_id"],
        item_role="CORE",
        response_quality="ASSISTED_SUCCESS",
        current_b=float(sample_core["difficulty_b"]),
        state=state,
        error_profile=profile,
        policy_reason=[],
        has_reduced_remediation=True,
        has_floor_remediation=False,
    )
    second = policy.get_next_action(
        activity_id=sample_core["activity_id"],
        current_item_id="S1A1R02V3",
        item_role="REMEDIATION",
        response_quality="CLEAN_SUCCESS",
        current_b=float(by_id["S1A1R02V3"]["difficulty_b"]),
        state=state,
        error_profile=profile,
        policy_reason=[],
        has_reduced_remediation=True,
        has_floor_remediation=False,
    )
    third = policy.get_next_action(
        activity_id=sample_core["activity_id"],
        current_item_id="S1A1R02V4",
        item_role="CONFIRMATION",
        response_quality="CLEAN_SUCCESS",
        current_b=float(by_id["S1A1R02V4"]["difficulty_b"]),
        state=state,
        error_profile=profile,
        policy_reason=[],
        has_reduced_remediation=True,
        has_floor_remediation=False,
    )
    state_machine_path = [
        first["next_phase"], second["next_phase"], third["next_phase"]
    ]
    expected_path = ["REMEDIATION", "CONFIRMATION", "CORE"]

    blockers = {
        "missing_practice_metadata": missing_metadata,
        "missing_remediation_pools": missing_remediation_pool,
        "missing_confirmation_pools": missing_confirmation_pool,
        "wrong_scope_selections": wrong_scope_selections,
        "wrong_difficulty_selections": wrong_difficulty_selections,
        "invalid_exact_target_variants": invalid_exact_variants,
        "state_machine_path_mismatch": (
            [] if state_machine_path == expected_path else [state_machine_path]
        ),
    }
    if any(bool(value) for value in blockers.values()):
        raise AssertionError(
            f"Targeted-practice acceptance failed: {blockers}"
        )

    artifact = practice_selector_model.artifact
    return {
        "status": "PASS",
        "policy_version": DynamicPracticePolicy.version,
        "model_version": artifact.get("model_version"),
        "validation_status": artifact.get("validation_status"),
        "activation_allowed_for_observed_children": artifact.get(
            "activation_allowed", False
        ),
        "simulation_controls_functionally": True,
        "skill_1_2_practice_flow": (
            "local_exact_target_remediation_confirmation"
        ),
        "skill_1_2_cross_activity_target_memory": "disabled",
        "dynamic_scope": "skills_1_4_local_same_activity_only",
        "simulation_disclosure": (
            "Synthetic-trained selection is functional verification, not "
            "Grade-1 learning-efficacy evidence."
        ),
        "core_items_checked": len(cores),
        "remediation_pools_checked": len(cores),
        "confirmation_pools_checked": len(cores),
        "exact_target_variants": len(exact_variants),
        "exact_target_model_selections": exact_target_selections,
        "bounded_limits": {
            "max_remediation_items": policy.max_remediation_items,
            "max_confirmation_items": policy.max_confirmation_items,
        },
        "verified_state_machine_path": state_machine_path,
        "sampled_dynamic_routes": sampled_routes,
        "held_out_metrics": artifact.get("held_out_group_evaluation"),
        "blockers": blockers,
    }


def main() -> None:
    """Run and print the complete offline Component 4 acceptance report."""
    result = {
        "component": "C4_ADAPTIVE_TUTORING",
        "overall_status": "PASS",
        "item_bank": _verify_bank(),
        "scaffold_action_model": _verify_policy(),
        "dynamic_targeted_practice": _verify_targeted_practice(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
