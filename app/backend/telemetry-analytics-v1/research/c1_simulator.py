"""Round-level session simulator for the learner-level C1 model.

It produces telemetry events with the same fields the Flutter app sends, so
the model is trained on features computed by the live feature code
(``services/c1/learner_window.build_learner_features``) instead of on
hand-written feature values. Parameters live in ``config/c1_simulation.yaml``.
"""
from __future__ import annotations

import math
import os
from typing import Optional

import numpy as np
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASS_NAMES = ["TYPICAL", "VISUAL_ORTHOGRAPHIC_PATTERN", "PHONOLOGICAL_PATTERN", "COMBINED_PATTERN"]


def load_config(path: Optional[str] = None) -> dict:
    path = path or os.path.join(ROOT, "config", "c1_simulation.yaml")
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def _activity_table(cfg: dict) -> list[dict]:
    rows = []
    for key, (skill, act, kc, kind, rounds, audio, ft, solve, acc) in cfg["activities"].items():
        rows.append(dict(key=key, skill=int(skill), activity=int(act), kc=kc, kind=kind, rounds=int(rounds),
                         audio=bool(audio), first_touch_ms=float(ft), solve_ms=float(solve), accuracy=float(acc)))
    return rows


def _logit(p: float) -> float:
    p = min(max(p, 1e-4), 1 - 1e-4)
    return math.log(p / (1 - p))


def _sigmoid(x: float) -> float:
    return 1 / (1 + math.exp(-x))


def sample_learner(rng: np.random.Generator, pattern: str, cfg: dict) -> dict:
    t, ind = cfg["traits"], cfg["individual"]
    draw = lambda name: float(rng.uniform(*t[name][pattern]))
    weights = np.asarray(ind["skill_reached_weights"], dtype=float)
    return {
        "pattern": pattern,
        "speed": float(math.exp(rng.normal(0, ind["speed_log_sd"]))),
        "skill_offset": float(rng.normal(0, ind["skill_logit_sd"])),
        "hesitation_per_10s": draw("hesitation_per_10s"),
        "abandon": draw("abandon_per_round"),
        "fatigue_slope": draw("fatigue_slope"),
        "audio_replays": draw("audio_replays"),
        "skill_reached": int(rng.choice(np.arange(1, len(weights) + 1), p=weights / weights.sum())),
    }


def simulate_session(rng, learner: dict, activity: dict, cfg: dict, session_id: str) -> list[dict]:
    ind = cfg["individual"]
    time_mult, odds_mult = cfg["pattern_effects"][learner["pattern"]][activity["kind"]]
    events = []
    for r in range(activity["rounds"]):
        item = f"S{activity['skill']}A{activity['activity']}R{r + 1:02d}"
        base = {
            "event_id": f"{session_id}:{item}", "session_id": session_id, "item_id": item,
            "skill_id": f"skill_{activity['skill']}", "activity_id": f"act_{activity['activity']}",
            "knowledge_component_id": activity["kc"], "round_number": r + 1,
            "prompt_modality": "audio" if activity["audio"] else "visual",
        }
        tired = 1 + learner["fatigue_slope"] * r
        if rng.random() < learner["abandon"]:
            touched = rng.random() < 0.5
            elapsed = float(rng.uniform(2000, 30000))
            events.append({**base, "event_id": base["event_id"] + ":abandoned", "is_abandoned": True,
                           "is_correct": False, "final_correct": False, "first_attempt_correct": None,
                           "attempt_count": 1, "incorrect_attempt_count": 0, "misclick_count": 0,
                           "hesitation_count": 0, "audio_replay_count": 0,
                           "first_touch_latency_ms": float(rng.uniform(800, elapsed)) if touched else 0.0,
                           "total_round_latency_ms": elapsed, "time_to_correct_ms": 0.0})
            break  # the child left the activity
        noise = lambda: math.exp(rng.normal(0, ind["round_time_log_sd"]))
        speed = learner["speed"] * time_mult * tired
        first_touch = activity["first_touch_ms"] * speed * noise()
        p_error = _sigmoid(_logit(1 - activity["accuracy"]) + math.log(odds_mult)
                           + learner["skill_offset"] + 0.15 * learner["fatigue_slope"] * r * 10)
        wrong = 0
        if rng.random() < p_error:
            wrong = 1
            while rng.random() < ind["wrong_tap_continue"] and wrong < 6:
                wrong += 1
        solve = activity["solve_ms"] * speed * noise()
        total = first_touch + solve + wrong * ind["wrong_tap_ms"] * speed
        hesitations = int(rng.poisson(learner["hesitation_per_10s"] * total / 10000))
        total += hesitations * 8000 * 0.5  # each long pause adds time
        replays = int(rng.poisson(learner["audio_replays"])) if activity["audio"] else 0
        events.append({**base, "event_id": base["event_id"] + ":complete", "is_abandoned": False,
                       "is_correct": True, "final_correct": True, "first_attempt_correct": wrong == 0,
                       "attempt_count": wrong + 1, "incorrect_attempt_count": wrong,
                       "misclick_count": wrong, "hesitation_count": hesitations,
                       "audio_replay_count": replays, "first_touch_latency_ms": round(first_touch),
                       "total_round_latency_ms": round(total), "time_to_correct_ms": round(total)})
    return events


