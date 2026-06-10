"""
visual-service-v1/core/sovcm.py
=================================
Sinhala Orthographic Visual Complexity Model (SOVCM) — C2 (AVLI).

Per-character structural complexity lookup for Sinhala script (U+0D80–U+0DFF).
Serves as the novel context feature for the LinUCB contextual bandit.

composite_score = 0.30·stroke + 0.25·enclosed + 0.20·v_asym
                + 0.15·h_asym + 0.10·pilla_density

Reference:
    Whitney, D. & Levi, D. M. (2011). Visual crowding. Trends in Cognitive
    Sciences, 15(4), 160–168.
"""

from __future__ import annotations
from typing import Dict, Optional
import numpy as np


# ---------------------------------------------------------------------------
# SOVCM Lookup Table  (s=strokes, e=enclosed, va=vert_asym, ha=horiz_asym, p=pilla)
# ---------------------------------------------------------------------------
SOVCM_TABLE: Dict[str, dict] = {
    # Vowels
    "අ": {"s":3,"e":0,"va":0.3,"ha":0.4,"p":0}, "ආ": {"s":4,"e":0,"va":0.3,"ha":0.5,"p":0},
    "ඇ": {"s":4,"e":1,"va":0.4,"ha":0.5,"p":0}, "ඈ": {"s":5,"e":1,"va":0.4,"ha":0.6,"p":0},
    "ඉ": {"s":2,"e":0,"va":0.2,"ha":0.3,"p":0}, "ඊ": {"s":3,"e":0,"va":0.2,"ha":0.4,"p":0},
    "උ": {"s":2,"e":0,"va":0.3,"ha":0.4,"p":0}, "ඌ": {"s":3,"e":0,"va":0.3,"ha":0.5,"p":0},
    "එ": {"s":2,"e":0,"va":0.2,"ha":0.3,"p":0}, "ඒ": {"s":3,"e":0,"va":0.2,"ha":0.4,"p":0},
    "ඔ": {"s":3,"e":1,"va":0.4,"ha":0.4,"p":0}, "ඕ": {"s":4,"e":1,"va":0.4,"ha":0.5,"p":0},
    # Consonants
    "ක": {"s":3,"e":0,"va":0.3,"ha":0.4,"p":0}, "ඛ": {"s":4,"e":1,"va":0.4,"ha":0.5,"p":0},
    "ග": {"s":3,"e":1,"va":0.5,"ha":0.4,"p":0}, "ඝ": {"s":4,"e":1,"va":0.5,"ha":0.5,"p":0},
    "ච": {"s":3,"e":0,"va":0.2,"ha":0.3,"p":0}, "ඡ": {"s":4,"e":0,"va":0.3,"ha":0.4,"p":0},
    "ජ": {"s":3,"e":0,"va":0.3,"ha":0.5,"p":0}, "ඣ": {"s":4,"e":1,"va":0.4,"ha":0.5,"p":0},
    "ට": {"s":2,"e":0,"va":0.2,"ha":0.2,"p":0}, "ඨ": {"s":3,"e":0,"va":0.2,"ha":0.3,"p":0},
    "ඩ": {"s":3,"e":1,"va":0.4,"ha":0.4,"p":0}, "ඪ": {"s":4,"e":1,"va":0.4,"ha":0.5,"p":0},
    "ණ": {"s":3,"e":1,"va":0.5,"ha":0.5,"p":0},
    "ත": {"s":2,"e":0,"va":0.1,"ha":0.2,"p":0}, "ථ": {"s":3,"e":0,"va":0.2,"ha":0.3,"p":0},
    "ද": {"s":3,"e":1,"va":0.4,"ha":0.5,"p":0}, "ධ": {"s":4,"e":1,"va":0.5,"ha":0.5,"p":0},
    "න": {"s":3,"e":0,"va":0.3,"ha":0.4,"p":0},
    "ප": {"s":3,"e":1,"va":0.4,"ha":0.3,"p":0}, "ඵ": {"s":4,"e":1,"va":0.4,"ha":0.4,"p":0},
    "බ": {"s":3,"e":1,"va":0.5,"ha":0.4,"p":0}, "භ": {"s":4,"e":1,"va":0.5,"ha":0.5,"p":0},
    "ම": {"s":4,"e":1,"va":0.5,"ha":0.4,"p":0},
    "ය": {"s":3,"e":0,"va":0.3,"ha":0.5,"p":0}, "ර": {"s":2,"e":0,"va":0.2,"ha":0.3,"p":0},
    "ල": {"s":2,"e":0,"va":0.1,"ha":0.2,"p":0}, "ව": {"s":3,"e":0,"va":0.2,"ha":0.3,"p":0},
    "ශ": {"s":5,"e":2,"va":0.6,"ha":0.6,"p":0}, "ෂ": {"s":5,"e":2,"va":0.6,"ha":0.6,"p":0},
    "ස": {"s":4,"e":1,"va":0.4,"ha":0.5,"p":0}, "හ": {"s":4,"e":1,"va":0.5,"ha":0.5,"p":0},
    "ළ": {"s":3,"e":0,"va":0.2,"ha":0.3,"p":0}, "ෆ": {"s":3,"e":1,"va":0.4,"ha":0.4,"p":0},
    # Vowel signs (pilla / matura)
    "\u0DCF":{"s":1,"e":0,"va":0.1,"ha":0.1,"p":1},  # ා
    "\u0DD0":{"s":1,"e":0,"va":0.1,"ha":0.2,"p":1},  # ැ
    "\u0DD1":{"s":2,"e":0,"va":0.2,"ha":0.2,"p":1},  # ෑ
    "\u0DD2":{"s":1,"e":0,"va":0.1,"ha":0.1,"p":1},  # ි
    "\u0DD3":{"s":2,"e":0,"va":0.1,"ha":0.2,"p":1},  # ී
    "\u0DD4":{"s":1,"e":0,"va":0.1,"ha":0.1,"p":1},  # ු
    "\u0DD6":{"s":2,"e":0,"va":0.1,"ha":0.2,"p":1},  # ූ
    "\u0DD8":{"s":2,"e":0,"va":0.2,"ha":0.2,"p":1},  # ෘ
    "\u0DDA":{"s":2,"e":1,"va":0.3,"ha":0.3,"p":2},  # ෙ
    "\u0DDB":{"s":3,"e":1,"va":0.3,"ha":0.3,"p":2},  # ේ
    "\u0DDC":{"s":3,"e":1,"va":0.4,"ha":0.4,"p":2},  # ෝ  wraps both sides
    "\u0DDD":{"s":4,"e":1,"va":0.4,"ha":0.5,"p":2},  # ෞ
    "\u0DDE":{"s":3,"e":1,"va":0.4,"ha":0.4,"p":2},  # ෟ
    "\u0DDF":{"s":2,"e":0,"va":0.2,"ha":0.3,"p":1},  # ෯
    "\u0DCA":{"s":1,"e":0,"va":0.1,"ha":0.1,"p":0},  # ් hal/virama
}

