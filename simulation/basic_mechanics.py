"""Reference core game mechanics for BURZEN TD.

The goal is to keep first-pass gameplay logic in small pure functions so that
balancing can happen by changing parameters instead of rewriting control flow.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CoreRules:
    """Tunable rules for the baseline loop."""

    max_towers: int = 5
    base_enemy_hp: float = 100.0
    enemy_hp_growth_per_wave: float = 0.20
    base_enemy_speed: float = 84.0
    enemy_speed_growth_per_wave: float = 0.06
    base_reward: int = 5


@dataclass(frozen=True)
class TowerStats:
    damage: float = 20.0
    range_px: float = 115.0
    fire_rate_per_second: float = 1.0


@dataclass(frozen=True)
class EnemySnapshot:
    hp: float
    progress_px: float
    speed_px_s: float


def can_place_tower(current_towers: int, rules: CoreRules) -> bool:
    """Return True when the player can place another tower."""

    return current_towers < rules.max_towers


def enemy_hp_for_wave(wave_index: int, rules: CoreRules) -> float:
    """Deterministic wave HP scaling.

    Wave index is 1-based.
    """

    return rules.base_enemy_hp * (1.0 + rules.enemy_hp_growth_per_wave * max(0, wave_index - 1))


def enemy_speed_for_wave(wave_index: int, rules: CoreRules) -> float:
    """Deterministic wave speed scaling.

    Wave index is 1-based.
    """

    return rules.base_enemy_speed * (1.0 + rules.enemy_speed_growth_per_wave * max(0, wave_index - 1))


def step_enemy(enemy: EnemySnapshot, dt: float) -> EnemySnapshot:
    """Advance enemy position over a frame."""

    return EnemySnapshot(hp=enemy.hp, progress_px=enemy.progress_px + enemy.speed_px_s * dt, speed_px_s=enemy.speed_px_s)


def tower_hit_damage(tower: TowerStats, dt: float, overheated: bool) -> float:
    """Damage output for a single simulation step.

    Uses continuous DPS model derived from per-shot damage and fire-rate.
    """

    if overheated:
        return 0.0
    return tower.damage * tower.fire_rate_per_second * dt


def apply_damage(enemy: EnemySnapshot, damage: float) -> EnemySnapshot:
    """Apply damage and clamp to zero HP."""

    return EnemySnapshot(hp=max(0.0, enemy.hp - damage), progress_px=enemy.progress_px, speed_px_s=enemy.speed_px_s)


def is_enemy_defeated(enemy: EnemySnapshot) -> bool:
    return enemy.hp <= 0.0


def reward_for_kill(wave_index: int, rules: CoreRules) -> int:
    """Simple reward rule that scales per wave.

    Wave index is 1-based.
    """

    return int(rules.base_reward * (1 + 0.25 * max(0, wave_index - 1)))
