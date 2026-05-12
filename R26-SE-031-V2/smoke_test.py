"""
smoke_test.py -- R26-SE-031-V2  (v3.0)
Run from: R26-SE-031-V2 or R26-SE-031
Usage: python R26-SE-031-V2/smoke_test.py
"""
import sys, importlib, types
sys.stdout.reconfigure(encoding='utf-8')  # Force UTF-8 on Windows console
from pathlib import Path

BASE = Path(__file__).parent.resolve()
SHARED = BASE / 'shared'
C1    = BASE / 'monitoring-service-v2'
C2    = BASE / 'visual-service-v2'
C3    = BASE / 'content-service-v2'
C4    = BASE / 'intervention-service-v2'

# ── Helper to import a module from an explicit file path ──────────────────
def import_from(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    mod  = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

# ── 0. Shared schemas ─────────────────────────────────────────────────────
sys.path.insert(0, str(BASE))
from shared.schemas import (
    TelemetryPayload, MBSV, MBSVOutput, InterventionCheckPayload,
    TypographyRequest, GuardianIntakePayload, AtRiskResult,
    SymptomProfile, ObservationMatrixSeed, AtRiskFlag, ObservationLevel,
)
print('[OK] shared/schemas.py  (incl. v3.0 onboarding schemas)')

# ── 1. Welford ────────────────────────────────────────────────────────────
welford = import_from('welford', C1 / 'core' / 'welford.py')
b = welford.WelfordBaseline('stu_test', ':memory:')
features = {k: 0.0 for k in welford.WelfordBaseline.FEATURES}
features['hesitation_ms'] = 2000.0
b.update(features)
z = b.z_score('hesitation_ms', 2500.0)
print('[OK] welford.py  z=' + str(round(z, 4)))

# ── 2. BKT engine ─────────────────────────────────────────────────────────
bkt_mod = import_from('bkt_engine', C3 / 'core' / 'bkt_engine.py')
bkt = bkt_mod.BKTEngine(':memory:')
bkt.initialize_student('stu_001')
before, after = bkt.update('stu_001', 'S3_syllable_formation', is_correct=True)
ns = bkt.get_next_skill('stu_001')
assert bkt_mod.MASTERY_THRESHOLD == 0.833, 'BKT threshold not updated to PAST criterion!'
print('[OK] bkt_engine.py  before=' + str(round(before, 3)) + ' after=' + str(round(after, 3)) + ' next=' + ns + '  threshold=0.833')

# ── 3. Content selector ───────────────────────────────────────────────────
cs_mod = import_from('content_selector', C3 / 'core' / 'content_selector.py')
assert cs_mod.MASTERY_THRESHOLD == 0.833, 'ContentSelector threshold not updated!'
print('[OK] content_selector.py  threshold=0.833')

# ── 4. Syllable splitter ──────────────────────────────────────────────────
syl_mod = import_from('syllable_splitter', C4 / 'core' / 'syllable_splitter.py')
segs = syl_mod.split_syllables('\u0d9a\u0dc0\u0dd4')   # කවු
print('[OK] syllable_splitter.py  segs=' + str(segs))

# ── 5. SM-2 scheduler ────────────────────────────────────────────────────
sm2_mod = import_from('sm2_scheduler', C4 / 'core' / 'sm2_scheduler.py')
q = sm2_mod.accuracy_to_quality(82.0)
print('[OK] sm2_scheduler.py  quality=' + str(q) + ' for 82%')

# ── 6. LinUCB ────────────────────────────────────────────────────────────
import numpy as np
linucb_mod = import_from('linucb', C2 / 'core' / 'linucb.py')
arm = linucb_mod.LinUCBArm(0)
ctx = linucb_mod.build_context_vector(0.7, 0.4, 3, 7, 0.5, 0.4, 0.3)
arm.update(ctx, 0.5)
score = arm.ucb_score(ctx)
print('[OK] linucb.py  UCB=' + str(round(score, 4)))

# ── 7. Intervention engine ────────────────────────────────────────────────
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

engine = ie_mod.InterventionEngine(':memory:')
result = engine.check(
    student_id='stu_001',
    current_word='\u0d9a\u0dc0\u0dd4',
    phonological_strain_index=0.6,
    error_pattern_vector=[0, 1, 0, 0],
    strain_duration_ms=6000,
)
assert ie_mod.ACT_BLENDING == 'BLENDING_GAME', 'BLENDING_GAME not registered!'
print('[OK] intervention_engine.py  stage=' + str(result['stage']) + '  BLENDING_GAME registered')

# ========================================================================
# v3.0 NEW CHECKS (8-11)
# ========================================================================

# ── 8. Kalman Filter (C1) ─────────────────────────────────────────────────
kf_mod = import_from('kalman_filter', C1 / 'core' / 'kalman_filter.py')
kf = kf_mod.TouchKalmanFilter(dt=0.016)
for x, y in [(100, 200), (105, 205), (120, 215), (115, 210)]:
    kf.update(np.array([x, y], dtype=float))
mean_innov = kf.session_mean_innovation()
print('[OK] kalman_filter.py  mean_innovation=' + str(round(mean_innov, 4)))

# ── 9. SOVCM (C2) ─────────────────────────────────────────────────────────
sovcm_mod = import_from('sovcm', C2 / 'core' / 'sovcm.py')
score_sha = sovcm_mod.compute_sovcm_score('\u0dc1')            # ශ (high complexity)
assert score_sha is not None, 'SOVCM: character not found in table'
tc = sovcm_mod.task_complexity('\u0d9a\u0dc0\u0dd4')           # කවු
cl = sovcm_mod.crowding_load('\u0d9a\u0dc0\u0dd4', 2.0)
print('[OK] sovcm.py  composite(ශ)=' + str(score_sha['composite_score']) +
      '  task_complexity=' + str(round(tc, 4)) +
      '  crowding_load=' + str(round(cl, 4)))

# ── 10. Guardian Intake Scoring (C3 onboarding) ───────────────────────────
ob_mod = import_from('onboarding', C3 / 'core' / 'onboarding.py')
responses = {
    'tires_quickly_reading':          True,   # 10
    'many_errors_reading':            True,   # 20
    'difficulty_spelling_unfamiliar': True,   # 30
    'words_appear_blurred':           True,   # 30
}  # total = 90 → at_risk_moderate
score_val, flag = ob_mod.compute_at_risk_flag(responses)
assert flag == 'at_risk_moderate', 'Expected at_risk_moderate, got ' + flag
symptom_resp = {'confusion_similar_letters': True, 'omission_of_words': True}
profile = ob_mod.build_symptom_profile(symptom_resp)
assert profile['reversal_priority'] == 2
print('[OK] onboarding.py  score=' + str(score_val) + '  flag=' + flag +
      '  reversal_priority=' + str(profile['reversal_priority']))

# ── 11. Observation Matrix BKT Seeding (C3 onboarding) ───────────────────
mastery_seeds = ob_mod.seed_mastery_from_observation_matrix({
    'phonological_processing':  'Emerging',
    'reading_decoding':         'Unsatisfactory',
    'writing_copy_dictation':   'Proficient',
    'visual_spatial_attention': 'Proficient',
    'language_comprehension':   'Missing',
})
assert mastery_seeds['S0_shape_recognition'] == 0.75, 'S0 should be 0.75'
assert mastery_seeds['S1_vowel_id'] == 0.40,          'S1 should be 0.40'
assert mastery_seeds['S9_sentence_comprehension'] == 0.05, 'S9 should be 0.05'
print('[OK] onboarding.py  observation_matrix_seeding  S0=' +
      str(mastery_seeds['S0_shape_recognition']) +
      '  S1=' + str(mastery_seeds['S1_vowel_id']) +
      '  S9=' + str(mastery_seeds['S9_sentence_comprehension']))

print('')
print('=== ALL 11 MODULE CHECKS PASSED (v3.0) ===')
