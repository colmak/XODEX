"""Reference simulation model for XODEX.PROTEIN_TOWER.

The model follows BURZEN TD v0.00.3.0(N) constraints:
- geometry-resolving behavior over an 8x8 local neighborhood
- emergent damage from disruption-field curvature
- mutable tensor updates during the wave
- temporary collapse under thermal instability
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence


Grid = Sequence[Sequence[float]]


@dataclass(frozen=True)
class ProteinTowerConfig:
    footprint_tiles: tuple[int, int] = (2, 2)
    min_radius_tiles: int = 6
    max_radius_tiles: int = 8
    local_sample_size: int = 8
    alpha_0: float = 1.0
    alpha_wave_scale: float = 0.08
    base_adaptation_rate: float = 0.22
    adaptation_decay_per_wave: float = 0.01
    min_adaptation_rate: float = 0.05
    heat_per_tick: float = 0.7
    heat_decay_per_tick: float = 0.2
    instability_threshold: float = 12.0


@dataclass(frozen=True)
class ProteinTowerState:
    theta: float = 0.5
    heat: float = 0.0
    collapsed: bool = False


@dataclass(frozen=True)
class LocalFlowState:
    creep_density: Grid
    flow_speed: Grid
    wall_block: Grid


@dataclass(frozen=True)
class ProteinTickResult:
    state: ProteinTowerState
    disruption_field: float
    curvature: float
    damage: float


def alpha_for_wave(wave_index: int, config: ProteinTowerConfig) -> float:
    return config.alpha_0 * (1.0 + config.alpha_wave_scale * max(0, wave_index))


def adaptation_rate_for_wave(wave_index: int, config: ProteinTowerConfig) -> float:
    return max(
        config.min_adaptation_rate,
        config.base_adaptation_rate - config.adaptation_decay_per_wave * max(0, wave_index),
    )


def _mean(grid: Grid) -> float:
    flat = [value for row in grid for value in row]
    return sum(flat) / max(1, len(flat))


def _center_laplacian(grid: Grid) -> float:
    rows = len(grid)
    cols = len(grid[0]) if rows else 0
    if rows < 3 or cols < 3:
        return 0.0
    cx = rows // 2
    cy = cols // 2
    center = grid[cx][cy]
    north = grid[cx - 1][cy]
    south = grid[cx + 1][cy]
    west = grid[cx][cy - 1]
    east = grid[cx][cy + 1]
    return north + south + west + east - 4.0 * center


def _compute_disruption_field(state: ProteinTowerState, local_flow: LocalFlowState) -> float:
    density = _mean(local_flow.creep_density)
    speed = _mean(local_flow.flow_speed)
    wall = _mean(local_flow.wall_block)
    return state.theta * (1.5 * density + 0.6 * speed + 0.4 * wall)


def _update_theta(
    theta: float,
    adaptation_rate: float,
    predicted_disruption: float,
    realized_escape_energy: float,
) -> float:
    error = predicted_disruption - realized_escape_energy
    return max(0.0, theta + adaptation_rate * error)


def step_protein_tower(
    state: ProteinTowerState,
    local_flow: LocalFlowState,
    wave_index: int,
    realized_escape_energy: float,
    config: ProteinTowerConfig = ProteinTowerConfig(),
) -> ProteinTickResult:
    """Run one mutable Protein Tower update tick."""

    if state.collapsed:
        cooled = max(0.0, state.heat - config.heat_decay_per_tick)
        recovered = cooled < config.instability_threshold * 0.5
        next_state = ProteinTowerState(theta=state.theta, heat=cooled, collapsed=not recovered)
        return ProteinTickResult(state=next_state, disruption_field=0.0, curvature=0.0, damage=0.0)

    disruption_field = _compute_disruption_field(state, local_flow)
    curvature = abs(_center_laplacian(local_flow.creep_density))
    damage = alpha_for_wave(wave_index, config) * curvature * disruption_field

    adaptation_rate = adaptation_rate_for_wave(wave_index, config)
    next_theta = _update_theta(state.theta, adaptation_rate, disruption_field, realized_escape_energy)

    next_heat = max(0.0, state.heat + config.heat_per_tick * disruption_field - config.heat_decay_per_tick)
    collapsed = next_heat > config.instability_threshold

    next_state = ProteinTowerState(theta=next_theta, heat=next_heat, collapsed=collapsed)
    return ProteinTickResult(
        state=next_state,
        disruption_field=disruption_field,
        curvature=curvature,
        damage=0.0 if collapsed else damage,
    )
