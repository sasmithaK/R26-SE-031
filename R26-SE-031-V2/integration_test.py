"""
integration_test.py -- R26-SE-031-V2  (v3.0)
==============================================
Full integration test suite covering:
  - All 11 module smoke tests (from smoke_test.py)
  - Trained model loading and inference (LightGBM, RF, LinUCB)
  - End-to-end pipeline: TelemetryPayload → MBSV → downstream services
  - Inter-service schema compliance validation

Usage:
    python R26-SE-031-V2/integration_test.py

Prerequisites:
    Run scripts/run_all_training.py first to generate model artifacts.
"""

import sys, types, pickle, importlib, importlib.util, asyncio
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path
import numpy as np

BASE    = Path(__file__).parent.resolve()
MODELS  = BASE / "models"
C1      = BASE / "monitoring-service-v2"
C2      = BASE / "visual-service-v2"
C3      = BASE / "content-service-v2"
C4      = BASE / "intervention-service-v2"

PASS = 0
FAIL = 0

def _ok(msg):
    global PASS
    PASS += 1
    print(f"  [PASS] {msg}")

def _fail(msg, err=""):
    global FAIL
    FAIL += 1
    print(f"  [FAIL] {msg}  — {err}")

def import_from(name, path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    mod  = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

# ── Register shared package ────────────────────────────────────────────────
sys.path.insert(0, str(BASE))

from shared.database import connect_to_mongo, close_mongo_connection, db_state

async def main():
    await connect_to_mongo()
    # Use a test database so we don't pollute the real one
    if db_state.client:
        db_state.db = db_state.client["dyslexia_platform_test"]

    # ============================================================================
    print("\n" + "="*62)
    print("  MODULE SMOKE TESTS  (11 checks)")
    print("="*62)

    # 0. Shared schemas
    try:
        from shared.schemas import (
            TelemetryPayload, MBSV, MBSVOutput, InterventionCheckPayload,
            TypographyRequest, GuardianIntakePayload, AtRiskResult,
            SymptomProfile, ObservationMatrixSeed, AtRiskFlag, ObservationLevel,
            ActivityType,
        )
        assert "BLENDING_GAME" in [a.value for a in ActivityType]
        _ok("shared/schemas.py — all v3.0 types present, BLENDING_GAME in ActivityType")
    except Exception as e:
        _fail("shared/schemas.py", e)

    # 1. Welford
    try:
        welford = import_from('welford', C1 / 'core' / 'welford.py')
        b = welford.WelfordBaseline('stu_test')
        feats = {k: 0.0 for k in welford.WelfordBaseline.FEATURES}
        feats['hesitation_ms'] = 2000.0
        await b.update(feats); await b.update(feats); await b.update(feats)
        z = b.z_score('hesitation_ms', 3000.0)
        assert isinstance(z, float)
        _ok(f"welford.py  z={round(z,4)}")
    except Exception as e:
        _fail("welford.py", e)

    # 2. BKT engine
    try:
        bkt_mod = import_from('bkt_engine', C3 / 'core' / 'bkt_engine.py')
        bkt = bkt_mod.BKTEngine()
        await bkt.initialize_student('stu_it')
        bf, af = await bkt.update('stu_it', 'S1_vowel_id', is_correct=True)
        assert bkt_mod.MASTERY_THRESHOLD == 0.833
        _ok(f"bkt_engine.py  p_know {round(bf,3)}→{round(af,3)}  threshold=0.833")
    except Exception as e:
        _fail("bkt_engine.py", e)

    # 3. Content selector
    try:
        cs_mod = import_from('content_selector', C3 / 'core' / 'content_selector.py')
        assert cs_mod.MASTERY_THRESHOLD == 0.833
        _ok("content_selector.py  threshold=0.833")
    except Exception as e:
        _fail("content_selector.py", e)

    # 4. Syllable splitter
    try:
        syl_mod = import_from('syllable_splitter', C4 / 'core' / 'syllable_splitter.py')
        segs = syl_mod.split_syllables('\u0d9a\u0dc0\u0dd4')
        assert len(segs) >= 1
        _ok(f"syllable_splitter.py  segs={segs}")
    except Exception as e:
        _fail("syllable_splitter.py", e)

    # 5. SM-2 scheduler
    try:
        sm2_mod = import_from('sm2_scheduler', C4 / 'core' / 'sm2_scheduler.py')
        q = sm2_mod.accuracy_to_quality(82.0)
        assert 0 <= q <= 5
        _ok(f"sm2_scheduler.py  quality={q} for 82%")
    except Exception as e:
        _fail("sm2_scheduler.py", e)

    # 6. LinUCB
    try:
        linucb_mod = import_from('linucb', C2 / 'core' / 'linucb.py')
        arm = linucb_mod.LinUCBArm(0)
        ctx = linucb_mod.build_context_vector(0.7, 0.4, 3, 7, 0.5, 0.4, 0.3)
        arm.update(ctx, 0.5)
        score = arm.ucb_score(ctx)
        assert isinstance(score, float)
        _ok(f"linucb.py  UCB={round(score,4)}")
    except Exception as e:
        _fail("linucb.py", e)

    # 7. Intervention engine
    try:
        pkg_name = 'intervention_core'
        pkg = types.ModuleType(pkg_name)
        pkg.__path__ = [str(C4 / 'core')]
        pkg.__package__ = pkg_name
        sys.modules[pkg_name] = pkg
        sys.modules[pkg_name + '.syllable_splitter'] = syl_mod
        syl_mod.__package__ = pkg_name
        spec = importlib.util.spec_from_file_location(
            pkg_name + '.intervention_engine',
            str(C4 / 'core' / 'intervention_engine.py'),
            submodule_search_locations=[],
        )
        ie_mod = importlib.util.module_from_spec(spec)
        ie_mod.__package__ = pkg_name
        sys.modules[pkg_name + '.intervention_engine'] = ie_mod
        spec.loader.exec_module(ie_mod)
        engine = ie_mod.InterventionEngine()
        result = await engine.check('stu_it', '\u0d9a\u0dc0\u0dd4', 0.6, [0,1,0,0], 6000)
        assert ie_mod.ACT_BLENDING == 'BLENDING_GAME'
        assert ie_mod.PAST_FRUSTRATION_STOP == 3
        _ok(f"intervention_engine.py  stage={result['stage']}  PAST_STOP=3  BLENDING_GAME registered")
    except Exception as e:
        _fail("intervention_engine.py", e)

    # 8. Kalman filter
    try:
        kf_mod = import_from('kalman_filter', C1 / 'core' / 'kalman_filter.py')
        kf = kf_mod.TouchKalmanFilter(dt=0.016)
        for x, y in [(100,200),(108,208),(115,212),(112,210),(118,215)]:
            kf.update(np.array([x,y], dtype=float))
        mi = kf.session_mean_innovation()
        assert mi > 0
        _ok(f"kalman_filter.py  mean_innovation={round(mi,4)}")
    except Exception as e:
        _fail("kalman_filter.py", e)

    # 9. SOVCM
    try:
        sovcm_mod = import_from('sovcm', C2 / 'core' / 'sovcm.py')
        sc = sovcm_mod.compute_sovcm_score('\u0dc1')   # ශ
        assert sc is not None and 0 < sc['composite_score'] <= 1
        tc = sovcm_mod.task_complexity('\u0d9a\u0dc0\u0dd4')
        cl = sovcm_mod.crowding_load('\u0d9a\u0dc0\u0dd4', 2.0)
        _ok(f"sovcm.py  ශ={sc['composite_score']}  task_cpx={round(tc,4)}  crowding={round(cl,4)}")
    except Exception as e:
        _fail("sovcm.py", e)

    # 10-11. Onboarding
    try:
        ob_mod = import_from('onboarding', C3 / 'core' / 'onboarding.py')
        score_val, flag = ob_mod.compute_at_risk_flag({
            'tires_quickly_reading': True, 'many_errors_reading': True,
            'difficulty_spelling_unfamiliar': True, 'words_appear_blurred': True,
        })
        assert flag == 'at_risk_moderate'
        seeds = ob_mod.seed_mastery_from_observation_matrix({
            'phonological_processing': 'Emerging', 'reading_decoding': 'Unsatisfactory',
            'writing_copy_dictation': 'Proficient', 'visual_spatial_attention': 'Proficient',
            'language_comprehension': 'Missing',
        })
        assert seeds['S0_shape_recognition'] == 0.75
        assert seeds['S9_sentence_comprehension'] == 0.05
        _ok(f"onboarding.py  score={score_val} flag={flag}  S0={seeds['S0_shape_recognition']} S9={seeds['S9_sentence_comprehension']}")
    except Exception as e:
        _fail("onboarding.py", e)

    # ============================================================================
    print("\n" + "="*62)
    print("  MODEL INFERENCE TESTS  (3 checks)")
    print("="*62)

    # M1. LightGBM MBSV model
    try:
        lgbm_path = MODELS / "c1_lgbm_mbsv.pkl"
        assert lgbm_path.exists(), "Model not found — run scripts/run_all_training.py first"
        with open(lgbm_path, "rb") as f:
            lgbm_model = pickle.load(f)
        sample = np.array([[3200, 0.75, 2800, 0.65, 120, 3, 3, 18, 950, 1800, 1.4, 4, 12.5]])
        pred = lgbm_model.predict(sample)[0]
        labels = dict(zip(["CLI","PSI","VSI","FI","ES","ERI"], [round(float(v),4) for v in pred]))
        assert all(0 <= v <= 1.2 for v in pred), "Predictions out of expected range"
        _ok(f"c1_lgbm_mbsv.pkl  inference: {labels}")
    except Exception as e:
        _fail("c1_lgbm_mbsv.pkl", e)

    # M2. Random Forest learner type
    try:
        rf_path = MODELS / "c1_learner_type_rf.pkl"
        assert rf_path.exists(), "Model not found — run scripts/run_all_training.py first"
        with open(rf_path, "rb") as f:
            rf_artifact = pickle.load(f)
        rf_model = rf_artifact["model"]
        le        = rf_artifact["label_encoder"]
        sample = np.array([[4, 1, 11, 150, 1500, 4, 750]])
        pred_cls = le.inverse_transform(rf_model.predict(sample))[0]
        proba    = rf_model.predict_proba(sample)[0]
        _ok(f"c1_learner_type_rf.pkl  predicted={pred_cls}  proba={dict(zip(le.classes_,[round(float(p),3) for p in proba]))}")
    except Exception as e:
        _fail("c1_learner_type_rf.pkl", e)

    # M3. LinUCB warm-start agent
    try:
        linucb_path = MODELS / "c2_linucb_agent_warmstart.pkl"
        assert linucb_path.exists(), "Model not found — run scripts/run_all_training.py first"
        agent = linucb_mod.LinUCBAgent.load_or_create(
            str(linucb_path),
            str(C2 / "data" / "arm_presets.json"),
        )
        ctx = linucb_mod.build_context_vector(0.85, 0.2, 30, 8, 0.75, 0.6, 0.80)
        arm = agent.select_arm(ctx)
        stats = agent.get_stats()
        _ok(f"c2_linucb_agent_warmstart.pkl  arm_selected={arm}  total_steps={stats['total_steps']}")
    except Exception as e:
        _fail("c2_linucb_agent_warmstart.pkl", e)

    # ============================================================================
    print("\n" + "="*62)
    print("  END-TO-END PIPELINE TEST  (1 check)")
    print("="*62)

    # E2E: TelemetryPayload → MBSV → InterventionCheckPayload
    try:
        from shared.schemas import (
            TelemetryPayload, MBSVOutput, MBSV, ErrorPatternVector,
            InterventionCheckPayload,
        )

        telemetry = TelemetryPayload(
            student_id="stu_e2e",
            task_id="task_001",
            session_id="sess_001",
            timestamp_ms=1715000000000,
            hesitation_ms=3200,
            swipe_velocity=110.0,
            correction_rate=0.72,
            replay_count=3,
            hint_request_count=2,
            read_aloud_pause_ms=1900,
            syllable_rate=1.3,
            disfluency_count=4,
        )
        assert telemetry.student_id == "stu_e2e"

        epv = ErrorPatternVector(reversal=0, omission=1, substitution=0, hesitation=1)
        mbsv = MBSV(
            cognitive_load_index=0.72,
            phonological_strain_index=0.68,
            visual_strain_index=0.61,
            session_fatigue_index=0.65,
            engagement_index=0.28,
            error_pattern_vector=epv,
        )

        before, after = await bkt.update('stu_e2e', 'S1_vowel_id', is_correct=False)

        ivn_payload = InterventionCheckPayload(
            student_id=telemetry.student_id,
            session_id=telemetry.session_id,
            current_word='\u0d9a\u0dc0\u0dd4',
            phonological_strain_index=mbsv.phonological_strain_index,
            error_pattern_vector=[epv.reversal, epv.omission, epv.substitution, epv.hesitation],
            strain_duration_ms=6500,
        )
        
        result = await engine.check(
            student_id=ivn_payload.student_id,
            current_word=ivn_payload.current_word,
            phonological_strain_index=ivn_payload.phonological_strain_index,
            error_pattern_vector=ivn_payload.error_pattern_vector,
            strain_duration_ms=ivn_payload.strain_duration_ms,
        )

        assert result["stage"] in [0, 1, 2, 3]
        _ok(f"E2E Pipeline: Telemetry→MBSV→BKT→Intervention  stage={result['stage']}  activity={result.get('activity_type','N/A')}")
    except Exception as e:
        _fail("E2E Pipeline", e)

    await close_mongo_connection()

if __name__ == "__main__":
    asyncio.run(main())
    print()
    print("="*62)
    total = PASS + FAIL
    print(f"  RESULTS: {PASS}/{total} passed  |  {FAIL} failed")
    print("="*62)
    if FAIL == 0:
        print("  ALL INTEGRATION TESTS PASSED (v3.0)")
    else:
        print("  SOME TESTS FAILED — check output above")
        sys.exit(1)
