"""Offline contract regressions. No Mongo connection, live token, or cloud service required."""
import asyncio, copy, pathlib, sys, unittest
from datetime import datetime, timezone, timedelta
from bson import ObjectId

API=pathlib.Path(__file__).resolve().parents[1]
ROOT=API.parents[2]
sys.path.insert(0,str(ROOT));sys.path.insert(0,str(API))
from routers import therapist_dashboard as therapist, parent_dashboard as parent
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
    def call(self,fn,*args):return asyncio.run(fn(*args))
    def session(self,n,**extra):
        return dict(_id=f'{n:03}',student_id=STUDENT,session_id=f'session-{n}',completed_at=datetime(2026,8,1,tzinfo=timezone.utc)+timedelta(days=n),
                    overall={'accuracy':.75,'median_response_latency_ms':1200,'retry_rate':.25},knowledge_components={},error_profile={},**extra)
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
    def test_parent_real_session_count_duration_and_history(self):
        self.db.session_summaries.rows=[self.session(1,activity_breakdown={'act_1':{'accuracy':.75,'trials':2}})]
        self.db.telemetry_events.rows=[dict(student_id=STUDENT,session_id='session-1',events=[{'activity_id':'act_1','total_round_latency_ms':60000}],session_duration_seconds=120),
            dict(student_id=STUDENT,session_id='session-1',is_correct=True)]
        dto=self.call(parent.get_parent_overview,STUDENT)
        self.assertEqual(dto.sessions_completed,1);self.assertEqual(dto.practice_time_minutes,2)
        history=self.call(parent.get_parent_activity_history,STUDENT,10,None)
        self.assertEqual(history.history[0].duration_minutes,1)
        self.assertEqual(history.history[0].session_date,'2026-08-02')
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