_W = (0.30, 0.25, 0.20, 0.15, 0.10)   # weight vector
_MAX = (5, 2, 1, 1, 2)                  # normalisation denominators


def _composite(e: dict) -> float:
    return (
        _W[0] * e["s"]  / _MAX[0] +
        _W[1] * e["e"]  / _MAX[1] +
        _W[2] * e["va"]           +
        _W[3] * e["ha"]           +
        _W[4] * e["p"]  / _MAX[4]
    )


def compute_sovcm_score(char: str) -> Optional[dict]:
    """Return SOVCM profile dict for one Sinhala character, or None."""
    e = SOVCM_TABLE.get(char)
    if e is None:
        return None
    return {
        "stroke_count":         e["s"],
        "enclosed_regions":     e["e"],
        "vertical_asymmetry":   e["va"],
        "horizontal_asymmetry": e["ha"],
        "pilla_density":        e["p"],
        "composite_score":      round(_composite(e), 4),
    }


def task_complexity(content_text: str) -> float:
    """
    Mean composite SOVCM score across all Sinhala characters in content_text.
    Returns 0.5 (neutral) if no Sinhala characters found.
    Used as `task_complexity_sovcm` context dimension in LinUCB.
    """
    scores = [_composite(SOVCM_TABLE[c]) for c in content_text if c in SOVCM_TABLE]
    return float(np.mean(scores)) if scores else 0.5


def crowding_load(content_text: str, current_letter_spacing_px: float) -> float:
    """
    Visual crowding load for a Sinhala string.
    crowding_i = similarity(char_i, char_{i+1}) / (spacing + 1)
    Returns 0.0 if fewer than 2 Sinhala characters present.
    """
    chars = [c for c in content_text if c in SOVCM_TABLE]
    if len(chars) < 2:
        return 0.0
    scores = []
    for i in range(len(chars) - 1):
        sim = 1.0 - abs(_composite(SOVCM_TABLE[chars[i]]) - _composite(SOVCM_TABLE[chars[i+1]]))
        scores.append(sim / (current_letter_spacing_px + 1.0))
    return float(np.mean(scores))
