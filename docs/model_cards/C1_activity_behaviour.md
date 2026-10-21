# Model card — C1 activity behaviour (learner-level pattern estimate)

**Status:** research prototype, trained on simulated learners only. Not a diagnostic tool.
**Version:** `c1_learner_model` 3.0.0 · features `c1-learner-v2` · simulator `c1-sim-v1` · 21 Oct 2026

## Purpose
Summarise how a child interacts with the Skill 1–4 touch activities over the last 14 days. A professional sees it as one input to review. It never labels a child, and parents never see it.

## What it uses
Rounds captured by the app in **Skills 1-4** (the scope the model is trained on; Skill 5 reading questions and letter practice are excluded). Only completed rounds count; duplicate rounds are dropped. Timing inputs use first touch, as in the simulator.

| Group | Features |
| --- | --- |
| Accuracy | first-try accuracy; accuracy trend; share of rounds finished |
| Timing | mean, median and spread of round time; mean time to first touch |
| Behaviour | long pauses (> 8 s), wrong answers and audio replays, each per round |
| Within-session change | slowing, more errors and more pauses late in a session. These are medians over sessions with 4+ rounds: 2 vs 2 rounds for 4–5-round sessions, 3 vs 3 for 6+ |
| Indices (0–100) | visual-task speed, sound-task speed (Skill 2 activities 3–4, Skill 3 activities 1 and 3), wrong taps and pauses, attention stability |
| Scores | fatigue (0–1), effort (0–1) |

Missing values (for example no sound tasks yet) stay missing. The model handles them natively; nothing is filled in.

## When it runs
- **Evidence rule:** at least 20 completed rounds in at least 2 sessions within 14 days. Otherwise the dashboard shows what is still needed.
- **Out-of-range guard:** no estimate if any input lies more than 10% outside the 1st–99th percentile range of the training data. The dashboard lists those inputs and their trained ranges.

## Training data
The simulator `research/c1_simulator.py` (parameters in `config/c1_simulation.yaml`) generates learners round by round:

- per-activity timing and accuracy
- four pattern profiles, applied to each task kind (picture, letter shape, sound–letter, word/sentence)
- individual differences
- wrong taps, long pauses, abandoned rounds, within-session fatigue and audio replays
- 2–12 sessions in 14 days, and how far the learner has progressed through the skills

Features are then computed by the **live** code (`services/c1/learner_window.py`), so training and real data use one definition. In total, 6,000 learners were simulated. 4,162 passed the evidence rule, and 1,689 of those had no sound-task rounds.

The simulator parameters are **provisional**. They are anchored on observed app data (Skill 1 Activity 1 timings) and on the task designs, not on population norms for Sri Lankan Grade 1 children. Calibrate them with `scripts/c1_calibration_report.py`.

## Algorithm
`HistGradientBoostingClassifier` (scikit-learn 1.9.1): 300 iterations at most, depth 5, learning rate 0.08, with early stopping. Classes: TYPICAL, VISUAL_ORTHOGRAPHIC_PATTERN, PHONOLOGICAL_PATTERN, COMBINED_PATTERN.

## Results on held-out simulated learners (n = 833)

| | Value |
| --- | --- |
| Accuracy | 0.72 |
| Macro F1 | 0.71 |
| Accuracy with sound-task evidence | 0.76 |
| Accuracy without sound-task evidence | 0.65 |

Per class (precision / recall): Typical 0.76 / 0.87 · Visual-orthographic 0.67 / 0.61 · Phonological 0.68 / 0.62 · Combined 0.75 / 0.77.

These numbers show that the pipeline separates the *simulated* profiles. They are not evidence of validity for real children.

## Limitations
- Synthetic training only. Real children may differ from the simulator in ways that the out-of-range guard cannot catch.
- "Wrong answers" (`misclick_count`) are knowledge errors, not motor errors. Drops outside a target are stored separately (`stray_drop_count`) and shown on the dashboard, but are not a model input.
- Activity times are not yet normalised per activity.
- Professional reviews are stored with the exact inputs the model saw. Use them to check and later re-weight the model once enough exist.

## Files
`services/c1/learner_window.py` · `services/ml/learner_inference.py` · `research/c1_simulator.py` · `config/c1_simulation.yaml` · `scripts/train_c1_learner_model.py` · `scripts/c1_calibration_report.py` · `models/c1_learner_model.pkl` · `models/c1_learner_model_metrics.json` · `models/c1_learner_feature_ranges.json`
