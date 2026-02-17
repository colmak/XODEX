"""Deterministic biophysical heat model mirror for BURZEN v0.00.5.0."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class HeatConfig:
    base_heat_generation: float = 0.8
    heat_dissipation_rate: float = 0.35
    thermal_sensitivity: float = 0.012
    misfold_low: float = 0.05
    misfold_medium: float = 0.25
    misfold_high: float = 0.65


@dataclass(frozen=True)
class RuntimeHeatSettings:
    difficulty_scalar: float = 1.0
    global_heat_multiplier: float = 1.0
    cooling_efficiency: float = 1.0
    tower_heat_tolerance_boost: float = 0.0


def apply_heat_tick(
    heat_score: float,
    *,
    fired: bool,
    nearby_mob_density: float,
    delta: float,
    threshold: float,
    config: HeatConfig = HeatConfig(),
    runtime: RuntimeHeatSettings = RuntimeHeatSettings(),
) -> dict[str, float | bool]:
    generated = config.base_heat_generation * ((1.0 if fired else 0.0) + max(0.0, nearby_mob_density))
    generated *= runtime.difficulty_scalar * runtime.global_heat_multiplier * delta
    cooled = config.heat_dissipation_rate * runtime.cooling_efficiency * delta
    next_heat = max(0.0, heat_score + generated - cooled)
    boosted_threshold = threshold * (1.0 + runtime.tower_heat_tolerance_boost)
    normalized = min(2.0, next_heat / max(1e-9, boosted_threshold))
    return {
        "heat_score": next_heat,
        "normalized_heat": normalized,
        "misfold_probability": misfold_probability(normalized, config),
        "is_misfolded": normalized >= 1.0,
    }


def apply_bond_strength(base_strength: float, left_heat: float, right_heat: float, config: HeatConfig = HeatConfig()) -> float:
    attenuation = max(0.0, 1.0 - config.thermal_sensitivity * ((left_heat + right_heat) * 0.5) * 100.0)
    return base_strength * attenuation


def misfold_probability(normalized_heat: float, config: HeatConfig = HeatConfig()) -> float:
    if normalized_heat < 0.6:
        return config.misfold_low
    if normalized_heat < 1.0:
        return config.misfold_medium
    return config.misfold_high
