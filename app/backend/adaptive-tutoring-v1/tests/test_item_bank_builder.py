import json

from item_bank_builder import (
    DEFAULT_CURRICULUM_DIR,
    build_items,
    normalize_item_id,
    validation_summary,
)


def test_item_bank_is_canonical_complete_and_research_ready():
    items = build_items()
    summary = validation_summary(items)
    ids = [item["item_id"] for item in items]

    assert len(ids) == len(set(ids))
    assert summary["total_items"] >= 150
    assert summary["active_items"] >= 140
    assert summary["unknown_kc"] == 0
    assert summary["runtime_generated_items"] == 0
    assert all(item["allowed_scaffolds"] for item in items)
    assert all(-3.0 <= item["difficulty_b"] <= 3.0 for item in items)
    assert all(item["validation"]["age_band"] == "Grade 1" for item in items)
    assert all(item["validation"]["language"] == "si-LK" for item in items)
    skill_one_kcs = {
        item["knowledge_component_id"]
        for item in items
        if item["skill_id"] == "skill_1"
    }
    assert "KC_VISUAL_SUPPORT" not in skill_one_kcs
    assert "KC_VISUAL_IDENTIFICATION" in skill_one_kcs
    assert "KC_VISUAL_MEMORY" in skill_one_kcs


def test_variants_are_grouped_and_exact_duplicates_are_not_served():
    items = build_items()
    variants = [item for item in items if not item["is_core"]]
    exact_duplicates = [
        item for item in variants if item["validation"]["duplicate_of_core"]
    ]

    assert variants
    assert all(item["equivalent_group_id"] for item in variants)
    assert not exact_duplicates
    assert all(item["is_active"] for item in variants)


def test_every_skill_one_to_four_core_has_distinct_remediation_and_confirmation():
    items = build_items()
    scoped = [
        item for item in items
        if item["skill_id"] in {"skill_1", "skill_2", "skill_3", "skill_4"}
    ]
    by_id = {item["item_id"]: item for item in scoped}
    cores = [item for item in scoped if item["is_core"]]

    assert len(cores) == 97
    for core in cores:
        remediation = by_id[f'{core["item_id"]}V1']
        confirmation = by_id[f'{core["item_id"]}V2']
        assert remediation["item_role"] == "REMEDIATION"
        assert confirmation["item_role"] == "CONFIRMATION"
        if core["has_reduced_remediation"]:
            assert remediation["difficulty_b"] < core["difficulty_b"]
            assert remediation["response_load_relation"] == "reduced"
        else:
            assert remediation["difficulty_b"] == core["difficulty_b"]
            assert remediation["response_load_relation"] == "equivalent"
        assert confirmation["difficulty_b"] == core["difficulty_b"]
        assert confirmation["response_load_relation"] == "equivalent"
        assert len({core["content_hash"], remediation["content_hash"], confirmation["content_hash"]}) == 3


def test_historical_item_ids_normalize_to_one_stable_format():
    assert normalize_item_id("S2_A1_R1") == "S2A1R01"
    assert normalize_item_id("s3-a4-r05v2") == "S3A4R05V2"


def test_pair_matching_variants_never_repeat_a_required_letter():
    pair_variants = [
        item for item in build_items()
        if item["activity_id"] == "2.2" and not item["is_core"]
    ]

    assert len(pair_variants) == 10
    for item in pair_variants:
        values = [
            option["value"] for option in item["options"]
            if option["role"] == "pair_target"
        ]
        assert len(values) == len(set(values)), item["item_id"]


def test_skill_one_sorting_never_classifies_ice_cream_as_fruit():
    sorting_items = [
        item for item in build_items()
        if item["activity_id"] == "1.3"
    ]

    assert sorting_items
    for item in sorting_items:
        fruit_assets = item["content"]["categories"].get("fruits", [])
        assert "fruits_food/ice_cream.png" not in fruit_assets, item["item_id"]


def test_skill_one_client_metadata_uses_the_same_official_kcs_as_item_bank():
    decoded = json.loads(
        (DEFAULT_CURRICULUM_DIR / "skill_1.json").read_text(encoding="utf-8")
    )
    activities = decoded[0]["activities"]
    expected = {
        "act_1": "KC_VISUAL_IDENTIFICATION",
        "act_2": "KC_VISUAL_MATCHING",
        "act_3": "KC_VISUAL_CATEGORIZATION",
        "act_4": "KC_VISUAL_PATTERN",
        "act_5": "KC_VISUAL_MEMORY",
    }

    assert {
        activity["id"]: activity["research_metadata"]["knowledge_component_id"]
        for activity in activities
    } == expected


def _response_load(content):
    if content.get("targets"):
        return int(content.get("target_count", 1)) + len(content.get("distractors") or [])
    if content.get("target_assets"):
        return len(content["target_assets"])
    if content.get("categories"):
        return sum(len(values) for values in content["categories"].values())
    for key in ("options", "items", "letters", "assets", "scrambled_letters", "scrambled_words", "pattern"):
        if content.get(key):
            return len(content[key])
    return 0


def test_remediation_reduces_load_when_valid_and_confirmation_preserves_it():
    items = build_items()
    by_id = {item["item_id"]: item for item in items}
    cores = [item for item in items if item["is_core"] and item["skill_id"] in {
        "skill_1", "skill_2", "skill_3", "skill_4"
    }]

    for core in cores:
        remediation = by_id[f'{core["item_id"]}V1']
        confirmation = by_id[f'{core["item_id"]}V2']
        core_load = _response_load(core["content"])
        remediation_load = _response_load(remediation["content"])
        confirmation_load = _response_load(confirmation["content"])
        assert confirmation_load == core_load, confirmation["item_id"]
        assert remediation_load <= core_load, remediation["item_id"]
        if core["has_reduced_remediation"]:
            has_more_viewing_time = (
                remediation["content"].get("show_milliseconds", 0)
                > core["content"].get("show_milliseconds", 0)
                or remediation["content"].get("show_seconds", 0)
                > core["content"].get("show_seconds", 0)
            )
            assert remediation_load < core_load or has_more_viewing_time, remediation["item_id"]


def test_hidden_search_items_have_stable_target_and_distractor_records():
    items = {
        item["item_id"]: item
        for item in build_items()
        if item["activity_id"] == "1.1" and item["is_core"]
    }

    assert [len(items[f"S1A1R0{round_number}"]["options"])
            for round_number in range(1, 6)] == [4, 7, 9, 12, 15]
    first = items["S1A1R01"]["options"]
    assert first[0]["option_id"] == "S1A1R01_T1"
    assert first[0]["role"] == "target"
    assert {option["role"] for option in first[1:]} == {"distractor"}
