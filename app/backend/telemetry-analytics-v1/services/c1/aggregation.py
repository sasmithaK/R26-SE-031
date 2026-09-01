import statistics
from typing import List

def calculate_rolling_state(recent_sessions: List[dict]) -> dict:
    """
    Given the last N C1 session results, return a rolling state dictionary.
    """
    if not recent_sessions:
        return {}
        
    accuracies = []
    latencies = []
    hesitations = []
    fatigues = []
    
    for sess in recent_sessions:
        beh = sess.get("behavior", {})
        if beh.get("accuracy") is not None:
            accuracies.append(beh["accuracy"])
        if beh.get("median_latency_ms") is not None:
            latencies.append(beh["median_latency_ms"])
        if beh.get("hesitation_rate") is not None:
            hesitations.append(beh["hesitation_rate"])
            
        fat = sess.get("fatigue", {})
        if fat.get("score") is not None:
            fatigues.append(fat["score"])

    return {
        "rolling_accuracy": statistics.mean(accuracies) if accuracies else None,
        "rolling_latency": statistics.median(latencies) if latencies else None,
        "rolling_hesitation": statistics.mean(hesitations) if hesitations else None,
        "rolling_fatigue": statistics.mean(fatigues) if fatigues else None
    }
