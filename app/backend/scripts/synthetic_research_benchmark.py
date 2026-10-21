"""Reproducible synthetic benchmark for the SipSara C1-C3 research pipelines.

This creates research-only CSV/JSON outputs. It never writes to deployed model
directories or the application database. All labels are simulator scenarios,
not diagnoses or empirically validated child profiles.

Run from the repository root:
  python app/backend/scripts/synthetic_research_benchmark.py --learners-per-class 120
"""
from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import math
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import yaml
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import HistGradientBoostingClassifier, RandomForestClassifier, ExtraTreesClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, balanced_accuracy_score, classification_report,
                             confusion_matrix, f1_score)
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT / "app" / "backend"
C1_ROOT = BACKEND / "telemetry-analytics-v1"
C3_ROOT = BACKEND / "diagnostic-fusion-v1"
CURRICULUM = ROOT / "app" / "frontend" / "assets" / "data" / "curriculum" / "skill_6.json"
CLASS_NAMES = ["TYPICAL", "VISUAL_ORTHOGRAPHIC_PATTERN", "PHONOLOGICAL_PATTERN", "COMBINED_PATTERN"]
C3_CLASS_MAP = {"TYPICAL": 0, "PHONOLOGICAL_PATTERN": 1,
                "VISUAL_ORTHOGRAPHIC_PATTERN": 2, "COMBINED_PATTERN": 3}
C3_CLASS_NAMES = ["Typical Learning Pattern", "Phonological Learning Pattern",
                  "Visual-Orthographic Learning Pattern", "Combined Learning Pattern"]


def _load_c1():
    sys.path.insert(0, str(C1_ROOT))
    from research.c1_simulator import CLASS_NAMES as simulator_classes, load_config, simulate_learner
    from services.c1.learner_window import RULES, build_learner_features, evidence_gaps
    if simulator_classes != CLASS_NAMES:
        raise ValueError("C1 simulator class order changed; update the benchmark mapping explicitly.")
    return load_config, simulate_learner, RULES, build_learner_features, evidence_gaps


def _c1_feature_names() -> list[str]:
    return json.loads((C1_ROOT / "config" / "c1_features.json").read_text(encoding="utf-8"))["features"]