def simulate_learner(rng, pattern: str, cfg: dict, learner_id: str, speed_scale: float = 1.0) -> tuple[dict, list]:
    """``speed_scale`` (e.g. for age) multiplies all times; it uses no random
    draws, so the C1 training data are unchanged when it is 1.0."""
    learner = sample_learner(rng, pattern, cfg)
    learner["speed"] *= speed_scale
    activities = [a for a in _activity_table(cfg) if a["skill"] <= learner["skill_reached"]]
    n_sessions = int(rng.integers(cfg["individual"]["sessions_in_window"][0],
                                  cfg["individual"]["sessions_in_window"][1] + 1))
    sessions = []
    for s in range(n_sessions):
        activity = activities[int(rng.integers(0, len(activities)))]
        sid = f"{learner_id}-s{s + 1}"
        sessions.append(({"session_id": sid, "activity": activity}, simulate_session(rng, learner, activity, cfg, sid)))
    return learner, sessions


# --- Touch streams (used for C3 training; not needed by the C1 model) -------

DRAG_ITEMS = {"1.3": 5, "3.5": 4, "4.4": 4}  # drags per round in drag activities


def _movement_traits(rng, pattern: str, cfg: dict) -> dict:
    m = cfg["movement"]
    draw = lambda name: float(rng.uniform(*m[name][pattern]))
    return {"curvature": draw("path_curvature"), "tremor": draw("tremor"),
            "drag_ms": draw("drag_duration_ms"), "stray": draw("stray_drops_per_drag")}


def _stroke(rng, t0, start, end, duration, curvature, tremor, hz=60):
    """One finger stroke from ``start`` to ``end`` (screen ratios)."""
    n = max(3, int(duration / (1000 / hz)))
    (x0, y0), (x1, y1) = start, end
    nx, ny = -(y1 - y0), (x1 - x0)  # normal for the bow
    bow = curvature * (1 if rng.random() < 0.5 else -1)
    points = []
    for i in range(n + 1):
        u = i / n
        ease = u * u * (3 - 2 * u)  # smooth start and stop
        x = x0 + (x1 - x0) * ease + nx * bow * math.sin(math.pi * u) + rng.normal(0, tremor)
        y = y0 + (y1 - y0) * ease + ny * bow * math.sin(math.pi * u) + rng.normal(0, tremor)
        kind = "down" if i == 0 else "up" if i == n else "move"
        points.append({"x_ratio": round(min(max(x, 0.0), 1.0), 4), "y_ratio": round(min(max(y, 0.0), 1.0), 4),
                       "timestamp_ms": int(t0 + duration * u), "type": kind})
    return points


def add_touch_streams(rng, pattern: str, learner: dict, sessions: list, cfg: dict) -> None:
    """Attach Flutter-style ``touch_path`` points to every completed round."""
    traits = _movement_traits(rng, pattern, cfg)
    for meta, events in sessions:
        key = f"{meta['activity']['skill']}.{meta['activity']['activity']}"
        for event in events:
            if event.get("is_abandoned"):
                continue
            t = float(event["first_touch_latency_ms"])
            path = []
            if key in DRAG_ITEMS:
                drags = DRAG_ITEMS[key] + int(event.get("incorrect_attempt_count", 0))
                strays = int(rng.poisson(traits["stray"] * drags))
                for _ in range(drags + strays):
                    start = (float(rng.uniform(0.15, 0.85)), float(rng.uniform(0.65, 0.9)))
                    end = (float(rng.uniform(0.1, 0.9)), float(rng.uniform(0.15, 0.45)))
                    duration = traits["drag_ms"] * learner["speed"] * math.exp(rng.normal(0, 0.25))
                    path += _stroke(rng, t, start, end, duration, traits["curvature"], traits["tremor"])
                    t += duration + float(rng.uniform(300, 1500)) * learner["speed"]
                event["stray_drop_count"] = strays
                event["response_modality"] = "drag"
            else:
                for _ in range(1 + int(event.get("incorrect_attempt_count", 0))):
                    x, y = float(rng.uniform(0.1, 0.9)), float(rng.uniform(0.2, 0.9))
                    contact = float(rng.uniform(60, 160)) * (1 + 3 * traits["tremor"] * 10)
                    path += [{"x_ratio": round(x, 4), "y_ratio": round(y, 4), "timestamp_ms": int(t), "type": "down"},
                             {"x_ratio": round(x, 4), "y_ratio": round(y, 4), "timestamp_ms": int(t + contact), "type": "up"}]
                    t += contact + float(rng.uniform(800, 2500)) * learner["speed"]
            event["touch_path"] = path
