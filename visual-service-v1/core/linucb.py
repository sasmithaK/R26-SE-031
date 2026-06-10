"""
visual-service-v1/core/linucb.py
==================================
LinUCB Contextual Bandit for typography adaptation in C2 (AVLI).

Reference:
    Li, L., Chu, W., Langford, J., & Schapire, R. E. (2010). A contextual-bandit
    approach to personalized news article recommendation. WWW '10, 661–670.

Arms (8 typography configurations):
    Each arm is a pre-defined typography parameter combination stored in
    data/arm_presets.json. The bandit learns which arm produces the highest
    reading-fluency reward for each child, conditioned on the context vector.

Context vector (d=7):
    [visual_strain_index, engagement_index, session_number_normalized,
     child_age_normalized, task_complexity_sovcm, crowding_load,
     phonological_strain_index]

Reward:
    r = (visual_strain_before - visual_strain_after) + 0.3 * accuracy_delta
    Range: approximately [-1.3, +1.3]; higher is better.

Research novelty (Sinhala/Tamil):
    Arms include diacritic_offset and glyph_padding parameters which are
    Sinhala/Tamil abugida-specific (no prior work). These compensate for
    vowel sign detachment when inter-character spacing increases.
"""

from __future__ import annotations

import json
import os
import pickle
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np


CONTEXT_DIM = 7   # d
NUM_ARMS    = 8   # K
ALPHA       = 0.1 # exploration parameter


class LinUCBArm:
    """
    Per-arm parameters for LinUCB.

    A: (d × d) positive definite matrix (initialized to identity).
    b: (d × 1) vector.
    theta: A^{-1} b (cached for efficient arm selection).
    """

    def __init__(self, arm_id: int, d: int = CONTEXT_DIM):
        self.arm_id = arm_id
        self.d = d
        self.A: np.ndarray = np.identity(d)          # (d × d)
        self.b: np.ndarray = np.zeros((d, 1))         # (d × 1)
        self._A_inv: Optional[np.ndarray] = None      # cached inverse

    def _get_A_inv(self) -> np.ndarray:
        if self._A_inv is None:
            self._A_inv = np.linalg.inv(self.A)
        return self._A_inv

    def ucb_score(self, context: np.ndarray, alpha: float = ALPHA) -> float:
        """
        Compute UCB score for this arm given context vector x (d × 1).
        score = theta^T x + alpha * sqrt(x^T A^{-1} x)
        """
        x = context.reshape(-1, 1)   # (d × 1)
        A_inv = self._get_A_inv()
        theta = A_inv @ self.b       # (d × 1)
        exploit = (theta.T @ x).item()
        explore = alpha * float(np.sqrt((x.T @ A_inv @ x).item()))
        return exploit + explore

    def update(self, context: np.ndarray, reward: float) -> None:
        """Update A and b given received reward. Invalidates A_inv cache."""
        x = context.reshape(-1, 1)
        self.A += x @ x.T
        self.b += reward * x
        self._A_inv = None  # invalidate cache

    def to_dict(self) -> dict:
        return {
            "arm_id": self.arm_id,
            "A": self.A.tolist(),
            "b": self.b.tolist(),
        }

    @classmethod
    def from_dict(cls, d: dict) -> "LinUCBArm":
        arm = cls(arm_id=d["arm_id"])
        arm.A = np.array(d["A"])
        arm.b = np.array(d["b"])
        return arm


