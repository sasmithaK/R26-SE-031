"""
monitoring-service-v2/core/kalman_filter.py
============================================
Kalman Filter for touch trajectory smoothing in C1 (CBME).

Models touch interaction as a Linear Dynamical System with a constant-velocity
motion model. The Kalman innovation (predicted position − observed position)
is used as a **motor-control uncertainty proxy** — a theoretically grounded
cognitive load indicator.

Theoretical grounding:
    Sweller (1988) Cognitive Load Theory: high cognitive load degrades
    fine-motor control precision. The Kalman innovation captures this
    degradation as a scalar `kalman_innovation` feature fed into the
    `visual_strain_index` computation via the multi-task LightGBM pipeline.

State vector: [x, y, dx, dy]  (position + velocity, in screen pixels)
Observation:  [x, y]          (raw touch coordinates)

Reference:
    Kalman, R. E. (1960). A New Approach to Linear Filtering and Prediction
    Problems. Journal of Basic Engineering, 82(1), 35–45.
"""

from __future__ import annotations

import numpy as np


class TouchKalmanFilter:
    """
    4-state Kalman Filter for touch trajectory kinematic smoothing.

    Usage (per task interaction session):
        kf = TouchKalmanFilter(dt=0.016)   # 60 Hz touch sampling
        for touch_event in events:
            z = np.array([touch_event.x, touch_event.y])
            innovation_norm = kf.update(z)
            # innovation_norm → feature: kalman_innovation (add to telemetry)

    The returned `innovation_norm` is the L2 norm of the Kalman residual
    (predicted position minus observed position). A high norm over a task
    indicates unstable, cognitively loaded fine-motor control.
    """

    def __init__(self, dt: float = 0.016):
        """
        Args:
            dt: Time step between touch samples in seconds.
                0.016 ≈ 60 Hz (Flutter GestureDetector default refresh).
        """
        self.dt = dt

        # State transition matrix (constant-velocity model)
        self.A = np.array([
            [1, 0, dt,  0],
            [0, 1,  0, dt],
            [0, 0,  1,  0],
            [0, 0,  0,  1],
        ], dtype=float)

        # Observation matrix — we only observe x, y (not velocities)
        self.H = np.array([
            [1, 0, 0, 0],
            [0, 1, 0, 0],
        ], dtype=float)

        # Process noise covariance (tunable; small = trust model more)
        self.Q = np.eye(4) * 0.01

        # Observation noise covariance (tunable; larger = trust sensor less)
        self.R = np.eye(2) * 0.5

        # Error covariance matrix
        self.P = np.eye(4)

        # State estimate [x, y, dx, dy]
        self.x = np.zeros(4)

        # Track cumulative innovation for session-level feature
        self._innovations: list[float] = []

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def update(self, z: np.ndarray) -> float:
        """
        Process one touch observation and return the Kalman innovation norm.

        Args:
            z: np.ndarray of shape (2,) — observed [x, y] in screen pixels.

        Returns:
            float — L2 norm of the innovation vector. High values indicate
                     motor precision degradation (cognitive load proxy).
        """
        z = z.reshape(2)

        # ── Prediction step ──────────────────────────────────────────
        x_pred = self.A @ self.x            # prior state estimate
        P_pred = self.A @ self.P @ self.A.T + self.Q   # prior error covariance

        # ── Innovation ───────────────────────────────────────────────
        y_innov = z - self.H @ x_pred       # measurement residual
        S = self.H @ P_pred @ self.H.T + self.R   # innovation covariance
        K = P_pred @ self.H.T @ np.linalg.inv(S)  # Kalman gain

        # ── Update step ──────────────────────────────────────────────
        self.x = x_pred + K @ y_innov
        self.P = (np.eye(4) - K @ self.H) @ P_pred

        innovation_norm = float(np.linalg.norm(y_innov))
        self._innovations.append(innovation_norm)
        return innovation_norm

    def session_mean_innovation(self) -> float:
        """
        Returns the mean innovation norm across all updates in this session.
        Use as the `kalman_innovation` feature value for C1's LightGBM input.
        """
        if not self._innovations:
            return 0.0
        return float(np.mean(self._innovations))

    def reset(self) -> None:
        """Reset state for a new task or session."""
        self.P = np.eye(4)
        self.x = np.zeros(4)
        self._innovations.clear()
