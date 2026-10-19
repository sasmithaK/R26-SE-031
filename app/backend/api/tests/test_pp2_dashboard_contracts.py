"""Offline contract regressions. No Mongo connection, live token, or cloud service required."""
import asyncio, copy, pathlib, sys, unittest
from datetime import datetime, timezone, timedelta
from bson import ObjectId

API=pathlib.Path(__file__).resolve().parents[1]
ROOT=API.parents[2]
sys.path.insert(0,str(ROOT));sys.path.insert(0,str(API))
from routers import therapist_dashboard as therapist, parent_dashboard as parent
from routers import therapist as therapist_routes
from services import dashboard_access
from services.dashboard_data import speech, stamp
from dependencies import get_current_user
from fastapi import FastAPI
from fastapi.testclient import TestClient

STUDENT='000000000000000000000031';OWNER=ObjectId('000000000000000000000011')

def matches(row, query):
    for key,wanted in query.items():
        if isinstance(wanted,dict):
            if '$exists' in wanted and (key in row)!=wanted['$exists']:return False
            if '$in' in wanted and row.get(key) not in wanted['$in']:return False
            if '$ne' in wanted and row.get(key)==wanted['$ne']:return False
        elif row.get(key)!=wanted:return False
    return True

class Cursor:
    def __init__(self,rows):self.rows=copy.deepcopy(rows)
    def sort(self,key,direction):
        self.rows.sort(key=lambda x:str(x.get(key,'')),reverse=direction<0);return self
    def limit(self,n):self.rows=self.rows[:n];return self
    async def to_list(self,length):return self.rows[:length]

class Collection:
    def __init__(self,rows=None):self.rows=rows or []
    def find(self,query):return Cursor([r for r in self.rows if matches(r,query)])
    async def find_one(self,query,**kwargs):return next((copy.deepcopy(r) for r in self.rows if matches(r,query)),None)
    async def distinct(self,key,query):return list({r.get(key) for r in self.rows if matches(r,query)})
    def aggregate(self,pipeline):
        rows=[r for r in self.rows if matches(r,pipeline[0]['$match'])]
        values={}
        for r in rows:
            if isinstance(r.get('session_duration_seconds'),(int,float)):
                sid=r['session_id'];values[sid]=max(values.get(sid,0),r['session_duration_seconds'])
        return Cursor([{'seconds':sum(values.values())}] if values else [])

class Database:
    def __init__(self,**collections):self.collections={k:Collection(v) for k,v in collections.items()}
    def __getitem__(self,key):return self.collections.setdefault(key,Collection())
    def __getattr__(self,key):return self[key]

