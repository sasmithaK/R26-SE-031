"""Reproducible PP2 simulation. Offline by default; never fabricates model predictions.

Synthetic distributions are declared engineering assumptions, NOT Sri Lankan child norms.
The current deployed model is not overwritten. Run with --help for explicit import controls.
"""
import argparse, ast, asyncio, hashlib, importlib.util, json, math, os, pathlib, sys
from datetime import datetime, timezone, timedelta

ROOT = pathlib.Path(__file__).resolve().parents[3]

def module(name, path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result

def build(args):
    import numpy as np
    import pandas as pd
    import joblib
    from sklearn.model_selection import train_test_split
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler
    from sklearn.linear_model import LogisticRegression
    from sklearn.dummy import DummyClassifier
    from sklearn.metrics import f1_score, balanced_accuracy_score, log_loss, brier_score_loss, confusion_matrix
    from xgboost import XGBClassifier
    rng=np.random.default_rng(args.seed)
    out=pathlib.Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
    os.environ.setdefault('NUMBA_CACHE_DIR',str(out/'numba-cache'))
    now=datetime(2026,8,31,6,0,tzinfo=timezone.utc)
    dataset=f'pp2-overlap-v1-seed-{args.seed}'
    origin=dict(data_origin='synthetic',dataset_id=dataset,validation_status='synthetic_only')
    docs={k:[] for k in ['telemetry_events','session_summaries','speech_features','learner_profiles','knowledge_states','adaptive_decisions','item_bank','research_evaluations']}
    curriculum=[json.loads((ROOT/f'app/frontend/assets/data/curriculum/skill_{i}.json').read_text(encoding='utf-8-sig'))[0] for i in range(1,7)]
    c1path=ROOT/'app/backend/telemetry-analytics-v1'
    sys.path.insert(0,str(c1path))
    from schemas.telemetry import TelemetrySessionSubmit
    from services.behavioral_engine import extract_session_features
    bkt=module('pp2_bkt',ROOT/'app/backend/adaptive-tutoring-v1/services/bkt_engine.py').bkt_engine
    irt=module('pp2_irt',ROOT/'app/backend/adaptive-tutoring-v1/services/irt_engine.py').irt_engine
    policy=module('pp2_policy',ROOT/'app/backend/adaptive-tutoring-v1/services/policy_engine.py').policy_engine
    accuracy_error=[];completion_error=[]
    mastery={};theta=0.; decision_index=0
    # Select a canonical activity in each skill. This simulates the intended event schema;
    # it does not claim every current Flutter template records all these fields correctly.
    selections=[0,0,4,0,1,0]
    for iteration in range(3):
      for si,skill in enumerate(curriculum):
        activity=skill['activities'][selections[si]]
        kc=activity['research_metadata']['knowledge_component_id']
        session=f'{dataset}-s{iteration+1}-skill{si+1}'
        events=[];oracle=[]
        when=now+timedelta(minutes=10*(iteration*6+si))
        for index,item in enumerate(activity.get('rounds',[])):
            b=float(item.get('difficulty_b',0));first=bool(rng.random()<1/(1+math.exp(b-.5)))
            retries=0 if first else int(rng.integers(1,4));final=first or bool(rng.random()<.85)
            latency=int(rng.lognormal(math.log(1100+.3*retries*1000),.35))
            duration=latency+int(rng.integers(1200,2800))*(1+retries)
            error='sequence_error' if si==2 else 'unknown_error'
            targets=list(item.get('targets',[]))
            choices=list(item.get('distractors',[]))
            if item.get('items'):
                targets=[x['value'] for x in item['items'] if x.get('is_target')]
                choices=[x['value'] for x in item['items'] if not x.get('is_target')]
            elif item.get('options'):
                targets=[item['options'][item.get('correct_index',0)]]
                choices=[x for x in item['options'] if x not in targets]
            elif item.get('correct_word'):
                targets=[item['correct_word']];choices=[''.join(reversed(item['correct_word']))]
            elif si==5:
                targets=[item['prompt']];choices=['']  # Missing transcription, not a spoken distractor.
            wrong_value=str(choices[0]) if choices else '[no selected option]'
            right_value=str(targets[0]) if targets else '[target not supplied]'
            event=dict(event_id=f'{session}:{index}',student_id=args.student_id,skill_id=skill['id'],activity_id=activity['id'],
                       item_id=item['item_id'],item_version=item.get('item_version',1),activity_name=activity['template_type'],round_number=index+1,
                       knowledge_component_id=kc,prompt_modality=activity['research_metadata']['prompt_modality'],
                       response_modality=activity['research_metadata']['response_modality'],research_role=activity['research_metadata']['research_role'],
                       difficulty_b=b,difficulty_label=item.get('difficulty_label','medium'),is_anchor=item.get('is_anchor',False),
                       is_correct=final,final_correct=final,first_attempt_correct=first,attempt_count=1+retries,incorrect_attempt_count=retries if final else retries+1,
                       score=100 if final else 0,first_touch_latency_ms=latency,time_to_first_response_ms=latency,
                       total_round_latency_ms=duration,time_to_correct_ms=duration if final else 0,
                       selected_answers=[wrong_value]*retries+([right_value] if final else [wrong_value]),
                       targets=targets,error_type=error,hesitation_count=int(duration>6000),misclick_count=0,
                       correction_count=int(si==2 and retries>0),audio_replay_count=int(si in (1,4) and retries>0),
                       hint_count=0,is_abandoned=False,timestamp=(when+timedelta(seconds=index*15)).isoformat())
            events.append(event);oracle.append(first)
            docs['item_bank'].append(dict(item_id=item['item_id'],activity_id=activity['id'],knowledge_component_id=kc,difficulty_b=b,is_anchor=item.get('is_anchor',False),**origin))
            # Supportive/non-primary items do not update synthetic literacy mastery.
            if activity['research_metadata']['research_role']=='primary':
                before=mastery.get(kc,.3);after=bkt.update_knowledge_state(before,kc,first);mastery[kc]=after
                theta=irt.update_theta(theta,first,b)
                recommendation=policy.get_next_action(after,0.0,activity['id'],{})
                decision_index+=1
                docs['adaptive_decisions'].append(dict(event_id=event['event_id'],student_id=args.student_id,session_id=session,item_id=item['item_id'],
                    created_at=event['timestamp'],mastery_before=before,mastery_after=after,behavioral_fatigue_indicator=0.,previous_difficulty=b,
                    selected_difficulty=recommendation['target_difficulty_b'],scaffold_level=recommendation['scaffold_level'],
                    next_activity=recommendation['next_activity'],decision=recommendation['decision'],decision_reason='Computed by existing BKT/Rasch/policy on synthetic first-attempt responses; recommendation only.',**origin))
        if not events:continue
        payload=dict(student_id=args.student_id,session_id=session,skill_id=skill['id'],activity_id=activity['id'],
                     session_duration_seconds=math.ceil(sum(e['total_round_latency_ms'] for e in events)/1000),events=events,device_metrics={'source':'synthetic'})
        summary=extract_session_features(TelemetrySessionSubmit(**payload)).model_dump(mode='json')
        summary.update(started_at=when.isoformat(),completed_at=(when+timedelta(seconds=payload['session_duration_seconds'])).isoformat(),**origin)
        docs['telemetry_events'].append({**payload,**origin});docs['session_summaries'].append(summary)
        truth=float(np.mean(oracle));accuracy_error.append(abs(summary['overall']['accuracy']-truth));completion_error.append(abs(np.mean([e['final_correct'] for e in events])-truth))
    docs['knowledge_states'].append(dict(student_id=args.student_id,knowledge_state=mastery,theta_estimate=theta,updated_at=(now+timedelta(days=1)).isoformat(),**origin))

    # Independent grouped cohort; task/device variation and overlapping latent traits.
    learner_count=160; observations=6; groups=np.arange(learner_count); labels=np.tile(np.arange(4),learner_count//4);rng.shuffle(labels)
    train_groups,remaining=train_test_split(groups,test_size=.4,stratify=labels,random_state=args.seed)
    valid_groups,test_groups=train_test_split(remaining,test_size=.5,stratify=labels[remaining],random_state=args.seed+1)
    rows=[];y=[];ids=[]
    for g,cls in enumerate(labels):
        phon=float(np.clip(rng.normal(.65 if cls in (1,3) else .2,.18),0,1))
        visual=float(np.clip(rng.normal(.65 if cls in (2,3) else .2,.18),0,1))
        age=int(rng.integers(5,8));gender=int(rng.integers(0,2));device=rng.normal(0,.15)
        for t in range(observations):
            difficulty=rng.uniform(-1,1);noise=rng.normal(0,.2)
            rows.append(dict(acoustic_latency_ms=float(rng.lognormal(math.log(550)+phon*.85+difficulty*.15+device,.3)),
                peak_count_delta=int(rng.poisson(.3+phon*2)),intra_word_silence_ratio=float(np.clip(.05+.32*phon+.08*noise,0,.9)),
                local_jitter=float(np.clip(.012+.04*phon+rng.normal(0,.012),.0001,.15)),local_shimmer=float(np.clip(.025+.025*phon+rng.normal(0,.012),.0001,.2)),
                time_to_first_touch_ms=float(rng.lognormal(math.log(600)+visual*.9+difficulty*.15+device,.3)),
                orthographic_confusion_index=float(np.clip(.04+.55*visual+rng.normal(0,.12),0,1)),
                path_efficiency_ratio=float(np.clip(.95-.4*visual+rng.normal(0,.1),.05,1)),
                dimensionless_jerk=float(rng.lognormal(math.log(40)+visual*.9+device,.35)),
                dwell_time_ms=float(rng.lognormal(math.log(200)+visual*.2,.3)),age=age,gender=gender,time_of_day_hour=int(rng.integers(8,16))))
            y.append(cls);ids.append(int(g))
    names=joblib.load(ROOT/'app/backend/diagnostic-fusion-v1/models/feature_names.pkl')
    X=pd.DataFrame(rows)[names];y=np.array(y);ids=np.array(ids)
    train=np.isin(ids,train_groups);valid=np.isin(ids,valid_groups);test=np.isin(ids,test_groups)
    model_path=ROOT/'app/backend/diagnostic-fusion-v1/models/xgboost_clinical_fusion.pkl'
    frozen=joblib.load(model_path)
    candidates={
      'Class-prior baseline':DummyClassifier(strategy='prior'),
      'Logistic regression baseline':make_pipeline(StandardScaler(),LogisticRegression(max_iter=1000)),
      'XGBoost candidate (not deployed)':XGBClassifier(n_estimators=100,max_depth=4,learning_rate=.1,objective='multi:softprob',num_class=4,random_state=args.seed,n_jobs=2),
    }
    comparisons=[];details={}
    def compare(name,model,cols):
        probabilities=model.predict_proba(X.loc[test,cols]);pred=np.argmax(probabilities,axis=1);truth=y[test]
        metrics={'macro_f1':float(f1_score(truth,pred,average='macro',zero_division=0)),
                 'balanced_accuracy':float(balanced_accuracy_score(truth,pred)),
                 'log_loss':float(log_loss(truth,probabilities,labels=[0,1,2,3]))}
        for metric,value in metrics.items():comparisons.append(dict(method=name,metric=metric,value=value,n=int(test.sum())))
        # Cluster bootstrap samples learners, not repeated rows independently.
        per_group=ids[test]; unique=np.unique(per_group);scores=[]
        for _ in range(200):
            sampled=rng.choice(unique,len(unique),replace=True);ix=np.concatenate([np.where(per_group==g)[0] for g in sampled])
            scores.append(f1_score(truth[ix],pred[ix],labels=[0,1,2,3],average='macro',zero_division=0))
        details[name]={**metrics,'macro_f1_cluster_bootstrap_95ci':np.quantile(scores,[.025,.975]).tolist(),
                       'confusion_matrix':confusion_matrix(truth,pred,labels=[0,1,2,3]).tolist(),
                       'validation_macro_f1':float(f1_score(y[valid],model.predict(X.loc[valid,cols]),average='macro',zero_division=0))}
    for name,model in candidates.items():
        model.fit(X.loc[train],y[train]);compare(name,model,names)
    for label,cols in [('Speech-only logistic ablation',names[:5]),('Kinematics-only logistic ablation',names[5:10])]:
        model=make_pipeline(StandardScaler(),LogisticRegression(max_iter=1000));model.fit(X.loc[train,cols],y[train]);compare(label,model,cols)
    compare('Frozen repository XGBoost (different training generator)',frozen,names)
    # Run the actual XAI engine for one held-out synthetic feature vector.
    xai=module('pp2_xai',ROOT/'app/backend/diagnostic-fusion-v1/services/xai_engine.py').XAIEngine()
    demo_index=int(np.where(test)[0][0]);vector={k:float(v) for k,v in X.iloc[demo_index].items()}
    analysis=xai.analyze_patient(vector)
    docs['learner_profiles'].append(dict(student_id=args.student_id,session_id=f'{dataset}-fusion',created_at=(now+timedelta(days=1)).isoformat(),
        learner_profile=analysis['learner_profile'],shap_explanations=analysis['shap_explanations'],model_version='C3-v1.0-frozen-repository',
        input_features=vector,feature_version='fusion-13',llm_summary=None,llm_recommendations=None,**origin))
    docs['speech_features'].append(dict(student_id=args.student_id,session_id=f'{dataset}-fusion',activity_id='act_1',item_id='S6_A1_R01',
        expected_text='ගස',recognized_text='ගස',word_error_rate=0.,acoustic_latency_ms=vector['acoustic_latency_ms'],voice_onset_ms=None,
        syllabic_event_mismatch=int(vector['peak_count_delta']),intra_word_silence_ratio=vector['intra_word_silence_ratio'],
        local_jitter=vector['local_jitter'],local_shimmer=vector['local_shimmer'],recording_quality='synthetic feature vector — not recorded speech',
        measurement_status='synthetic_features',created_at=(now+timedelta(days=1)).isoformat(),feature_version='synthetic-acoustics-v1',**origin))

    # C2 algorithm check on simple generated harmonic tones; NOT Sinhala speech/STT testing.
    acoustic=module('pp2_acoustic',ROOT/'app/backend/speech-monitoring-v1/services/acoustic_service.py').AcousticAnalysisService()
    onsets=[];estimates=[];sr=16000
    for _ in range(40):
        delay=float(rng.uniform(.1,1.2));tone_t=np.arange(sr)/sr
        tone=(.3*np.sin(2*np.pi*220*tone_t)+.1*np.sin(2*np.pi*440*tone_t)).astype(np.float32)
        signal=np.concatenate([np.zeros(int(delay*sr),dtype=np.float32),tone])
        onsets.append(int(delay*sr)/sr*1000);estimates.append(acoustic.find_voice_onset(signal,sr))
    baseline_onset=float(np.mean(onsets[:20]));onset_mae=float(np.mean(np.abs(np.array(estimates[20:])-np.array(onsets[20:]))))
    baseline_mae=float(np.mean(np.abs(baseline_onset-np.array(onsets[20:]))))

    # C4 next-response prediction under a declared simulator, not learning benefit.
    bkt_true=[];bkt_pred=[];irt_true=[];irt_pred=[];irt_static=[]
    for _ in range(80):
        learned=bool(rng.random()<rng.uniform(.15,.55));p=.3;ability=float(rng.normal(0,1));estimated_theta=0.
        for _ in range(20):
            response=bool(rng.random()<(.85 if learned else .2));bkt_true.append(response);bkt_pred.append(p*.9+(1-p)*.2)
            p=bkt.update_knowledge_state(p,'default',response)
            if not learned and rng.random()<.08:learned=True
            difficulty=float(rng.choice([-1.,0.,1.]));trueprob=irt.calculate_probability(ability,difficulty)
            answer=bool(rng.random()<trueprob);irt_true.append(answer);irt_pred.append(irt.calculate_probability(estimated_theta,difficulty))
            irt_static.append(irt.calculate_probability(0.,difficulty))
            estimated_theta=irt.update_theta(estimated_theta,answer,difficulty)
    c4comparisons=[dict(method=name,metric='next_response_brier_score_lower_is_better',value=float(brier_score_loss(truth,prediction)),n=len(truth)) for name,truth,prediction in (
        ('BKT fixed priors',bkt_true,bkt_pred),('Fixed 0.5 baseline (BKT simulation)',bkt_true,[.5]*len(bkt_true)),
        ('Online Rasch theta',irt_true,irt_pred),('Fixed theta=0 Rasch baseline',irt_true,irt_static),
        ('Fixed 0.5 baseline (IRT simulation)',irt_true,[.5]*len(irt_true)))]
    evidence=dict(student_id=args.student_id,evaluation_id=dataset+'-eval',created_at=now.isoformat(),sample_count=len(X),
        split_description='160 synthetic learners × 6 observations; 96 train / 32 validation / 32 test learners; zero learner overlap',
        generator_seed=args.seed,model_sha256=hashlib.sha256(model_path.read_bytes()).hexdigest(),
        components=[
          dict(component='C1',objective='Preserve first attempts separately from eventual completion',evidence_type='Synthetic event contract check, not predictive validation',
               input_summary=f'{len(accuracy_error)} canonical-schema synthetic sessions across six skills',
               comparisons=[dict(method='C1 first-attempt aggregate',metric='mean_absolute_error_to_synthetic_first_attempt_truth',value=float(np.mean(accuracy_error)),n=len(accuracy_error)),
                            dict(method='Final-completion baseline',metric='mean_absolute_error_to_synthetic_first_attempt_truth',value=float(np.mean(completion_error)),n=len(completion_error))],
               claim='C1 can preserve failed first attempts even when later completion succeeds on correctly instrumented input.',limitation='Tests the event contract; it does not repair inconsistent Flutter attempt hooks or validate fatigue.'),
          dict(component='C2',objective='Measure acoustic onset timing with known stimulus timing',evidence_type='Generated harmonic waveform timing check',input_summary='40 generated tones with known leading silence; first20 baseline fit, final20 comparison',
               comparisons=[dict(method='librosa onset detector',metric='onset_MAE_ms_lower_is_better',value=onset_mae,n=20),dict(method='Training-mean onset baseline',metric='onset_MAE_ms_lower_is_better',value=baseline_mae,n=20)],
               claim='Onset extraction is compared against known timings on controlled waveforms.',limitation='Harmonic tones are not Sinhala child speech. STT, pauses, jitter and shimmer still need labelled speech evaluation.'),
          dict(component='C3',objective='Compare multimodal pattern classification with simpler baselines',evidence_type='Grouped held-out synthetic classification',input_summary='13 correlated features; overlapping latent traits; independent device/task noise',comparisons=comparisons,
               claim='Scores report performance on this declared synthetic generator; any advantage or regression is shown without selecting only favorable metrics.',
               limitation='Labels and feature relationships are assumed. Frozen model used a different generator; candidate is not deployed. No Sri Lankan child validation.',artifacts='classification_details.json; synthetic_cohort.csv; generator_manifest.json'),
          dict(component='C4',objective='Track knowledge/ability for next-response prediction',evidence_type='Sequential synthetic learner simulation',input_summary='80 learners × 20 responses per simulator; predict before update',comparisons=c4comparisons,
               claim='Prediction error is measured before each response updates the state.',limitation='Simulator is related to model assumptions. Does not establish better learning, calibrated item difficulty, or applied Flutter adaptation.')],**origin)
    docs['research_evaluations'].append(evidence)
    manifest=dict(dataset_id=dataset,seed=args.seed,data_origin='synthetic',validation_status='synthetic_only',
      assumptions=['Correlated latent acoustic/visual traits with overlapping distributions','Positive latencies from lognormal distributions','Ratios clipped to [0,1]','Age/gender independent of assigned pattern','Repeated observations grouped by simulated learner; no group leakage','No claim of normative realism for Sri Lankan children'],
      split=dict(train_learners=train_groups.tolist(),validation_learners=valid_groups.tolist(),test_learners=test_groups.tolist()),
      model_sha256=evidence['model_sha256'],feature_names=names,versions={m:__import__(m).__version__ for m in ['numpy','pandas','sklearn','xgboost','shap']})
    docs['item_bank']=list({d['item_id']:d for d in docs['item_bank']}.values())
    manifest['simulation_scopes']={'session_summaries':'C1 canonical-event contract scenarios; not replayed Flutter sessions',
                                  'learner_profiles':'One held-out C3 cohort vector; synthetic speech features correspond to this vector',
                                  'knowledge_states':'C4 computed from the C1 synthetic event sequences; not measured child learning'}
    X.assign(synthetic_learner_id=ids,synthetic_pattern=y,split=np.where(train,'train',np.where(valid,'validation','test'))).to_csv(out/'synthetic_cohort.csv',index=False)
    for name,data in [('dataset.json',docs),('research_evidence.json',evidence),('classification_details.json',details),('generator_manifest.json',manifest)]:
        (out/name).write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf-8')
    print(json.dumps({'output':str(out),'documents':{k:len(v) for k,v in docs.items()},'c3_test_metrics':details,'database_written':False},indent=2))
    return docs

async def persist(args,docs):
    if not args.database or not args.confirm_synthetic_student:
        raise SystemExit('--persist requires --database and --confirm-synthetic-student; use a designated test child only')
    from motor.motor_asyncio import AsyncIOMotorClient
    from bson import ObjectId
    uri=os.environ.get('MONGODB_URL')
    if not uri:raise SystemExit('Set MONGODB_URL explicitly; no .env credentials are loaded by this script')
    client=AsyncIOMotorClient(uri);db=client[args.database]
    try:
        if not ObjectId.is_valid(args.student_id) or not await db.students.find_one({'_id':ObjectId(args.student_id)}):
            raise SystemExit('The selected synthetic/test student must already exist in this database')
        # Read-only item metadata from local JSON need not overwrite an existing calibrated bank.
        for collection,rows in docs.items():
            if collection=='item_bank':continue
            for d in rows:
                identity={'student_id':args.student_id,'data_origin':'synthetic','dataset_id':d['dataset_id']}
                for k in ['event_id','session_id','item_id','evaluation_id']:
                    if k in d:identity[k]=d[k]
                await db[collection].update_one(identity,{'$set':d},upsert=True)
        print('Synthetic dataset imported idempotently; no delete operation, account creation or item-bank overwrite performed.')
    finally:client.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed',type=int,default=20260831)
    parser.add_argument('--student-id',default='000000000000000000000031')
    parser.add_argument('--output',required=True)
    parser.add_argument('--persist',action='store_true')
    parser.add_argument('--database')
    parser.add_argument('--confirm-synthetic-student',action='store_true')
    args=parser.parse_args();docs=build(args)
    if args.persist:asyncio.run(persist(args,docs))
