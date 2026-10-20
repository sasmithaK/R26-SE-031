# Model card — C3 combined profile (multimodal learner-window estimate)

**Status:** research prototype, trained on simulated learners only. Not a diagnostic tool.
**Version:** `C3-v2.0` · features `c3-learner-window-v2` · simulators `c1-sim-v1` + `c3-sim-v1` · 21 Oct 2026

## Purpose
Combine reading, touch-movement and activity evidence from the last 14 days into one learning-pattern estimate, with SHAP explanations, for professional review. Parents see only a plain-language summary; no pattern names or probabilities are shown to them.

## Inputs (15)

| Group | Features | Source |
| --- | --- | --- |
| Reading (C2) | time to start reading, beats vs syllables, silence within words, jitter, shimmer | medians over clear recordings |
| Touch movement | time to first touch, look-alike letter choices, drag directness, drag smoothness (jerk), finger contact time | medians over sessions with touch data; directness and smoothness from drag strokes only |
| Activity behaviour (C1) | first-try accuracy, visual-task index, sound-task index, long pauses per round | the learner-level C1 features; used only when C1 had enough evidence |
| Context | age in years | from birth month and year |

Gender and time of day are no longer inputs (v1 used them). Missing values stay missing; XGBoost handles them natively.

## When it runs
- **Evidence rule:** at least 2 clear recordings, at least 2 sessions with touch data, and a known age.
- **Out-of-range guard:** as in C1, with 10% beyond the training 1st–99th percentile range. When it triggers, the dashboard shows which inputs and why.

## Training data
1. **Touch side.** `telemetry-analytics-v1/scripts/export_c3_simulation.py` simulates learners round by round. It uses the C1 simulator plus finger-stroke paths (curvature, tremor, drag duration, drops outside a target), with an age effect of about 12% per year. It then runs the **live** C1 feature code and the **live** movement extractor (`comp2_kinematics.py`).
2. **Reading side.** Recordings are simulated per recording from `config/c3_simulation.yaml`; no audio is generated. Jitter and shimmer get **no** pattern effect.
3. **Aggregation.** Everything is aggregated with the **live** C3 code (`services/c3_features.py`). Learners that fail the evidence rule are dropped.

In total, 6,000 learners were simulated. 3,798 passed the evidence rule, and 1,080 of those had no C1 evidence.

## Algorithm
XGBoost `multi:softprob`: 300 trees, depth 4, learning rate 0.06, subsample 0.9. SHAP TreeExplainer gives the top 3 contributions for the predicted class.

## Results on held-out simulated learners (n = 760)

| | Value |
| --- | --- |
| Accuracy | 0.84 |
| Macro F1 | 0.84 |
| Mean Brier score | 0.061 |

Calibration (mean confidence → observed accuracy):

| Confidence band | Learners | Mean confidence | Observed accuracy |
| --- | --- | --- | --- |
| 0.4–0.6 | 97 | 0.52 | 0.58 |
| 0.6–0.8 | 150 | 0.71 | 0.73 |
| 0.8–1.0 | 510 | 0.94 | 0.93 |

Confidence matches accuracy on the simulated data. These numbers reflect separation of the *simulated* profiles, not validity for real children.

## Limitations
- Reading features are simulated directly, not computed from audio, so the speech-recognition and acoustic pipeline is not part of what was trained.
- The look-alike letter index is rarely measurable: the confusion map covers 3 target letters. It was not simulated, so the model gives it no weight.
- The pattern effects in the simulators are hypotheses taken from the literature on reading difficulties, not measured effect sizes.
- Professional agree/disagree reviews are stored with the exact inputs, ready for future calibration.

## Files
`services/c3_features.py` · `services/xai_engine.py` · `main.py` (`/diagnose/session`) · `config/c3_simulation.yaml` · `scripts/train_c3_model.py` · `models/xgboost_clinical_fusion.pkl` · `models/feature_names.pkl` · `models/c3_feature_ranges.json` · `models/c3_model_metrics.json`

Retrain with `python scripts/train_c3_model.py` from `diagnostic-fusion-v1`. The first run generates the touch simulation, which takes about 2 minutes.
