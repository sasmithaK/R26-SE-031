"""
services/ml_engine.py
========================
Adaptive Learning ML Engine for real-time curriculum adjustments.

This engine evaluates the recent telemetry stream of a student to determine
their immediate Cognitive Load (Engaged, Frustrated, Overwhelmed) and 
provides dynamic difficulty reduction strategies for incoming activities.
"""

from typing import List, Dict, Any

class CognitiveLoadClassifier:
    """
    A lightweight, real-time classifier that acts as a proxy for an ML model.
    It assesses recent telemetry events to deduce immediate cognitive load.
    """
    
    @staticmethod
    def classify(telemetry_history: List[Dict[str, Any]]) -> str:
        """
        Classify the student's current cognitive load.
        Valid outputs: "ENGAGED", "FRUSTRATED", "OVERWHELMED", or struggling
        """
        if not telemetry_history:
            return "ENGAGED"
        
        n = len(telemetry_history)
        
        # Calculate moving averages
        avg_hesitations = sum(e.get("hesitation_count", 0) for e in telemetry_history) / n
        avg_misclicks = sum(e.get("misclick_count", 0) for e in telemetry_history) / n
        
        # Calculate an abstract "Load Score"
        # max normal hesitations ~ 3, max normal misclicks ~ 2
        frustration_score = (avg_hesitations / 3.0) + (avg_misclicks / 2.0)
        
        if frustration_score > 2.5:
            return "OVERWHELMED"
        elif frustration_score > 1.2:
            return "FRUSTRATED"
        else:
            return "ENGAGED"

    @staticmethod
    def adapt_curriculum(skill_data: Dict[str, Any], classification: str) -> Dict[str, Any]:
        """
        Dynamically rewrite the JSON curriculum document to reduce difficulty 
        if the student is FRUSTRATED or OVERWHELMED.
        """
        if classification == "ENGAGED":
            return skill_data
            
        is_overwhelmed = (classification == "OVERWHELMED")
        
        # Mutate a shallow copy of activities
        adapted_data = dict(skill_data)
        activities = adapted_data.get("activities", [])
        
        adapted_activities = []
        for activity in activities:
            adapted_activity = dict(activity)
            
            # 1. Flag the activity as remedial so frontend applies UI reduction
            adapted_activity["isRemedial"] = True
            
            # 2. Reduce the total number of rounds if overwhelmed
            rounds = adapted_activity.get("rounds", [])
            if is_overwhelmed and len(rounds) > 3:
                adapted_activity["rounds"] = rounds[:3]
                
            adapted_activities.append(adapted_activity)
            
        adapted_data["activities"] = adapted_activities
        
        return adapted_data