def _load_c2_alignment():
    module_path = BACKEND / "speech-monitoring-v1" / "services" / "sinhala_alignment_service.py"
    spec = importlib.util.spec_from_file_location("sipsara_sinhala_alignment", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module.SinhalaAlignmentService(), module.grapheme_clusters, module.normalize_sinhala


def _read_c3_feature_names() -> list[str]:
    names = joblib.load(C3_ROOT / "models" / "feature_names.pkl")
    if not isinstance(names, list) or len(names) != 13:
        raise ValueError("C3 live feature contract changed; expected the current 13-field schema.")
    expected = {"acoustic_latency_ms", "peak_count_delta", "intra_word_silence_ratio",
                "local_jitter", "local_shimmer", "time_to_first_touch_ms",
                "orthographic_confusion_index", "path_efficiency_ratio", "dimensionless_jerk",
                "dwell_time_ms", "age", "gender", "time_of_day_hour"}
    if set(names) != expected:
        raise ValueError(f"C3 feature contract differs from benchmark mapping: {names}")
    return names


def _attenuate_class_effects(cfg: dict, factor: float) -> dict:
    """Challenge scenario: move effects toward typical while retaining overlap."""
    changed = copy.deepcopy(cfg)
    for pattern, kinds in changed["pattern_effects"].items():
        if pattern == "TYPICAL":
            continue
        for kind, (time_mult, odds_mult) in kinds.items():
            kinds[kind] = [1.0 + factor * (time_mult - 1.0),
                           1.0 + factor * (odds_mult - 1.0)]
    # Wider individual variability makes the held-out scenario deliberately harder.
    changed["individual"]["speed_log_sd"] *= 1.15
    changed["individual"]["round_time_log_sd"] *= 1.15
    return changed


def generate_c1_cohort(cfg: dict, count_per_class: int, seed: int, split: str,
                       feature_names: list[str], scenario: str = "nominal") -> pd.DataFrame:
    _, simulate_learner, rules, build_features, gaps = _load_c1()
    rng = np.random.default_rng(seed)
    output = []
    skipped = 0
    for label, pattern in enumerate(CLASS_NAMES):
        for index in range(count_per_class):
            subject_id = f"syn-{scenario}-{pattern.lower()}-{seed}-{index:05d}"
            _, sessions = simulate_learner(rng, pattern, cfg, subject_id)
            built = build_features(sessions)
            missing = gaps(built["evidence"], rules)
            if missing:
                skipped += 1
                continue
            row = {name: built["features"].get(name) for name in feature_names}
            row.update({"synthetic_subject_id": subject_id, "dataset_id": f"sip-c1-{scenario}-v1",
                        "split": split, "scenario": scenario, "label": pattern,
                        "label_id": label, "data_origin": "fully_synthetic_simulator",
                        "validation_status": "synthetic_scenario_only",
                        "completed_rounds": built["evidence"]["completed_rounds"],
                        "sessions": built["evidence"]["sessions_with_completed_rounds"],
                        "sound_task_rounds": built["evidence"]["sound_task_rounds"]})
            output.append(row)
    frame = pd.DataFrame(output)
    frame.attrs["skipped_below_evidence"] = skipped
    return frame


def _numeric_matrix(frame: pd.DataFrame, names: list[str]) -> np.ndarray:
    return frame[names].apply(pd.to_numeric, errors="coerce").to_numpy(dtype=float)


def _evaluate_models(train: pd.DataFrame, test: pd.DataFrame, names: list[str],
                     label_col: str, labels: list[str], seed: int,
                     frozen_models: dict | None = None) -> tuple[pd.DataFrame, dict]:
    X_train, X_test = _numeric_matrix(train, names), _numeric_matrix(test, names)
    y_train, y_test = train[label_col].to_numpy(), test[label_col].to_numpy()
    candidates = {
        "majority_baseline": DummyClassifier(strategy="most_frequent"),
        "logistic_regression": make_pipeline(SimpleImputer(add_indicator=True), StandardScaler(),
                                             LogisticRegression(max_iter=1500, class_weight="balanced")),
        "random_forest": RandomForestClassifier(n_estimators=350, min_samples_leaf=2,
                                                 class_weight="balanced_subsample", random_state=seed,
                                                 n_jobs=-1),
        "extra_trees": ExtraTreesClassifier(n_estimators=350, min_samples_leaf=2,
                                             class_weight="balanced", random_state=seed, n_jobs=-1),
        "hist_gradient_boosting": HistGradientBoostingClassifier(max_iter=250, learning_rate=0.07,
                                                                  max_leaf_nodes=15, l2_regularization=1.0,
                                                                  random_state=seed),
    }
    frozen_models = frozen_models or {}
    candidates.update(frozen_models)
    metric_rows, details = [], {}
    for name, model in candidates.items():
        is_frozen = name in frozen_models
        if not is_frozen:
            model.fit(X_train, y_train)
        pred = model.predict(X_test)
        matrix = confusion_matrix(y_test, pred, labels=np.arange(len(labels)))
        metric_rows.append({"model": name, "accuracy": accuracy_score(y_test, pred),
                            "balanced_accuracy": balanced_accuracy_score(y_test, pred),
                            "macro_f1": f1_score(y_test, pred, average="macro", zero_division=0),
                            "n_train": 0 if is_frozen else len(y_train), "n_test": len(y_test),
                            "model_source": "existing_runtime_artifact_not_retrained" if is_frozen else "retrained_candidate"})
        details[name] = {"confusion_matrix": matrix.tolist(),
                         "classification_report": classification_report(
                             y_test, pred, labels=np.arange(len(labels)), target_names=labels,
                             output_dict=True, zero_division=0)}
    return pd.DataFrame(metric_rows).sort_values("macro_f1", ascending=False), details


def run_c1(cfg: dict, learners_per_class: int, seed: int, feature_names: list[str]) -> tuple[pd.DataFrame, pd.DataFrame, dict]:
    train_cfg = copy.deepcopy(cfg)
    train_cfg["random_seed"] = seed
    train = generate_c1_cohort(train_cfg, learners_per_class, seed, "train", feature_names)
    # One row per subject; the held-out split is therefore subject-disjoint.
    train_part, nominal_test = train_test_split(train, test_size=0.25, random_state=seed,
                                                stratify=train["label"])
    train_part = train_part.copy()
    nominal_test = nominal_test.copy()
    train_part["split"] = "train"
    nominal_test["split"] = "nominal_test"
    challenge_cfg = _attenuate_class_effects(cfg, 0.55)
    challenge_cfg["random_seed"] = seed + 1
    challenge = generate_c1_cohort(challenge_cfg, max(25, learners_per_class // 2), seed + 1,
                                   "scenario_shift_challenge", feature_names, "shifted")
    runtime_model = joblib.load(C1_ROOT / "models" / "c1_learner_model.pkl")
    if (getattr(runtime_model, "sipsara_feature_schema", None) != "c1-learner-v2"
            or list(getattr(runtime_model, "sipsara_feature_names", [])) != feature_names
            or set(getattr(runtime_model, "classes_", [])) != set(range(len(CLASS_NAMES)))):
        raise ValueError("Current C1 runtime model does not match the learner-feature benchmark contract.")
    runtime = {"current_runtime_c1_learner_model": runtime_model}
    metrics, detail = _evaluate_models(train_part, nominal_test, feature_names, "label_id", CLASS_NAMES,
                                       seed, frozen_models=runtime)
    challenge_metrics, challenge_detail = _evaluate_models(train_part, challenge, feature_names,
                                                             "label_id", CLASS_NAMES, seed, frozen_models=runtime)
    for _, row in challenge_metrics.iterrows():
        detail[row["model"]]["scenario_shift_metrics"] = {
            key: float(row[key]) for key in ("accuracy", "balanced_accuracy", "macro_f1")}
        detail[row["model"]]["scenario_shift_confusion_matrix"] = challenge_detail[row["model"]]["confusion_matrix"]
    metadata = {"skipped_for_evidence_train_generation": int(train.attrs.get("skipped_below_evidence", 0)),
                "eligible_train_rows": len(train), "nominal_training_rows": len(train_part),
                "nominal_test_rows": len(nominal_test), "challenge_rows": len(challenge),
                "subject_overlap_train_test": len(set(train_part.synthetic_subject_id) & set(nominal_test.synthetic_subject_id)),
                "feature_schema": "c1-learner-v2", "features": feature_names,
                "label_order": CLASS_NAMES, "evidence_rule": _load_c1()[2]}
    return pd.concat([train_part, nominal_test, challenge], ignore_index=True), metrics, {"metadata": metadata,
        "nominal": detail, "scenario_shift_metrics": challenge_metrics.to_dict(orient="records"),
        "scenario_shift_details": challenge_detail}


def _c3_scenario_row(rng: np.random.Generator, pattern: str, feature_names: list[str],
                     effect_strength: float = 1.0, noise_scale: float = 1.0) -> dict:
    """Generate paired, noisy C3 modality measures; not Whisper/C1 observations."""
    p = {"TYPICAL": 0, "PHONOLOGICAL_PATTERN": 1,
         "VISUAL_ORTHOGRAPHIC_PATTERN": 2, "COMBINED_PATTERN": 3}[pattern]
    # Overlapping distributions are intentional. Parameters are engineering
    # scenarios, not Grade-1 norms or estimated clinical effect sizes.
    profiles = [
        (260, 0.15, .07, .018, .035, 900, .08, .82, 10, 620),
        (430, 1.05, .21, .035, .065, 1150, .13, .78, 14, 760),
        (340, .35, .12, .023, .045, 1420, .62, .70, 18, 900),
        (510, 1.25, .27, .042, .075, 1600, .53, .65, 22, 1040),
    ]
    typical = profiles[0]
    profile = tuple(base + effect_strength * (value - base) for base, value in zip(typical, profiles[p]))
    values = {
        "acoustic_latency_ms": rng.lognormal(math.log(profile[0]), .32 * noise_scale),
        "peak_count_delta": max(0, rng.poisson(profile[1])),
        "intra_word_silence_ratio": float(np.clip(rng.normal(profile[2], .10 * noise_scale), 0, 1)),
        "local_jitter": max(0, rng.lognormal(math.log(profile[3]), .45 * noise_scale)),
        "local_shimmer": max(0, rng.lognormal(math.log(profile[4]), .42 * noise_scale)),
        "time_to_first_touch_ms": rng.lognormal(math.log(profile[5]), .34 * noise_scale),
        "orthographic_confusion_index": float(np.clip(rng.normal(profile[6], .25 * noise_scale), 0, 1)),
        "path_efficiency_ratio": float(np.clip(rng.normal(profile[7], .12 * noise_scale), .2, 1)),
        "dimensionless_jerk": max(0, rng.lognormal(math.log(profile[8]), .65 * noise_scale)),
        "dwell_time_ms": rng.lognormal(math.log(profile[9]), .34 * noise_scale),
        "age": float(rng.choice([5.0, 6.0, 7.0], p=[.2, .6, .2])),
        "gender": float(rng.choice([0, 1])),
        "time_of_day_hour": float(rng.choice([8, 10, 13, 15, 17])),
    }
    return {name: values[name] for name in feature_names}


def run_c3(count_per_class: int, seed: int, feature_names: list[str]) -> tuple[pd.DataFrame, pd.DataFrame, dict]:
    rng = np.random.default_rng(seed + 300)
    rows = []
    for pattern in CLASS_NAMES:
        for index in range(count_per_class):
            subject_id = f"syn-c3-{pattern.lower()}-{seed}-{index:05d}"
            row = _c3_scenario_row(rng, pattern, feature_names)
            row.update({"synthetic_subject_id": subject_id, "dataset_id": "sip-c3-paired-scenario-v1",
                        "split": "pending", "label": pattern,
                        "label_id": C3_CLASS_MAP[pattern], "data_origin": "fully_synthetic_multimodal_scenario",
                        "validation_status": "synthetic_scenario_only"})
            rows.append(row)
    frame = pd.DataFrame(rows)
    train, test = train_test_split(frame, test_size=.25, random_state=seed, stratify=frame.label_id)
    train = train.copy(); test = test.copy()
    train["split"] = "train"; test["split"] = "subject_disjoint_test"
    challenge_rows = []
    # Independent, noisier and attenuated scenario family: disjoint subjects.
    challenge_rng = np.random.default_rng(seed + 301)
    for pattern in CLASS_NAMES:
        for index in range(max(25, count_per_class // 2)):
            row = _c3_scenario_row(challenge_rng, pattern, feature_names,
                                   effect_strength=.55, noise_scale=1.25)
            subject_id = f"syn-c3-shift-{pattern.lower()}-{seed}-{index:05d}"
            row.update({"synthetic_subject_id": subject_id, "dataset_id": "sip-c3-shift-challenge-v1",
                        "split": "scenario_shift_challenge", "label": pattern,
                        "label_id": C3_CLASS_MAP[pattern], "data_origin": "fully_synthetic_multimodal_scenario",
                        "validation_status": "synthetic_scenario_only"})
            challenge_rows.append(row)
    challenge = pd.DataFrame(challenge_rows)
    runtime_model = joblib.load(C3_ROOT / "models" / "xgboost_clinical_fusion.pkl")
    if (getattr(runtime_model, "n_features_in_", None) != len(feature_names)
            or set(getattr(runtime_model, "classes_", [])) != set(range(len(C3_CLASS_NAMES)))):
        raise ValueError("Current C3 runtime model does not match the live fusion contract.")
    runtime = {"current_runtime_c3_xgboost": runtime_model}
    metrics, detail = _evaluate_models(train, test, feature_names, "label_id", C3_CLASS_NAMES,
                                       seed, frozen_models=runtime)
    challenge_metrics, challenge_detail = _evaluate_models(train, challenge, feature_names,
                                                             "label_id", C3_CLASS_NAMES, seed, frozen_models=runtime)
    for _, row in challenge_metrics.iterrows():
        detail[row["model"]]["scenario_shift_metrics"] = {
            key: float(row[key]) for key in ("accuracy", "balanced_accuracy", "macro_f1")}
        detail[row["model"]]["scenario_shift_confusion_matrix"] = challenge_detail[row["model"]]["confusion_matrix"]
    return pd.concat([train, test, challenge], ignore_index=True), metrics, {
        "subject_overlap_train_test": len(set(train.synthetic_subject_id) & set(test.synthetic_subject_id)),
        "label_order": C3_CLASS_NAMES, "feature_schema": feature_names,
        "train_rows": len(train), "test_rows": len(test), "challenge_rows": len(challenge),
        "nominal": detail, "scenario_shift_metrics": challenge_metrics.to_dict(orient="records")}


def _levenshtein(left: list[str], right: list[str]) -> int:
    previous = list(range(len(right) + 1))
    for i, a in enumerate(left, 1):
        current = [i]
        for j, b in enumerate(right, 1):
            current.append(min(current[-1] + 1, previous[j] + 1, previous[j - 1] + (a != b)))
        previous = current
    return previous[-1]


def _perturb_graphemes(clusters: list[str], rng: np.random.Generator, family: str) -> list[str]:
    if not clusters:
        return clusters
    result = list(clusters)
    eligible = [i for i, cluster in enumerate(result) if cluster.strip()]
    alphabet = list({c for c in clusters if c.strip()})
    if not alphabet:
        return result
    def replacement(original: str) -> str:
        alternatives = [candidate for candidate in alphabet if candidate != original]
        return alternatives[int(rng.integers(len(alternatives)))] if alternatives else original
    if family == "exact":
        return result
    if family == "substitution":
        i = eligible[int(rng.integers(len(eligible)))]; result[i] = replacement(result[i])
    elif family == "deletion":
        result.pop(eligible[int(rng.integers(len(eligible)))])
    elif family == "insertion":
        result.insert(int(rng.integers(len(result) + 1)), alphabet[int(rng.integers(len(alphabet)))])
    elif family == "repetition":
        i = eligible[int(rng.integers(len(eligible)))]; result.insert(i, result[i])
    elif family == "multiple_errors":
        for _ in range(max(2, round(len(result) * .15))):
            op = int(rng.integers(3))
            available = [i for i, cluster in enumerate(result) if cluster.strip()]
            if op == 0 and available:
                i = available[int(rng.integers(len(available)))]
                result[i] = replacement(result[i])
            elif op == 1 and len(available) > 2:
                result.pop(available[int(rng.integers(len(available)))])
            else:
                result.insert(int(rng.integers(len(result) + 1)), alphabet[int(rng.integers(len(alphabet)))])
    return result


def run_c2(seed: int) -> tuple[pd.DataFrame, dict]:
    service, graphemes, normalize = _load_c2_alignment()
    curriculum = json.loads(CURRICULUM.read_text(encoding="utf-8"))
    prompts = [(activity["id"], round_item["item_id"], round_item["prompt"])
               for activity in curriculum[0]["activities"] for round_item in activity.get("rounds", [])]
    rng = np.random.default_rng(seed + 200)
    families = ["exact", "substitution", "deletion", "insertion", "repetition", "multiple_errors"]
    rows = []
    for prompt_index, (activity_id, item_id, expected) in enumerate(prompts):
        reference = []
        for word_index, word in enumerate(normalize(expected).split()):
            if word_index:
                reference.append(" ")
            reference.extend(graphemes(word))
        for family in families:
            recognized = "".join(_perturb_graphemes(reference, rng, family))
            result = service.compare(expected, recognized)
            expected_clusters, observed_clusters = graphemes(expected), graphemes(recognized)
            cp_distance = _levenshtein(list(normalize(expected).replace(" ", "")),
                                       list(normalize(recognized).replace(" ", "")))
            rows.append({"synthetic_subject_id": f"syn-c2-{seed}-{prompt_index:04d}-{family}",
                         "dataset_id": "sip-c2-alignment-v1", "skill_id": "skill_6",
                         "activity_id": activity_id, "item_id": item_id,
                         "expected_text": expected, "recognized_text": recognized,
                         "perturbation_family": family, "word_error_rate": result["word"]["error_rate"],
                         "grapheme_error_rate": result["grapheme"]["error_rate"],
                         "grapheme_accuracy": result["grapheme"]["accuracy"],
                         "grapheme_edit_count": result["grapheme"]["error_count"],
                         "raw_codepoint_edit_count": cp_distance,
                         "reference_graphemes": len(expected_clusters),
                         "observed_graphemes": len(observed_clusters),
                         "exact_match": result["exact_match"],
                         "data_origin": "synthetic_text_perturbation_not_audio",
                         "validation_status": "alignment_algorithm_test_not_asr_accuracy"})
    frame = pd.DataFrame(rows)
    summary = frame.groupby("perturbation_family", as_index=False).agg(
        examples=("item_id", "count"), mean_word_error_rate=("word_error_rate", "mean"),
        mean_grapheme_error_rate=("grapheme_error_rate", "mean"),
        mean_grapheme_accuracy=("grapheme_accuracy", "mean"), exact_match_rate=("exact_match", "mean"))
    return frame, {"summary": summary.to_dict(orient="records"),
                   "interpretation": "C2 reports alignment behavior under controlled text edits; this does not measure Whisper/STT accuracy or child speech performance."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--learners-per-class", type=int, default=120)
    parser.add_argument("--seed", type=int, default=20261021)
    parser.add_argument("--output-dir", type=Path,
                        default=BACKEND / "research" / "synthetic_benchmark_v1")
    args = parser.parse_args()
    if args.learners_per_class < 25:
        parser.error("--learners-per-class must be at least 25 for stratified model comparisons")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    c1_load_config, *_ = _load_c1()
    cfg = c1_load_config()
    c1_names, c3_names = _c1_feature_names(), _read_c3_feature_names()
    c1_data, c1_metrics, c1_details = run_c1(cfg, args.learners_per_class, args.seed, c1_names)
    c3_data, c3_metrics, c3_details = run_c3(args.learners_per_class, args.seed, c3_names)
    c2_data, c2_metrics = run_c2(args.seed)

    c1_data.to_csv(args.output_dir / "c1_learner_scenarios.csv", index=False)
    c3_data.to_csv(args.output_dir / "c3_paired_multimodal_scenarios.csv", index=False)
    c2_data.to_csv(args.output_dir / "c2_skill6_text_alignment.csv", index=False)
    c1_metrics.to_csv(args.output_dir / "c1_model_comparison.csv", index=False)
    c3_metrics.to_csv(args.output_dir / "c3_model_comparison.csv", index=False)
    manifest = {
        "dataset_id": "sipsara-synthetic-benchmark-v1", "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "seed": args.seed, "generator": Path(__file__).name, "generator_version": "1.0.0",
        "data_origin": "fully_synthetic_no_real_child_records", "output_is_research_only": True,
        "c1": c1_details, "c2": c2_metrics, "c3": c3_details,
        "standards_guidance": [
            {"reference": "ISO/IEC 5259-1:2024 and ISO/IEC 5259-2:2024 (https://www.iso.org/standard/81088.html; https://www.iso.org/standard/81860.html)", "application": "document data quality, provenance, schema, utility, and evaluation metrics; no claim of certification"},
            {"reference": "NIST SDNist synthetic data report guidance (https://www.nist.gov/services-resources/software/sdnist-synthetic-data-report-tool)", "application": "report utility/limitations and avoid implying synthetic fidelity proves real-population validity"},
            {"reference": "TRIPOD+AI scope (https://www.tripod-statement.org/scope/)", "application": "make intended use, data provenance, evaluation split, metrics, and limitations explicit; not a diagnostic model validation claim"}
        ],
        "interpretation_limits": [
            "C1/C3 scores measure recovery of labels created by these provisional simulation rules, not real children, learning outcomes, or clinical accuracy.",
            "C2 is deterministic Sinhala text alignment evaluated with controlled edits. It is not an evaluation of Whisper or spoken-child recordings.",
            "Synthetic classes are exploratory behavioral scenarios and must not be described as dyslexia diagnoses or clinical findings.",
            "No generated artifacts are loaded by runtime services; production model directories and MongoDB are not modified."
        ],
        "versions": {"c1_simulator": cfg.get("version"), "c1_feature_schema": "c1-learner-v2",
                     "c2_alignment": "c2-sinhala-alignment-v1", "c3_feature_schema": c3_names}
    }
    (args.output_dir / "benchmark_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output_dir": str(args.output_dir), "c1_rows": len(c1_data),
                      "c2_rows": len(c2_data), "c3_rows": len(c3_data),
                      "c1_models": c1_metrics.to_dict(orient="records"),
                      "c3_models": c3_metrics.to_dict(orient="records")}, indent=2))


if __name__ == "__main__":
    main()
