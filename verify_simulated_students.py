import asyncio
import sys
import os
from bson import ObjectId

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "app", "backend", "api"))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from shared.database import get_db, connect_to_mongo
from routers import parent_dashboard as parent_router
from routers import therapist_dashboard as therapist_router
from routers import therapist as therapist_mgmt

async def verify():
    await connect_to_mongo()
    db = get_db()
    
    dinuka = await db.students.find_one({"first_name": "Dinuka", "last_name": "Silva"})
    nuwan = await db.students.find_one({"first_name": "Nuwan", "last_name": "Perera"})
    
    dinuka_id = str(dinuka["_id"])
    nuwan_id = str(nuwan["_id"])

    print("=" * 80)
    print("1. VERIFYING PARENT DASHBOARD ENDPOINTS")
    print("=" * 80)
    for sid, name in [(dinuka_id, "Dinuka Silva (Average Performer)"), (nuwan_id, "Nuwan Perera (Struggling Learner)")]:
        print(f"\n--- {name} ({sid}) ---")
        p_overview = await parent_router.get_parent_overview(sid)
        print("  [Overview]")
        print(f"     Accuracy: {p_overview.accuracy}% | Sessions: {p_overview.sessions_completed} | Rounds: {p_overview.completed_rounds}")
        print(f"     Practice Time: {p_overview.practice_time_minutes} min | Reading Progress: {p_overview.reading_progress}")
        print(f"     Median Latency: {p_overview.median_response_latency_ms} ms")
        
        p_perf = await parent_router.get_parent_activity_performance(sid, days=30, skill_id=None, limit=100)
        acts = p_perf.get("activities", [])
        print(f"  [Activity Performance] Total activities: {len(acts)}")
        sample_acts = [f"{a.get('activity_name')}: {round((a.get('first_attempt_accuracy') or 0)*100)}% ({a.get('trials')} trials)" for a in acts[:3]]
        print(f"     Samples: {sample_acts}")
        
        p_analytics = await parent_router.get_parent_component_analytics(sid)
        print("  [Component Analytics]")
        print(f"     C1 Behavioral: {round(p_analytics['c1_behavioral']['first_attempt_accuracy']*100)}% acc, {p_analytics['c1_behavioral']['session_count']} sessions, {p_analytics['c1_behavioral']['completed_rounds']} rounds")
        print(f"     C2 Speech: WER={p_analytics['c2_speech']['wer']}, word_acc={p_analytics['c2_speech']['word_accuracy']}, recordings={p_analytics['c2_speech']['recording_count']}")
        print(f"     C3 Summary: {p_analytics['c3_explainability']['summary_text'][:110]}...")
        print(f"     C4 Adaptive: avg mastery={round(p_analytics['c4_adaptive']['average_mastery']*100)}% across {p_analytics['c4_adaptive']['knowledge_components']} areas")
        
        p_assess = await parent_router.get_parent_assessment_summary(sid)
        print(f"  [Assessment Summary] Completed categories: {p_assess['completed_categories']}/4 | Reported observations: {p_assess['reported_observations']}")
        print(f"     Categories breakdown: {p_assess['by_category']}")
        
        p_pattern = await parent_router.get_parent_learning_pattern(sid)
        print(f"  [Learning Pattern] Observation: {p_pattern.observation[:90]}...")
        print(f"     Recommendations count: {len(p_pattern.recommended_practices)}")

        p_insights = await parent_router.get_adaptive_insights(sid)
        print(f"  [Adaptive Insights] Activities count: {len(p_insights.activities)} | Policy notice: {p_insights.policy_notice[:40]}...")

    print("\n" + "=" * 80)
    print("2. VERIFYING THERAPIST DASHBOARD ENDPOINTS")
    print("=" * 80)
    for sid, name in [(dinuka_id, "Dinuka Silva (Average Performer)"), (nuwan_id, "Nuwan Perera (Struggling Learner)")]:
        print(f"\n--- {name} ({sid}) ---")
        t_overview = await therapist_router.get_therapist_overview(sid)
        print("  [Therapist Overview]")
        print(f"     Accuracy: {t_overview.accuracy} | Attempted items: {t_overview.attempted_items}")
        print(f"     Current pattern: {t_overview.current_pattern} (conf: {t_overview.pattern_confidence})")
        print(f"     Overall mastery: {t_overview.overall_mastery} across {t_overview.mastery_practised_areas} areas")
        print(f"     Reading fluency: {t_overview.reading_fluency_status} | Fatigue status: {t_overview.fatigue_status}")
        
        t_c1 = await therapist_router.get_therapist_c1_behavioral(sid, days=30)
        print("  [C1 Behavioral]")
        print(f"     First attempt acc: {t_c1.first_attempt_accuracy} | Retry rate: {t_c1.retry_rate}")
        print(f"     Median latency: {t_c1.median_response_latency_ms} ms | Fatigue state: {t_c1.fatigue_state}")
        print(f"     Kinematics dwell: {t_c1.kinematics.get('dwell_time_ms')} ms, path eff: {t_c1.kinematics.get('path_efficiency_ratio')}, jerk: {t_c1.kinematics.get('dimensionless_jerk')}, OCI: {t_c1.kinematics.get('orthographic_confusion_index')}")
        print(f"     Learner pattern estimate: {t_c1.c1_state.get('pattern_estimate', {}).get('predicted_pattern')}")
        
        t_c2 = await therapist_router.get_therapist_c2_speech(sid, days=30)
        print("  [C2 Speech & Oral Reading]")
        print(f"     Recordings: {t_c2.recording_count} (usable: {t_c2.usable_recording_count})")
        print(f"     Word accuracy: {t_c2.latest.word_accuracy} | Voice onset: {t_c2.latest.voice_onset_ms} ms")
        print(f"     Letter progress groups: {len(t_c2.letter_progress)}")
        for grp in t_c2.letter_progress:
            letters_done = sum(1 for l in grp.get('letters', []) if l.get('attempts', 0) > 0)
            print(f"        - {grp.get('title')}: {letters_done} letters practiced")
        print(f"     Letter changes recorded: {len(t_c2.letter_change_counts)}")
        
        t_c3 = await therapist_router.get_therapist_c3_profile(sid)
        print("  [C3 Combined Profile]")
        print(f"     Primary pattern: {t_c3.primary_pattern} (Classifier available: {t_c3.classifier_available})")
        print(f"     Probabilities: {t_c3.probabilities}")
        print(f"     Confidence: {t_c3.confidence}")
        print(f"     SHAP explanations count: {len(t_c3.shap_explanations)}")
        for sh in t_c3.shap_explanations[:2]:
            print(f"        * {sh.plain_text}")
        
        t_c4 = await therapist_router.get_therapist_c4_adaptive(sid, window=20)
        print("  [C4 Adaptive Support]")
        print(f"     History items: {len(t_c4.history)}")
        print(f"     Primary focus KC: {t_c4.summary.get('primary_focus_id')}")
        print(f"     Core tasks: {t_c4.summary.get('core_tasks')}, supported: {t_c4.summary.get('supported_core_tasks')}")
        print(f"     Next session activity: {t_c4.next_session_plan.get('activity_id')}")

    print("\n" + "=" * 80)
    print("3. VERIFYING THERAPIST CLINICAL WORKLIST")
    print("=" * 80)
    therapist_user = {"_id": ObjectId("6ad5a03c00c4cf9c13dbb645"), "role": "specialist"}
    summary = await therapist_mgmt.get_therapist_dashboard_summary(therapist_user)
    print(f"Total connected learners: {summary['summary']['connected_learners']}")
    print(f"Learners with evidence: {summary['summary']['learners_with_evidence']}")
    print(f"Review queue learners count: {len(summary.get('review_queue', []))}")
    for q in summary.get("review_queue", []):
        print(f"   -> {q.get('student_name')}: status={q.get('status')} | priority={q.get('priority')}")

    print("\n" + "=" * 80)
    print("4. VERIFYING STUDENT DASHBOARD COMPLETION & SCORES")
    print("=" * 80)
    for sid, name in [(dinuka_id, "Dinuka Silva (Average Performer)"), (nuwan_id, "Nuwan Perera (Struggling Learner)")]:
        st = await db.students.find_one({"_id": ObjectId(sid)})
        print(f"\n--- {name} ---")
        print(f"  Completed activities count: {len(st.get('completed_activities', []))}")
        print(f"  Activity scores count: {len(st.get('activity_scores', {}))}")
        print(f"  Sample scores: {list(st.get('activity_scores', {}).items())[:5]}")
        print(f"  Assessment completed: {st.get('assessment_completed')}")

if __name__ == "__main__":
    asyncio.run(verify())