class LinUCBAgent:
    """
    Disjoint LinUCB agent managing K arms for typography selection.

    Usage:
        agent = LinUCBAgent.load_or_create(state_path, presets_path)
        arm_id = agent.select_arm(context_vector)
        # ... Flutter renders typography for arm_id ...
        agent.update(arm_id, context_vector, reward)
        agent.save(state_path)
    """

    def __init__(self, arm_presets: List[dict]):
        self.arms: List[LinUCBArm] = [
            LinUCBArm(arm_id=i) for i in range(NUM_ARMS)
        ]
        self.arm_presets = arm_presets
        self.total_steps = 0
        self.cumulative_reward = 0.0

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def select_arm(self, context: np.ndarray) -> int:
        """
        Select arm with highest UCB score. Exploration parameter α=0.1.
        Returns arm_id (0–7).
        """
        scores = [arm.ucb_score(context) for arm in self.arms]
        return int(np.argmax(scores))

    def update(self, arm_id: int, context: np.ndarray, reward: float) -> None:
        """Update the selected arm with received reward."""
        self.arms[arm_id].update(context, reward)
        self.total_steps += 1
        self.cumulative_reward += reward

    def get_typography_config(self, arm_id: int) -> dict:
        """Return the typography preset dict for a given arm_id."""
        return self.arm_presets[arm_id]

    def get_stats(self) -> dict:
        return {
            "total_steps": self.total_steps,
            "cumulative_reward": round(self.cumulative_reward, 4),
            "arm_selection_counts": self._arm_counts(),
        }

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------

    def save(self, state_path: str) -> None:
        state = {
            "arms": [arm.to_dict() for arm in self.arms],
            "total_steps": self.total_steps,
            "cumulative_reward": self.cumulative_reward,
            "arm_presets": self.arm_presets,
        }
        Path(state_path).parent.mkdir(parents=True, exist_ok=True)
        with open(state_path, "wb") as f:
            pickle.dump(state, f)

    @classmethod
    def load_or_create(cls, state_path: str, presets_path: str) -> "LinUCBAgent":
        """Load from pickle if exists, else initialize from arm presets JSON."""
        presets = _load_presets(presets_path)
        if os.path.exists(state_path):
            try:
                with open(state_path, "rb") as f:
                    state = pickle.load(f)
                agent = cls(arm_presets=presets)
                agent.arms = [LinUCBArm.from_dict(d) for d in state["arms"]]
                agent.total_steps = state.get("total_steps", 0)
                agent.cumulative_reward = state.get("cumulative_reward", 0.0)
                return agent
            except Exception:
                pass
        return cls(arm_presets=presets)

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _arm_counts(self) -> Dict[int, int]:
        """Proxy count from A diagonal (number of updates per arm)."""
        counts = {}
        for arm in self.arms:
            # Diagonal of A minus identity gives number of outer product updates
            counts[arm.arm_id] = int(round(np.trace(arm.A) - CONTEXT_DIM))
        return counts


# ---------------------------------------------------------------------------
# Context Vector Builder
# ---------------------------------------------------------------------------

def build_context_vector(
    visual_strain_index: float,
    engagement_index: float,
    session_number: int,
    child_age_years: Optional[int],
    task_complexity_sovcm: float,
    crowding_load: float,
    phonological_strain_index: float,
) -> np.ndarray:
    """
    Build the (d=7) context vector for LinUCB.

    Normalization:
        session_number:    capped at 50, normalized to [0, 1]
        child_age_years:   6–10 years → normalized to [0, 1]; default 0.5 if unknown
        task_complexity:   already [0, 1] (SOVCM composite_score)
        crowding_load:     already [0, 1]
    """
    session_norm = min(session_number / 50.0, 1.0)
    age_norm = ((child_age_years or 7) - 6) / 4.0 if child_age_years else 0.5

    return np.array([
        visual_strain_index,
        engagement_index,
        session_norm,
        age_norm,
        task_complexity_sovcm,
        crowding_load,
        phonological_strain_index,
    ], dtype=float)


def compute_reward(
    visual_strain_before: float,
    visual_strain_after: float,
    accuracy_delta: float,
) -> float:
    """
    Reward = reduction in visual strain + weighted accuracy improvement.
    r ∈ approximately [-1.3, +1.3].
    """
    strain_reduction = visual_strain_before - visual_strain_after
    return strain_reduction + 0.3 * accuracy_delta


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

def _load_presets(presets_path: str) -> List[dict]:
    with open(presets_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data["arms"]
