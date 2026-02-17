"""Tower selection and wave damage helpers for BURZEN TD prototypes."""

from __future__ import annotations

from dataclasses import dataclass
from random import Random


@dataclass(frozen=True)
class TowerSetting:
    id: str
    dps: float
    heat_scale: float
    targeting: str
    replacements: tuple[str, ...]
    residue_class: str
    modifiers: tuple[str, ...] = ()


@dataclass(frozen=True)
class MobArchetype:
    id: str
    hp: float
    armor: float
    speed: float
    heat: float


@dataclass(frozen=True)
class TerrainProfile:
    id: str
    damage_mult: float
    heat_bias: float


@dataclass(frozen=True)
class MobInstance:
    id: str
    hp: float
    armor: float
    speed: float
    heat: float


@dataclass(frozen=True)
class WaveDamageReport:
    kills: int
    remaining_hp: float
    average_heat: float


DEFAULT_TOWERS: tuple[TowerSetting, ...] = (
    TowerSetting(
        "triangle",
        dps=42.0,
        heat_scale=0.24,
        targeting="closest",
        replacements=("square", "fire"),
        residue_class="nonpolar",
        modifiers=("hydrophobic_core",),
    ),
    TowerSetting(
        "square",
        dps=28.0,
        heat_scale=0.16,
        targeting="highest_hp",
        replacements=("triangle", "water"),
        residue_class="nonpolar",
        modifiers=("hydrophobic_core",),
    ),
    TowerSetting(
        "fire",
        dps=34.0,
        heat_scale=0.08,
        targeting="clustered",
        replacements=("earth", "triangle"),
        residue_class="positively_charged",
    ),
    TowerSetting(
        "water",
        dps=21.0,
        heat_scale=0.06,
        targeting="fastest",
        replacements=("fire", "air"),
        residue_class="polar_uncharged",
    ),
)

DEFAULT_MOBS: tuple[MobArchetype, ...] = (
    MobArchetype("runner", hp=80.0, armor=8.0, speed=1.45, heat=0.22),
    MobArchetype("tank", hp=210.0, armor=28.0, speed=0.72, heat=0.55),
    MobArchetype("swarm", hp=62.0, armor=5.0, speed=1.65, heat=0.34),
    MobArchetype("ember", hp=130.0, armor=14.0, speed=1.12, heat=0.75),
)

DEFAULT_TERRAINS: tuple[TerrainProfile, ...] = (
    TerrainProfile("baseline", damage_mult=1.0, heat_bias=0.0),
    TerrainProfile("ash_dunes", damage_mult=0.92, heat_bias=0.18),
    TerrainProfile("frost_lane", damage_mult=1.08, heat_bias=-0.12),
)


def generate_wave_mobs(
    *, level_index: int, wave_index: int, rng: Random, terrain: TerrainProfile, mob_archetypes: tuple[MobArchetype, ...] = DEFAULT_MOBS
) -> list[MobInstance]:
    """Generate randomized wave mobs with deterministic scaling."""

    count = 5 + level_index + int(wave_index * 0.75)
    hp_scale = 1.0 + 0.13 * max(0, wave_index - 1)
    armor_scale = 1.0 + 0.08 * max(0, level_index - 1)
    mobs: list[MobInstance] = []
    for _ in range(count):
        archetype = rng.choice(mob_archetypes)
        mobs.append(
            MobInstance(
                id=archetype.id,
                hp=archetype.hp * hp_scale,
                armor=archetype.armor * armor_scale,
                speed=archetype.speed,
                heat=min(1.0, max(0.0, archetype.heat + terrain.heat_bias)),
            )
        )
    return mobs


def simulate_wave_damage(
    *, placed_tower_ids: tuple[str, ...], towers: tuple[TowerSetting, ...], mobs: list[MobInstance], terrain: TerrainProfile
) -> WaveDamageReport:
    """Compute aggregate tower damage against a generated wave."""

    active = [tower for tower in towers if tower.id in placed_tower_ids]
    if not active:
        return WaveDamageReport(kills=0, remaining_hp=sum(m.hp for m in mobs), average_heat=_avg_heat(mobs))

    total_dps = sum(tower.dps for tower in active)
    kills = 0
    remaining_hp = 0.0
    for mob in mobs:
        heat_scale = 1.0
        for tower in active:
            heat_scale *= max(0.35, 1.0 - mob.heat * tower.heat_scale)
        armor_reduction = max(0.2, 1.0 - mob.armor / 100.0)
        dealt = total_dps * heat_scale * armor_reduction * terrain.damage_mult
        hp_left = max(0.0, mob.hp - dealt)
        if hp_left == 0.0:
            kills += 1
        remaining_hp += hp_left

    return WaveDamageReport(kills=kills, remaining_hp=remaining_hp, average_heat=_avg_heat(mobs))


def tower_setting_options(towers: tuple[TowerSetting, ...]) -> dict[str, dict[str, object]]:
    """Expose standardized tower placement settings for UI systems."""

    return {
        tower.id: {
            "targeting": tower.targeting,
            "replacements": list(tower.replacements),
            "heat_scale": tower.heat_scale,
            "dps": tower.dps,
            "residue_class": tower.residue_class,
            "modifiers": list(tower.modifiers),
        }
        for tower in towers
    }


def _avg_heat(mobs: list[MobInstance]) -> float:
    if not mobs:
        return 0.0
    return sum(m.heat for m in mobs) / len(mobs)