class DashboardTests(unittest.TestCase):
    def setUp(self):
        self.db=Database(students=[{'_id':ObjectId(STUDENT),'parent_id':OWNER}],session_summaries=[])
        therapist.get_db=lambda:self.db;parent.get_db=lambda:self.db;dashboard_access.get_db=lambda:self.db
        therapist_routes.get_db=lambda:self.db
    def call(self,fn,*args):return asyncio.run(fn(*args))
    def session(self,n,**extra):
        return dict(_id=f'{n:03}',student_id=STUDENT,session_id=f'session-{n}',completed_at=datetime(2026,8,1,tzinfo=timezone.utc)+timedelta(days=n),
                    overall={'accuracy':.75,'median_response_latency_ms':1200,'retry_rate':.25},knowledge_components={},error_profile={},**extra)

    def test_therapist_home_uses_connected_observed_learning_only(self):
        therapist_id=ObjectId('000000000000000000000099')
        self.db.therapist_connections.rows=[{
            '_id':ObjectId('000000000000000000000088'),
            'therapist_id':str(therapist_id),'student_id':STUDENT,
            'status':'active','connected_at':datetime(2026,10,1,tzinfo=timezone.utc),
        }]
        self.db.students.rows=[{
            '_id':ObjectId(STUDENT),'parent_id':OWNER,'first_name':'Nimali',
            'last_name':'Perera','grade':'Grade 1','avatar_url':'avatar.png',
        }]
        self.db.adaptive_decisions.rows=[
            {'_id':'999','student_id':STUDENT,'timestamp':'2026-10-16T10:00:00Z',
             'activity_id':'2.1','current_item':'S2A1R99','item_role':'CORE',
             'first_attempt_correct':False,'scaffold_level_used':2,
             'response_quality':'ASSISTED_SUCCESS','research_eligible':False,
             'kc_id':'KC_LETTER_IDENTIFICATION'},
            {'_id':'300','student_id':STUDENT,'timestamp':'2026-10-15T10:00:00Z',
             'activity_id':'2.1','current_item':'S2A1R02','item_role':'CONFIRMATION',
             'first_attempt_correct':True,'scaffold_level_used':0,
             'response_quality':'CLEAN_SUCCESS','kc_id':'KC_LETTER_IDENTIFICATION'},
            {'_id':'200','student_id':STUDENT,'timestamp':'2026-10-15T09:59:00Z',
             'activity_id':'2.1','current_item':'S2A1R02','item_role':'CORE',
             'first_attempt_correct':False,'scaffold_level_used':1,
             'response_quality':'ASSISTED_SUCCESS','kc_id':'KC_LETTER_IDENTIFICATION'},
            {'_id':'100','student_id':STUDENT,'timestamp':'2026-10-15T09:58:00Z',
             'activity_id':'2.1','current_item':'S2A1R01','item_role':'CORE',
             'first_attempt_correct':True,'scaffold_level_used':0,
             'response_quality':'CLEAN_SUCCESS','kc_id':'KC_LETTER_IDENTIFICATION'},
        ]
        self.db.knowledge_states.rows=[{
            '_id':'400','student_id':STUDENT,
            'knowledge_state':{'KC_LETTER_IDENTIFICATION':.58},
        }]
        result=self.call(
            therapist_routes.get_therapist_dashboard_summary,
            {'_id':therapist_id,'role':'specialist'},
        )
        self.assertEqual(result['summary']['connected_learners'],1)
        self.assertEqual(result['summary']['observed_core_tasks'],2)
        self.assertEqual(result['summary']['independent_core_tasks'],1)
        self.assertEqual(result['summary']['supported_core_tasks'],1)
        self.assertEqual(result['summary']['confirmation_checks'],1)
        self.assertEqual(result['summary']['independent_rate'],.5)
        self.assertEqual(result['review_queue'][0]['student_name'],'Nimali Perera')
        self.assertEqual(result['review_queue'][0]['status'],'review_suggested')
        self.assertEqual(result['recent_activity'][0]['event_type'],'confirmation')
        self.assertIn('not a diagnosis',result['limitations'][0])
    def test_mongo_datetime_and_c1_trend_without_knowledge_state(self):
        self.db.session_summaries.rows=[self.session(i) for i in range(12)]
        dto=self.call(therapist.get_therapist_c1_behavioral,STUDENT)
        self.assertTrue(dto.updated_at.endswith('Z'));self.assertEqual(len(dto.trends.accuracy),10)
        self.assertEqual(dto.trends.accuracy[0],{'session':'session-2','value':.75})
        self.assertEqual(dto.trends.accuracy[-1]['session'],'session-11')
    def test_missing_values_remain_null_not_perfect_speech_or_confidence(self):
        c2=self.call(therapist.get_therapist_c2_speech,STUDENT);c3=self.call(therapist.get_therapist_c3_profile,STUDENT)
        self.assertIsNone(c2.latest.wer);self.assertIsNone(c2.latest.jitter);self.assertIsNone(c3.confidence)
        self.assertFalse(c2.available);self.assertEqual(c3.probabilities,{})
        self.assertFalse(c3.available);self.assertEqual(c3.pipeline_status,'not_run')
    def test_flat_nested_speech_contracts_and_no_one_minus_wer(self):
        self.assertEqual(speech({'speech_data':{'Acoustic_Latency_ms':1234,'Local_Jitter':.02}})['acoustic_latency_ms'],1234)
        self.assertEqual(speech({'local_shimmer':.03})['shimmer'],.03)
        self.assertIsNone(speech({'word_error_rate':0,'stt_confidence':1})['stt_confidence'])
        self.assertEqual(speech({'word_error_rate':2.5})['wer'],2.5)
    def test_shap_preserves_negative_direction_and_full_class_alias(self):
        self.db.learner_profiles.rows=[{'student_id':STUDENT,'learner_profile':{'primary_pattern':'Phonological Learning Pattern',
            'class_probabilities':{'Phonological Learning Pattern':.6}},'shap_explanations':{'top_contributing_features':[{'feature_name':'f','shap_impact':'-0.25','value':1.2}]}}]
        dto=self.call(therapist.get_therapist_c3_profile,STUDENT)
        self.assertEqual(dto.probabilities,{'Phonological':.6});self.assertEqual(dto.shap_explanations[0].contribution,-.25)
    def test_c4_newest_history_and_unknown_uncertainty(self):
        self.db.knowledge_states.rows=[{'student_id':STUDENT,'knowledge_state':{'KC_ORAL_READING_FLUENCY':.4},'theta_estimate':-.2,'updated_at':datetime(2026,8,31)}]
        self.db.adaptive_decisions.rows=[dict(_id=f'{i:03}',student_id=STUDENT,timestamp=f'2026-08-{i+1:02}T00:00:00Z',selected_activity='act_1',mastery_after=.4) for i in range(25)]
        dto=self.call(therapist.get_therapist_c4_adaptive,STUDENT)
        self.assertEqual(dto.theta,-.2);self.assertIsNone(dto.theta_se);self.assertEqual(len(dto.history),20)
        self.assertIn('08-25',dto.history[-1].timestamp);self.assertIsNone(dto.history[-1].mastery_before)
        self.assertEqual(dto.history[-1].next_activity,'act_1')

    def test_c4_clinician_summary_uses_observed_tasks_and_current_targets(self):
        self.db.knowledge_states.rows=[{
            '_id':'500','student_id':STUDENT,
            'knowledge_state':{
                'KC_AKSHARA_IDENTITY':.72,
                'KC_PHONEME_GRAPHEME':.46,
            },
        }]
        self.db.adaptive_decisions.rows=[
            {
                '_id':'404','student_id':STUDENT,'timestamp':'2026-10-15T10:04:00Z',
                'activity_id':'2.3','current_item':'S2A3R02V1','item_role':'REMEDIATION',
                'kc_id':'KC_PHONEME_GRAPHEME','mastery_after':.99,
                'first_attempt_correct':True,'scaffold_level_used':0,
                'response_quality':'CLEAN_SUCCESS',
            },
            {
                '_id':'403','student_id':STUDENT,'timestamp':'2026-10-15T10:03:00Z',
                'activity_id':'2.3','current_item':'S2A3R02V2','item_role':'CONFIRMATION',
                'kc_id':'KC_PHONEME_GRAPHEME','mastery_after':.46,
                'first_attempt_correct':True,'scaffold_level_used':0,
                'response_quality':'CLEAN_SUCCESS',
            },
            {
                '_id':'402','student_id':STUDENT,'timestamp':'2026-10-15T10:02:00Z',
                'activity_id':'2.3','current_item':'S2A3R02','item_role':'CORE',
                'kc_id':'KC_PHONEME_GRAPHEME','mastery_after':.43,
                'first_attempt_correct':False,'scaffold_level_used':1,
                'response_quality':'ASSISTED_SUCCESS','struggled_target_units':['ක'],
            },
            {
                '_id':'401','student_id':STUDENT,'timestamp':'2026-10-15T10:01:00Z',
                'activity_id':'2.3','current_item':'S2A3R01','item_role':'CORE',
                'kc_id':'KC_PHONEME_GRAPHEME','mastery_after':.40,
                'first_attempt_correct':True,'scaffold_level_used':0,
                'response_quality':'CLEAN_SUCCESS','struggled_target_units':['ක'],
            },
            {
                '_id':'900','student_id':STUDENT,'timestamp':'2026-10-16T10:00:00Z',
                'activity_id':'2.3','current_item':'S2A3R99','item_role':'CORE',
                'kc_id':'KC_PHONEME_GRAPHEME','mastery_after':.10,
                'first_attempt_correct':False,'scaffold_level_used':2,
                'research_eligible':False,'struggled_target_units':['retired'],
            },
        ]
        self.db.item_bank.rows=[{
            'item_id':'S2A3R02','activity_id':'2.3',
            'template_type':'skill2_audio','item_role':'CORE',
            'content':{
                'prompt':'ශබ්දයට සවන් දී අකුර තෝරන්න',
                'audio_text':'ක','options':['ක','ග'],'correctOption':'ක',
            },
            'options':[
                {'option_id':'S2A3R02_O1','value':'ක','role':'target'},
                {'option_id':'S2A3R02_O2','value':'ග','role':'distractor'},
            ],
        }]
        dto=self.call(therapist.get_therapist_c4_adaptive,STUDENT,10)
        self.assertEqual(dto.summary['primary_focus_id'],'KC_PHONEME_GRAPHEME')
        self.assertEqual(dto.summary['core_tasks'],2)
        self.assertEqual(dto.summary['supported_core_tasks'],1)
        self.assertEqual(dto.summary['independent_confirmations'],1)
        self.assertEqual(dto.summary['independent_transfer_rate'],1.0)
        self.assertEqual(dto.summary['transfer_evidence_level'],'early')
        self.assertEqual([point['value'] for point in dto.mastery_trend],[.4,.43,.46])
        self.assertEqual(
            [point['evidence_role'] for point in dto.mastery_trend],
            ['CORE','CORE','CONFIRMATION'],
        )
        self.assertEqual(dto.recurring_targets[0]['unit'],'ක')
        self.assertEqual(dto.recurring_targets[0]['observations'],2)
        self.assertEqual(dto.next_session_plan['activity_id'],'2.3')
        self.assertTrue(dto.next_session_plan['practice_available'])
        self.assertEqual(len(dto.skills),4)
        letters=next(row for row in dto.skills if row['skill_id']=='2')
        self.assertEqual(letters['activities_attempted'],1)
        activity=dto.activities[0]
        self.assertEqual(activity['activity_name'],'අකුර අසා හඳුනා ගනිමු')
        self.assertEqual(activity['core_tasks'],2)
        self.assertEqual(activity['remediation_tasks'],1)
        self.assertEqual(activity['confirmation_tasks'],1)
        core_preview=next(
            row for row in activity['task_attempts']
            if row['item_id']=='S2A3R02'
        )['preview']
        self.assertTrue(core_preview['available'])
        self.assertEqual(core_preview['correct_response'],['ක'])

    def test_task_replay_resolves_sequence_and_visual_target_answers(self):
        self.assertEqual(
            therapist._item_answer_values({
                'content':{'target_word':'රට','pattern':['ර','ට']},
                'options':[
                    {'option_id':'O1','value':'ර','role':'sequence_token'},
                    {'option_id':'O2','value':'ට','role':'sequence_token'},
                ],
            }),
            ['රට'],
        )
        self.assertEqual(
            therapist._item_answer_values({
                'content':{'items':[
                    {'value':'අ','is_target':True},
                    {'value':'ආ','is_target':False},
                ]},
            }),
            ['අ'],
        )

    def test_task_replay_exposes_pattern_memory_and_exact_attempt_journey(self):
        pattern = therapist._task_preview(
            {
                'selected_answers':['grapes.png','banana.png'],
                'attempt_count':2,
                'incorrect_attempt_count':1,
                'is_correct':True,
                'attempt_history':[
                    {
                        'attempt_number':1,'is_correct':False,
                        'selected_answers':['fruits_food/grapes.png'],
                        'support_applied_before_response':False,
                    },
                    {
                        'attempt_number':2,'is_correct':True,
                        'selected_answers':['fruits_food/banana.png'],
                        'support_applied_before_response':True,
                        'support_actions_before_response':['highlightOptions'],
                    },
                ],
            },
            {
                'template_type':'visual_pattern_adventure',
                'content':{
                    'sequence':['animals/turtle.png','fruits_food/apple.png',None],
                    'missing_index':2,
                    'correct_answer':'fruits_food/banana.png',
                    'options':['fruits_food/banana.png','fruits_food/grapes.png'],
                },
                'options':[],
            },
        )
        self.assertEqual(pattern['content']['missing_index'],2)
        self.assertEqual(pattern['content']['sequence'][-1],None)
        self.assertEqual(pattern['response_attempts'][0]['evidence_quality'],'exact')
        self.assertTrue(pattern['response_attempts'][1]['support_applied_before_response'])
        self.assertEqual(
            pattern['response_attempts'][1]['selected_answers'],
            ['fruits_food/banana.png'],
        )

        memory = therapist._task_preview(
            {
                'selected_answers':['S1A5R04V2_O1','everyday_objects/key.png'],
                'attempt_count':2,'incorrect_attempt_count':1,'is_correct':True,
                'scaffold_level_used':1,
            },
            {
                'template_type':'visual_memory_hats',
                'content':{
                    'assets':['everyday_objects/key.png','everyday_objects/bell.png'],
                    'target_asset':'everyday_objects/key.png',
                    'show_milliseconds':4000,
                },
                'options':[],
            },
        )
        self.assertEqual(len(memory['options']),2)
        self.assertEqual(
            memory['response_attempts'][0]['selected_answers'],
            ['Card 1 (historical position)'],
        )
        self.assertEqual(memory['response_attempts'][0]['evidence_quality'],'reconstructed')
        self.assertEqual(
            therapist._task_prompt({
                'template_type':'visual_pattern_adventure','content':{},
            }),
            'රටාවට ගැළපෙන පින්තූරය තෝරන්න',
        )

    def test_task_evidence_joins_real_telemetry_and_hides_action_ids(self):
        self.db.knowledge_states.rows=[{
            'student_id':STUDENT,
            'knowledge_state':{'KC_VISUAL_PATTERN':.44},
        }]
        self.db.adaptive_decisions.rows=[{
            '_id':'decision-1','student_id':STUDENT,'event_id':'event-1',
            'session_id':'session-1','timestamp':'2026-10-19T10:00:00Z',
            'activity_id':'1.4','current_item':'S1A4R01','item_role':'CORE',
            'kc_id':'KC_VISUAL_PATTERN','is_correct':True,
            'first_attempt_correct':False,'scaffold_level_used':2,
            'mastery_before':.40,'mastery_after':.44,
            'scaffold_applications':[
                {'action_id':'S1A4R01-C4-MODEL-2-1'},
            ],
        }]
        self.db.telemetry_events.rows=[{
            '_id':'telemetry-1','student_id':STUDENT,'event_id':'event-1',
            'session_id':'session-1','item_id':'S1A4R01',
            'timestamp':'2026-10-19T10:00:00Z',
            'attempt_count':3,'incorrect_attempt_count':2,
            'total_round_latency_ms':7420,
            'selected_answers':['grapes.png','apple.png','banana.png'],
            'attempt_history':[
                {'attempt_number':1,'is_correct':False,
                 'selected_answers':['grapes.png'],
                 'support_applied_before_response':False},
                {'attempt_number':2,'is_correct':False,
                 'selected_answers':['apple.png'],
                 'support_applied_before_response':True,
                 'support_actions_before_response':['removeOptions']},
                {'attempt_number':3,'is_correct':True,
                 'selected_answers':['banana.png'],
                 'support_applied_before_response':True,
                 'support_actions_before_response':['highlightOptions']},
            ],
            'scaffold_applications':[
                {'action_id':'S1A4R01-C4-MODEL-2-1',
                 'command_types':['highlightOptions']},
            ],
        }]
        self.db.item_bank.rows=[{
            'item_id':'S1A4R01','activity_id':'1.4',
            'template_type':'visual_pattern_adventure','item_role':'CORE',
            'content':{
                'prompt':'රටාවට ගැළපෙන පින්තූරය තෝරන්න',
                'sequence':['turtle.png','apple.png',None],
                'missing_index':2,'correct_answer':'banana.png',
                'options':['banana.png','grapes.png','apple.png'],
            },
            'options':[],
        }]

        dto=self.call(therapist.get_therapist_c4_adaptive,STUDENT,20)
        task=dto.activities[0]['task_attempts'][0]
        self.assertEqual(task['attempt_count'],3)
        self.assertEqual(task['incorrect_attempt_count'],2)
        self.assertEqual(task['total_round_latency_ms'],7420)
        self.assertEqual(
            task['support_actions'],['removeOptions','highlightOptions']
        )
        self.assertNotIn('C4-MODEL',str(task['support_actions']))
        self.assertEqual(len(task['preview']['response_attempts']),3)

    def test_c4_focus_and_trend_do_not_borrow_unobserved_kc_values(self):
        self.db.knowledge_states.rows=[{
            'student_id':STUDENT,
            'knowledge_state':{
                'KC_WORD_RECOGNITION':.20,
                'KC_VISUAL_IDENTIFICATION':.61,
            },
        }]
        self.db.adaptive_decisions.rows=[
            {
                '_id':'2','student_id':STUDENT,
                'timestamp':'2026-10-15T10:02:00Z','activity_id':'1.1',
                'current_item':'S1A1R02','item_role':'CORE',
                'kc_id':'KC_VISUAL_IDENTIFICATION','mastery_after':.61,
                'first_attempt_correct':True,'scaffold_level_used':0,
            },
            {
                '_id':'1','student_id':STUDENT,
                'timestamp':'2026-10-15T10:01:00Z','activity_id':'1.1',
                'current_item':'S1A1R01','item_role':'CORE',
                'kc_id':'KC_VISUAL_IDENTIFICATION','mastery_after':.55,
                'first_attempt_correct':False,'scaffold_level_used':1,
            },
        ]
        dto=self.call(therapist.get_therapist_c4_adaptive,STUDENT,20)
        self.assertEqual(dto.summary['primary_focus_id'],'KC_VISUAL_IDENTIFICATION')
        self.assertEqual([point['value'] for point in dto.mastery_trend],[.55,.61])
        self.assertEqual(dto.summary['focus_core_tasks'],2)
        visual=next(row for row in dto.knowledge_components if row.id=='KC_VISUAL_IDENTIFICATION')
        self.assertEqual(visual.name,'Picture identification')
        self.assertEqual(visual.observations,2)
        self.assertEqual(visual.independent_observations,1)
        word=next(row for row in dto.knowledge_components if row.id=='KC_WORD_RECOGNITION')
        self.assertEqual(word.observations,0)
    def test_c4_does_not_surface_retired_transfer_experiment(self):
        self.db.knowledge_states.rows=[{
            'student_id':STUDENT,
            'knowledge_state':{'KC_VISUAL_DISCRIMINATION':.5},
            'cross_activity_target_profile':{
                'elephant':{
                    'status':'persistent','independent_failures':4,
                    'activities':['1.1','1.2','1.3'],
                    'last_failed_at':'2026-10-15T10:00:00Z',
                },
                'cat':{
                    'status':'resolved','independent_failures':3,
                    'activities':['1.1','1.2','1.3'],
                },
            },
        }]
        dto=self.call(therapist.get_therapist_c4_adaptive,STUDENT)
        self.assertEqual(dto.persistent_learning_needs,[])
    def test_c4_policy_evidence_is_separated_for_parent_and_specialist(self):
        self.db.knowledge_states.rows=[{'student_id':STUDENT,'knowledge_state':{'KC_AKSHARA_IDENTITY':.55},'data_origin':'observed'}]
        self.db.adaptive_decisions.rows=[{
            'student_id':STUDENT,'timestamp':'2026-08-31T00:00:00Z',
            'response_quality':'ASSISTED_SUCCESS','decision':'CONFIRMATION',
            'next_phase':'CONFIRMATION','is_correct':True,
        }]
        self.db.policy_decisions.rows=[{
            'student_id':STUDENT,'timestamp':'2026-08-31T00:00:00Z',
            'item_id':'S1A1R01','policy_mode':'shadow',
            'model_version':'c4-action-outcome-synthetic-v1',
            'model_validation_status':'synthetic_only',
            'fallback_reason':'SYNTHETIC_OR_UNVALIDATED_MODEL_SHADOW_ONLY',
            'candidate_actions':['RETRY_CURRENT','SCAFFOLD_HIGHLIGHT_CORRECT'],
            'model_recommendation':'SCAFFOLD_HIGHLIGHT_CORRECT',
            'model_confidence':.2,'applied_action':'RETRY_CURRENT',
            'proximal_outcome_observed':True,'proximal_next_response_correct':False,
            'outcome_observed':True,'outcome_first_attempt_correct':True,
            'data_origin':'observed',
        }]
        specialist=self.call(therapist.get_therapist_c4_adaptive,STUDENT)
        self.assertEqual(specialist.policy_status['mode'],'shadow')
        self.assertEqual(specialist.latest_policy_decision['applied_action'],'RETRY_CURRENT')
        self.assertFalse(specialist.policy_status['controls_live_adaptation'])
        self.assertEqual(specialist.data_quality['recommendation_agreement_rate'],0.0)
        self.assertEqual(specialist.support_effectiveness[0]['next_independent_success_rate'],1.0)
        self.assertEqual(specialist.data_quality['policy_rows_with_proximal_outcomes'],1)
        parent_dto=self.call(parent.get_adaptive_insights,STUDENT)
        self.assertEqual(parent_dto.support_summary['completed_tasks'],1)
        self.assertEqual(parent_dto.support_summary['supported_successes'],1)
        self.assertIn('do not control',parent_dto.policy_notice)
        self.db.policy_decisions.rows[0].update({
            'policy_mode':'simulation_model',
            'execution_source':'synthetic_model_simulation',
            'controls_live_adaptation':True,
            'applied_action':'SCAFFOLD_HIGHLIGHT_CORRECT',
        })
        simulation=self.call(therapist.get_therapist_c4_adaptive,STUDENT)
        self.assertTrue(simulation.policy_status['controls_live_adaptation'])
        self.assertIn('functional evidence only',simulation.policy_status['evidence_scope'])
        simulation_parent=self.call(parent.get_adaptive_insights,STUDENT)
        self.assertIn('Research demonstration mode',simulation_parent.policy_notice)
        self.assertIn('not a diagnosis',simulation_parent.policy_notice)
    def test_parent_latest_activity_sessions_cover_history_without_inflated_rounds(self):
        self.db.adaptive_decisions.rows=[
            {
                '_id':'900','student_id':STUDENT,'session_id':'latest',
                'timestamp':'2026-10-13T10:00:03Z','activity_id':'1.1',
                'current_item':'S1A1R02','response_quality':'ASSISTED_SUCCESS',
                'scaffold_level':1,'is_correct':True,'decision':'REMEDIATION',
                'next_phase':'REMEDIATION',
            },
            {
                '_id':'899','student_id':STUDENT,'session_id':'latest',
                'timestamp':'2026-10-13T10:00:02Z','activity_id':'1.1',
                'current_item':'S1A1R01','response_quality':'CLEAN_SUCCESS',
                'scaffold_level':0,'is_correct':True,'decision':'CONTINUE',
                'next_phase':'CORE',
            },
            {
                '_id':'300','student_id':STUDENT,'session_id':'older-skill-one',
                'timestamp':'2026-10-12T10:00:00Z','activity_id':'1.1',
                'current_item':'S1A1R01','response_quality':'CLEAN_SUCCESS',
                'scaffold_level':0,'is_correct':True,'decision':'CONTINUE',
            },
            {
                '_id':'100','student_id':STUDENT,'session_id':'old-skill-two',
                'timestamp':'2026-10-01T10:00:00Z','activity_id':'2.1',
                'current_item':'S2A1R01','response_quality':'CLEAN_SUCCESS',
                'scaffold_level':0,'is_correct':True,'decision':'CONTINUE',
            },
        ]
        dto=self.call(parent.get_adaptive_insights,STUDENT)
        self.assertIsNone(dto.support_summary['session_id'])
        self.assertEqual(dto.support_summary['completed_tasks'],3)
        self.assertEqual(dto.support_summary['activity_count'],2)
        self.assertEqual(dto.support_summary['session_count'],2)
        self.assertEqual([row.activity_id for row in dto.activities],['1.1','2.1'])
        card=dto.activities[0]
        self.assertEqual(card.rounds_completed,2);self.assertEqual(card.rounds_total,5)
        self.assertEqual(card.times_played,2)
        self.assertIn('Hidden Picture Search',card.activity_name)
        older_activity=dto.activities[1]
        self.assertEqual(older_activity.rounds_completed,1)
        self.assertEqual(older_activity.times_played,1)

    def test_parent_adaptive_summary_uses_real_component4_state(self):
        self.db.knowledge_states.rows=[{
            'student_id':STUDENT,
            'knowledge_state':{
                'KC_VISUAL_IDENTIFICATION':.84,
                'KC_PHONEME_LETTER_MAPPING':.43,
            },
        }]
        self.db.adaptive_decisions.rows=[
            {
                '_id':'200','student_id':STUDENT,'session_id':'letters',
                'timestamp':'2026-10-14T10:00:00Z','activity_id':'2.3',
                'current_item':'S2A3R01','response_quality':'ASSISTED_SUCCESS',
                'scaffold_level':1,'is_correct':True,'decision':'REMEDIATION',
                'next_phase':'CONFIRMATION',
            },
            {
                '_id':'100','student_id':STUDENT,'session_id':'pictures',
                'timestamp':'2026-10-13T10:00:00Z','activity_id':'1.1',
                'current_item':'S1A1R01','response_quality':'CLEAN_SUCCESS',
                'scaffold_level':0,'is_correct':True,'decision':'CONTINUE',
                'next_phase':'CORE',
            },
        ]
        dto=self.call(parent.get_adaptive_insights,STUDENT)
        summary=dto.support_summary
        self.assertEqual(summary['strongest_area']['title'],'Picture recognition')
        self.assertEqual(summary['strongest_area']['score_percent'],84)
        self.assertEqual(summary['focus_area']['title'],'Listening to letters')
        self.assertEqual(summary['focus_area']['score_percent'],43)
        self.assertEqual(summary['focus_area']['source'],'component4_mastery_estimate')
        self.assertEqual(summary['help_story']['learning_checks'],1)
        self.assertEqual(summary['home_practice']['minutes'],5)
        self.assertNotIn('KC_',summary['home_practice']['title'])
        self.assertEqual(summary['coverage']['activities_tried'],2)
        self.assertEqual(summary['coverage']['activities_available'],19)
        self.assertEqual(
            [skill['title'] for skill in summary['skill_progress']],
            ['Pictures','Letters'],
        )
        self.assertEqual(summary['skill_progress'][0]['observed_tasks'],1)
        self.assertEqual(summary['skill_progress'][0]['first_try_successes'],1)
        self.assertEqual(
            summary['support_effectiveness']['legacy_follow_up_routes'],1
        )
        self.assertEqual(
            summary['metric_details']['independent'][0]['skill_title'],
            'Pictures',
        )
        self.assertEqual(
            summary['metric_details']['independent'][0]['task_label'],
            'Task 1',
        )
        self.assertEqual(
            summary['metric_details']['helped'][0]['activity_id'],'2.3'
        )

    def test_parent_support_result_uses_completed_confirmation_evidence(self):
        self.db.adaptive_decisions.rows=[
            {
                '_id':'301','student_id':STUDENT,'session_id':'pictures',
                'timestamp':'2026-10-14T10:00:03Z','activity_id':'1.1',
                'current_item':'S1A1R01V2','item_role':'CONFIRMATION',
                'practice_phase':'CONFIRMATION','response_quality':'CLEAN_SUCCESS',
                'scaffold_level':0,'is_correct':True,'decision':'CONTINUE',
                'next_phase':'CORE',
            },
            {
                '_id':'300','student_id':STUDENT,'session_id':'pictures',
                'timestamp':'2026-10-14T10:00:02Z','activity_id':'1.1',
                'current_item':'S1A1R01','item_role':'CORE',
                'response_quality':'ASSISTED_SUCCESS','scaffold_level':1,
                'is_correct':True,'decision':'CONFIRMATION',
                'next_phase':'CONFIRMATION',
            },
        ]
        summary=self.call(parent.get_adaptive_insights,STUDENT).support_summary
        self.assertEqual(summary['confirmation_checks'],1)
        self.assertEqual(
            summary['confirmation_check_basis'],'completed_follow_up_items'
        )
        effectiveness=summary['support_effectiveness']
        self.assertEqual(effectiveness['completed_follow_up_checks'],1)
        self.assertEqual(effectiveness['independent_follow_up_checks'],1)
        self.assertIn('1 of 1 fresh checks',effectiveness['summary'])
        checked=summary['metric_details']['checked']
        self.assertEqual(len(checked),1)
        self.assertEqual(checked[0]['skill_title'],'Pictures')
        self.assertEqual(checked[0]['task_kind'],'Learning check')
        self.assertIn('independently',checked[0]['detail'])

    def test_parent_support_priorities_use_observed_struggle_and_reviewed_pair(self):
        self.db.item_bank.rows=[
            {
                'item_id':'S2A3R02V1','equivalent_group_id':'S2A3R02',
                'item_role':'REMEDIATION','is_active':True,
                'targeted_practice':False,
            },
            {
                'item_id':'S2A3R02V2','equivalent_group_id':'S2A3R02',
                'item_role':'CONFIRMATION','is_active':True,
                'targeted_practice':False,
            },
            {
                'item_id':'S2A3R02V3','equivalent_group_id':'S2A3R02',
                'item_role':'REMEDIATION','is_active':True,
                'targeted_practice':True,
            },
        ]
        self.db.adaptive_decisions.rows=[
            {
                '_id':'202','student_id':STUDENT,'session_id':'letters',
                'timestamp':'2026-10-14T10:00:02Z','activity_id':'2.3',
                'current_item':'S2A3R02','response_quality':'ASSISTED_SUCCESS',
                'scaffold_level':1,'is_correct':True,'decision':'REMEDIATION',
                'next_phase':'REMEDIATION',
            },
            {
                '_id':'201','student_id':STUDENT,'session_id':'letters',
                'timestamp':'2026-10-14T10:00:01Z','activity_id':'2.3',
                'current_item':'S2A3R01','response_quality':'CLEAN_SUCCESS',
                'scaffold_level':0,'is_correct':True,'decision':'CONTINUE',
                'next_phase':'CORE',
            },
        ]
        summary=self.call(parent.get_adaptive_insights,STUDENT).support_summary
        self.assertEqual(len(summary['needs_practice']),1)
        need=summary['needs_practice'][0]
        self.assertEqual(need['activity_id'],'2.3')
        self.assertEqual(need['origin_item_id'],'S2A3R02')
        self.assertTrue(need['practice_available'])
        self.assertEqual(
            [step['item_id'] for step in need['practice_steps']],
            ['S2A3R02V1','S2A3R02V2'],
        )
        self.assertIn('Needed help on 1 task',need['evidence_text'])
    def test_c3_missing_inputs_are_visible_to_specialist_without_fabricated_profile(self):
        self.db.model_audit_log.rows=[{
            '_id':'900','student_id':STUDENT,'model_name':'XGBoost',
            'timestamp':'2026-10-13T10:00:00Z','validation_status':'synthetic_only',
            'status':'skipped_missing_inputs',
            'missing_features':['acoustic_latency_ms','student_age_months'],
        }]
        c3=self.call(therapist.get_therapist_c3_profile,STUDENT)
        self.assertFalse(c3.available)
        self.assertEqual(c3.pipeline_status,'skipped_missing_inputs')
        self.assertEqual(c3.missing_inputs,['acoustic_latency_ms','student_age_months'])
        self.assertIn('not ready yet',c3.skip_reason)
        c4=self.call(therapist.get_therapist_c4_adaptive,STUDENT)
        self.assertEqual(c4.data_quality['c3_pipeline_status'],'skipped_missing_inputs')
    def test_parent_real_session_count_duration_and_history(self):
        self.db.session_summaries.rows=[self.session(1,activity_breakdown={'act_1':{'accuracy':.75,'trials':2}})]
        self.db.telemetry_sessions.rows=[dict(student_id=STUDENT,session_id='session-1',schema_version='2.0',
            events=[{'activity_id':'act_1','total_round_latency_ms':60000}],session_duration_seconds=120)]
        dto=self.call(parent.get_parent_overview,STUDENT)
        self.assertEqual(dto.sessions_completed,1);self.assertEqual(dto.practice_time_minutes,2)
        history=self.call(parent.get_parent_activity_history,STUDENT,10,None)
        self.assertEqual(history.history[0].duration_minutes,1)
        self.assertEqual(history.history[0].session_date,'2026-08-02')
    def test_parent_component_analytics_preserves_component_availability(self):
        self.db.session_summaries.rows=[self.session(1,behavioral_fatigue_proxy=.2)]
        self.db.speech_features.rows=[dict(student_id=STUDENT,session_id='session-1',created_at='2026-08-02T00:00:00Z',
            word_error_rate=.25,acoustic_latency_ms=900,recording_quality='good')]
        self.db.knowledge_states.rows=[dict(student_id=STUDENT,knowledge_state={'KC_AKSHARA_IDENTITY':.7})]
        self.db.adaptive_decisions.rows=[dict(student_id=STUDENT,decision='CONTINUE',scaffold_level_used=1)]
        result=self.call(parent.get_parent_component_analytics,STUDENT)
        self.assertTrue(result['c1_behavioral']['available']);self.assertTrue(result['c2_speech']['available'])
        self.assertFalse(result['c3_explainability']['available'])
        self.assertEqual(result['c4_adaptive']['average_mastery'],.7)
        self.assertEqual(result['c4_adaptive']['supported_decision_rate'],1.0)
    def test_parent_empty_is_not_a_fabricated_progress_point(self):
        self.assertEqual(self.call(parent.get_parent_progress,STUDENT).accuracy_trend,[])
        self.assertIsNone(self.call(parent.get_parent_overview,STUDENT).accuracy)
        self.assertIn('No learning-pattern',self.call(parent.get_parent_learning_pattern,STUDENT).observation)
    def test_http_authorization_and_bson_serialization(self):
        self.db.session_summaries.rows=[self.session(1)]
        app=FastAPI();app.include_router(therapist.router)
        with TestClient(app) as client:
            url=f'/api/v1/therapist/students/{STUDENT}/c1-behavioral'
            self.assertEqual(client.get(url).status_code,401)
            app.dependency_overrides[get_current_user]=lambda:{'_id':ObjectId(),'role':'parent'}
            self.assertEqual(client.get(url).status_code,403)
            app.dependency_overrides[get_current_user]=lambda:{'_id':OWNER,'role':'parent'}
            response=client.get(url);self.assertEqual(response.status_code,200);self.assertEqual(response.json()['first_attempt_accuracy'],.75)
    def test_pp2_evidence_missing_and_synthetic_provenance(self):
        self.assertEqual(self.call(parent.get_parent_evidence,STUDENT)['components'],[])
        self.db.research_evaluations.rows=[dict(student_id=STUDENT,data_origin='synthetic',dataset_id='d1',components=[{'component':'C1'}])]
        result=self.call(therapist.get_therapist_evidence,STUDENT)
        self.assertEqual(result['data_origin'],'synthetic');self.assertEqual(result['components'][0]['component'],'C1')
    def test_pdf_handles_unavailable_measurements(self):
        response=self.call(therapist.get_therapist_research_pdf,STUDENT)
        self.assertTrue(response.body.startswith(b'%PDF'))
        self.db.learner_profiles.rows=[{'student_id':STUDENT,'learner_profile':{'primary_pattern':'Typical Learning Pattern'},'llm_summary':'Experimental explanation. '*30}]
        self.db.adaptive_decisions.rows=[{'student_id':STUDENT,'timestamp':'2026-08-31T00:00:00Z','decision_reason':'A recommendation, not applied adaptation. '*15}]
        response=self.call(therapist.get_therapist_research_pdf,STUDENT)
        self.assertTrue(response.body.startswith(b'%PDF'))

if __name__=='__main__':unittest.main(verbosity=2)
