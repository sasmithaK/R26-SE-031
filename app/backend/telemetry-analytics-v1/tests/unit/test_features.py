import pytest
from services.c1.features import calculate_accuracy, calculate_mean_latency, calculate_completion_rate

def test_calculate_accuracy():
    events = [{"is_correct": True}, {"is_correct": False}, {"is_correct": True}]
    assert calculate_accuracy(events) == 2/3
    assert calculate_accuracy([]) is None
    
def test_calculate_mean_latency():
    events = [{"total_round_latency_ms": 1000}, {"total_round_latency_ms": 2000}]
    assert calculate_mean_latency(events) == 1500.0
    
def test_calculate_completion_rate():
    events = [{"is_abandoned": False}, {"is_abandoned": True}]
    assert calculate_completion_rate(events) == 0.5
