# Model card — C3 combined profile (multimodal learner-window estimate)

**Status:** research prototype, trained on simulated learners only. Not a diagnostic tool.
**Version:** `C3-v2.1` · features `c3-learner-window-v3` · simulators `c1-sim-v1` + `c3-sim-v2` · 21 Oct 2026

## Purpose
Combine reading, touch-movement and activity evidence from the last 14 days into one learning-pattern estimate, with SHAP explanations, for professional review. Parents see only a plain-language summary; no pattern names or probabilities are shown to them.

## Inputs (14)

| Group | Features | Source |
| --- | --- | --- |
| Reading (C2) | time to start reading, spoken beats vs expected syllables **per syllable**, silence within words, jitter, shimmer | medians over clear oral-reading recordings that were acoustically measured (letter practice excluded) |
| Touch movement | time to first touch, drag directness, drag smoothness (jerk), finger contact time | medians over sessions with touch data; drags resampled to 50 Hz so phones with different touch rates are comparable |
| Activity behaviour (C1) | first-try accuracy, visual-task index, sound-task index, long pauses per round | learner-level C1 features, used when C1's evidence rule passed |
| Context | age in years | birth month and year |

Gender, time of day and the look-alike letter index are not inputs (the letter index is almost never measurable; it stays on the dashboard).

## When it runs
- **Evidence rule:** 2+ clear, acoustically measured reading recordings; 2+ touch sessions; age known; and every input that is always present in training (reading time, beat mismatch, silence, first touch, contact time) must be measured. Otherwise the dashboard lists what is missing.
- **Out-of-range guard:** no estimate if any input is more than 10% outside the training 1st-99th percentile range. If the ranges file is missing or for another version, no estimate is shown (fail closed).
- Jitter/shimmer and C1 inputs may be missing; the model was trained with those gaps (10% of recordings without voice measures; 1,111 learners without C1 evidence).

## Training data
Touch side: `export_c3_simulation.py` (round-level simulator + finger strokes at 60, 90 or 120 Hz, age effect about 12% per year) through the **live** C1 and movement code. Reading side: per-recording simulation from `config/c3_simulation.yaml` (item length 4-24 syllables, beat mismatch as a rate per syllable, no pattern effect on jitter/shimmer). Aggregation with the **live** `services/c3_features.py`. 6,000 learners simulated; 3,852 passed the evidence rule.

## Algorithm
XGBoost `multi:softprob`: 300 trees, depth 4, learning rate 0.06, subsample 0.9. SHAP TreeExplainer gives the top 3 contributions for the predicted class.

## Results on held-out simulated learners (n = 771)

| | Value |
| --- | --- |
| Accuracy | 0.83 |
| Macro F1 | 0.83 |
| Mean Brier score | 0.059 |

| Confidence band | Learners | Mean confidence | Observed accuracy |
| --- | --- | --- | --- |
| 0.4-0.6 | 98 | 0.53 | 0.51 |
| 0.6-0.8 | 131 | 0.70 | 0.71 |
| 0.8-1.0 | 534 | 0.95 | 0.93 |

These show separation of the *simulated* profiles, not validity for real children.

## Limitations
- Reading features are simulated directly, not computed from audio, so the speech-recognition and acoustic pipeline is not part of what was trained.
- The pattern effects in the simulators are hypotheses taken from the literature on reading difficulties, not measured effect sizes.
- Professional agree/disagree reviews are stored with the exact inputs, ready for future calibration.

## Files
`services/c3_features.py` · `services/xai_engine.py` · `main.py` (`/diagnose/session`) · `config/c3_simulation.yaml` · `scripts/train_c3_model.py` · `models/xgboost_clinical_fusion.pkl` · `models/feature_names.pkl` · `models/c3_feature_ranges.json` · `models/c3_model_metrics.json`

Retrain with `python scripts/train_c3_model.py` from `diagnostic-fusion-v1`. The first run generates the touch simulation, which takes about 2 minutes.
