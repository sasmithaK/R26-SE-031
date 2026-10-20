# Synthetic research benchmark (C1-C3)

This is an isolated demonstration and model-comparison workflow. It writes only to `app/backend/research/synthetic_benchmark_v1/`; it does not touch MongoDB, deployed models, or runtime model registries.

From the repository root, with the backend virtual environment active:

```powershell
python app/backend/scripts/synthetic_research_benchmark.py --learners-per-class 120 --seed 20261021
jupyter notebook app/backend/scripts/synthetic_research_benchmark/synthetic_datasets_and_accuracies.ipynb
```

The notebook calls the same script with a smaller cohort for a quick viva demonstration. Run the command above first for the full CSV/JSON outputs, or execute the notebook's first code cell to generate them.

## What the benchmark evaluates

- C1 generates round events using the existing `c1_simulator.py`, then computes features with the exact live `build_learner_features` code. Comparisons include the unchanged current runtime artifact plus a majority baseline, logistic regression, random forest, extra trees, and histogram gradient boosting. The normal holdout is subject-disjoint; a separately generated lower-signal/noisier scenario challenges distribution shift.
- C2 uses real Grade 1 Skill 6 reading prompts from the curriculum JSON and the live Sinhala alignment service. It applies exact, substitution, deletion, insertion, repetition, and mixed text edits. Reported values are word/grapheme alignment error rates—not speech-recognition accuracy.
- C3 creates joint synthetic speech/touch/context feature rows with the live 13-feature contract, then compares the unchanged current runtime XGBoost artifact against a majority baseline, logistic regression, random forest, extra trees, and histogram gradient boosting. These rows are not assembled from the C1/C2 datasets, actual Whisper output, or app observations; this is a controlled fusion-schema demonstration, not an update of the deployed XGBoost model.

## Data-quality and reporting safeguards

Each row has a synthetic subject ID, dataset ID, split, label provenance, and validation status. No subject appears in both the normal train and test cohorts. The manifest records the seed, feature schemas, class orders, evidence rules, metrics, and limitations. Newly fitted candidates are trained in memory for the comparison; current runtime artifacts are scored unchanged. No model artifact is saved or registered by this workflow. The challenge cohort is generated independently and is not used to fit models.

The workflow is informed by [ISO/IEC 5259-1](https://www.iso.org/standard/81088.html) and [ISO/IEC 5259-2](https://www.iso.org/standard/81860.html) data-quality guidance, the [NIST SDNist synthetic-data report tool](https://www.nist.gov/services-resources/software/sdnist-synthetic-data-report-tool), and [TRIPOD+AI reporting guidance](https://www.tripod-statement.org/scope/). It does not assert certification, clinical validity, or normative status. The simulator values in `config/c1_simulation.yaml` are provisional engineering assumptions, not population norms. Synthetic accuracy only shows that models can recover synthetic scenario labels under stated assumptions. C2 alignment scores do not measure Whisper. Never present these as diagnostic accuracy.

The app-facing dashboard should not disclose simulator provenance as a product feature; research reporting and viva materials must, however, state it clearly.
