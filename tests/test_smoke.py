"""
tests/test_smoke.py -- R26-SE-031  (v3.0)
Run from: repository root
Usage: python tests/test_smoke.py
"""
import sys, importlib, types
sys.stdout.reconfigure(encoding='utf-8')  # Force UTF-8 on Windows console
from pathlib import Path

BASE = Path(__file__).parent.parent.resolve()
SHARED = BASE / 'shared'
C1    = BASE / 'monitoring-service-v1'
C2    = BASE / 'visual-service-v1'
C3    = BASE / 'content-service-v1'
C4    = BASE / 'intervention-service-v1'

# â”€â”€ Helper to import a module from an explicit file path â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
def import_from(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    mod  = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

# â”€â”€ 0. Shared schemas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
sys.path.insert(0, str(BASE))
from shared.schemas import (
    TelemetryPayload, MBSV, MBSVOutput, InterventionCheckPayload,
    TypographyRequest, GuardianIntakePayload, AtRiskResult,
    SymptomProfile, ObservationMatrixSeed, AtRiskFlag, ObservationLevel,
)
print('[OK] shared/schemas.py  (incl. v3.0 onboarding schemas)')

# â”€â”€ 1. Welford â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
welford = import_from('welford', C1 / 'core' / 'welford.py')
# WelfordBaseline.update() is async/Mongo-backed now; test the pure math core.
state = welford.WelfordFeatureState()
for v in (1800.0, 2000.0, 2200.0):
    state.update(v)
z = state.z_score(2500.0)
assert state.count == 3 and z > 0
print('[OK] welford.py  z=' + str(round(z, 4)))

# â”€â”€ 2. BKT engine â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
bkt_mod = import_from('bkt_engine', C3 / 'core' / 'bkt_engine.py')
# BKTEngine is async/Mongo-backed now; test the pure BKT state math.
skill_state = bkt_mod.BKTSkillState(student_id='stu_001', skill_id='S3_syllable_formation')
before, after = skill_state.update(is_correct=True)
assert after > before, 'BKT p_know did not increase after a correct answer!'
assert bkt_mod.MASTERY_THRESHOLD == 0.833, 'BKT threshold not updated to PAST criterion!'
print('[OK] bkt_engine.py  before=' + str(round(before, 3)) + ' after=' + str(round(after, 3)) + '  threshold=0.833')

# â”€â”€ 3. Content selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
cs_mod = import_from('content_selector', C3 / 'core' / 'content_selector.py')
assert cs_mod.MASTERY_THRESHOLD == 0.833, 'ContentSelector threshold not updated!'
print('[OK] content_selector.py  threshold=0.833')

# â”€â”€ 4. Syllable splitter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
syl_mod = import_from('syllable_splitter', C4 / 'core' / 'syllable_splitter.py')
segs = syl_mod.split_syllables('\u0d9a\u0dc0\u0dd4')   # à¶šà·€à·”
print('[OK] syllable_splitter.py  segs=' + str(segs))

# â”€â”€ 5. SM-2 scheduler â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
sm2_mod = import_from('sm2_scheduler', C4 / 'core' / 'sm2_scheduler.py')
q = sm2_mod.accuracy_to_quality(82.0)
print('[OK] sm2_scheduler.py  quality=' + str(q) + ' for 82%')

# â”€â”€ 6. LinUCB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
import numpy as np
linucb_mod = import_from('linucb', C2 / 'core' / 'linucb.py')
arm = linucb_mod.LinUCBArm(0)
ctx = linucb_mod.build_context_vector(0.7, 0.4, 3, 7, 0.5, 0.4, 0.3)
arm.update(ctx, 0.5)
score = arm.ucb_score(ctx)
print('[OK] linucb.py  UCB=' + str(round(score, 4)))

# â”€â”€ 7. Intervention engine â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

import asyncio
engine = ie_mod.InterventionEngine()
result = asyncio.run(engine.check(
    student_id='stu_001',
    current_word='\u0d9a\u0dc0\u0dd4',
    phonological_strain_index=0.6,
    error_pattern_vector=[0, 1, 0, 0],
    strain_duration_ms=6000,
))
assert ie_mod.ACT_BLENDING == 'BLENDING_GAME', 'BLENDING_GAME not registered!'
print('[OK] intervention_engine.py  stage=' + str(result['stage']) + '  BLENDING_GAME registered')

# ========================================================================
# v3.0 NEW CHECKS (8-11)
# ========================================================================

# â”€â”€ 8. Kalman Filter (C1) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
kf_mod = import_from('kalman_filter', C1 / 'core' / 'kalman_filter.py')
kf = kf_mod.TouchKalmanFilter(dt=0.016)
for x, y in [(100, 200), (105, 205), (120, 215), (115, 210)]:
    kf.update(np.array([x, y], dtype=float))
mean_innov = kf.session_mean_innovation()
print('[OK] kalman_filter.py  mean_innovation=' + str(round(mean_innov, 4)))

# â”€â”€ 9. SOVCM (C2) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
sovcm_mod = import_from('sovcm', C2 / 'core' / 'sovcm.py')
score_sha = sovcm_mod.compute_sovcm_score('\u0dc1')            # à· (high complexity)
assert score_sha is not None, 'SOVCM: character not found in table'
tc = sovcm_mod.task_complexity('\u0d9a\u0dc0\u0dd4')           # à¶šà·€à·”
cl = sovcm_mod.crowding_load('\u0d9a\u0dc0\u0dd4', 2.0)
print('[OK] sovcm.py  composite(à·)=' + str(score_sha['composite_score']) +
      '  task_complexity=' + str(round(tc, 4)) +
      '  crowding_load=' + str(round(cl, 4)))

# â”€â”€ 10. Guardian Intake Scoring (C3 onboarding) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
ob_mod = import_from('onboarding', C3 / 'core' / 'onboarding.py')
responses = {
    'tires_quickly_reading':          True,   # 10
    'many_errors_reading':            True,   # 20
    'difficulty_spelling_unfamiliar': True,   # 30
    'words_appear_blurred':           True,   # 30
}  # total = 90 â†’ at_risk_moderate
score_val, flag = ob_mod.compute_at_risk_flag(responses)
assert flag == 'at_risk_moderate', 'Expected at_risk_moderate, got ' + flag
symptom_resp = {'confusion_similar_letters': True, 'omission_of_words': True}
profile = ob_mod.build_symptom_profile(symptom_resp)
assert profile['reversal_priority'] == 2
print('[OK] onboarding.py  score=' + str(score_val) + '  flag=' + flag +
      '  reversal_priority=' + str(profile['reversal_priority']))

# â”€â”€ 11. Observation Matrix BKT Seeding (C3 onboarding) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
