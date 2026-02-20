from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from enum import Enum


class TowerArchetype(str, Enum):
    KINETIC = "kinetic"
    THERMAL = "thermal"
    ENERGY = "energy"
    REACTION = "reaction"
    PULSE = "pulse"
    FIELD = "field"
    CONVERSION = "conversion"
    CONTROL = "control"


@dataclass(frozen=True)
class TowerParams:
    g: float
    c: float
    eta: float
    gamma: float
    rho: float
    theta: float
    e_max: float = 100.0
    h_max: float = 100.0


BASELINE_PARAMS: dict[TowerArchetype, TowerParams] = {
    TowerArchetype.KINETIC: TowerParams(16.0, 8.0, 1.00, 0.55, 0.18, 46.0),
    TowerArchetype.THERMAL: TowerParams(14.0, 9.0, 0.95, 0.82, 0.14, 40.0),
    TowerArchetype.ENERGY: TowerParams(20.0, 5.0, 1.08, 0.30, 0.22, 52.0),
    TowerArchetype.REACTION: TowerParams(12.0, 11.0, 1.06, 0.68, 0.16, 44.0),
    TowerArchetype.PULSE: TowerParams(13.0, 8.5, 1.00, 0.58, 0.18, 45.0),
    TowerArchetype.FIELD: TowerParams(11.0, 7.0, 0.96, 0.52, 0.17, 48.0),
    TowerArchetype.CONVERSION: TowerParams(10.0, 8.0, 1.04, 0.61, 0.19, 43.0),
    TowerArchetype.CONTROL: TowerParams(9.0, 6.0, 0.91, 0.47, 0.20, 50.0),
}


@dataclass
class TowerState:
    archetype: TowerArchetype
    energy: float = 32.0
    heat: float = 8.0
    activity: float = 0.70
    burst_spend: float = 0.0
    instability_ticks: int = 0


@dataclass(frozen=True)
class EigenstateDelta:
    tick: int
    energy_lambda2: float
    energy_lambda3: float
    fiedler_sign_balance: float
    heat_mean: float
    heat_std: float
    heat_q95: float
    instability_count: int


@dataclass
class SimulationConfig:
    dt: float = 1.0
    alpha: float = 0.9
    beta: float = 1.4
    instability_threshold: float = 0.08
    instability_consecutive_ticks: int = 3
    safe_heat_q95: float = 65.0


@dataclass
class BurzenTDState:
    towers: list[TowerState]
    tick: int = 0


@dataclass(frozen=True)
class CampaignProgress:
    current_level: int = 1
    completed_levels: tuple[int, ...] = ()


@dataclass
class CustomSettings:
    allowed_towers: tuple[TowerArchetype, ...] = tuple(BASELINE_PARAMS.keys())
    map_energy_scalar: float = 1.0
    map_heat_scalar: float = 1.0
    override_alpha: float | None = None
    override_beta: float | None = None


@dataclass
class InfiniteMode:
    seed: int
    wave_index: int = 1
    entropy: float = 0.2
    rng: random.Random = field(init=False)

    def __post_init__(self) -> None:
        self.rng = random.Random(self.seed)

    def next_wave_strength(self) -> float:
        base = 1.18 ** max(0, self.wave_index - 1)
        jitter = 1.0 + self.rng.uniform(-self.entropy, self.entropy)
        self.wave_index += 1
        return base * jitter


FOUR_SLOT_LOADOUT = 4


def validate_loadout(loadout: tuple[TowerArchetype, ...]) -> None:
    if len(loadout) != FOUR_SLOT_LOADOUT:
        raise ValueError("Loadout must contain exactly 4 tower archetypes")
    if len(set(loadout)) != len(loadout):
        raise ValueError("Loadout must not contain duplicate tower archetypes")


def effective_efficiency(params: TowerParams, heat: float, alpha: float) -> float:
    overflow = max(0.0, (heat - params.theta) / max(params.theta, 1e-9))
    return params.eta * math.exp(-alpha * overflow)


def _quantile(sorted_values: list[float], q: float) -> float:
    if not sorted_values:
        return 0.0
    idx = min(len(sorted_values) - 1, max(0, int(math.ceil(q * len(sorted_values)) - 1)))
    return sorted_values[idx]


def burzen_step(
    state: BurzenTDState,
    couplings: list[list[float]],
    heat_diffusion: list[list[float]],
    config: SimulationConfig = SimulationConfig(),
) -> EigenstateDelta:
    n = len(state.towers)
    if n == 0:
        state.tick += 1
        return EigenstateDelta(state.tick, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0)

    next_energy: list[float] = []
    next_heat: list[float] = []
    instability_count = 0

    for i, tower in enumerate(state.towers):
        params = BASELINE_PARAMS[tower.archetype]
        activity = tower.activity
        if tower.archetype == TowerArchetype.PULSE:
            activity = 1.0 if state.tick % 3 == 0 else 0.0

        reaction_burst = 0.0
        if tower.archetype == TowerArchetype.REACTION and tower.heat > 0.8 * params.theta:
            reaction_burst = 4.0

        eta_eff = effective_efficiency(params, tower.heat, config.alpha)
        p_gen = activity * params.g * eta_eff
        p_use = activity * params.c + tower.burst_spend + reaction_burst

        neighbor_energy = 0.0
        neighbor_heat = 0.0
        for j, neighbor in enumerate(state.towers):
            if i == j:
                continue
            kappa = couplings[i][j]
            d = heat_diffusion[i][j]
            if tower.archetype == TowerArchetype.FIELD:
                kappa *= 1.15
            if tower.archetype == TowerArchetype.THERMAL:
                d *= 1.10
            neighbor_energy += kappa * (neighbor.energy - tower.energy)
            neighbor_heat += d * (neighbor.heat - tower.heat)

        e = max(0.0, min(params.e_max, tower.energy + config.dt * (p_gen - p_use + neighbor_energy)))
        h = max(0.0, min(params.h_max, tower.heat + config.dt * (params.gamma * p_use + neighbor_heat - params.rho * tower.heat)))

        overflow_ratio = max(0.0, (h - params.theta) / max(params.theta, 1e-9))
        hazard = config.beta * (overflow_ratio**2)
        ticks = tower.instability_ticks + 1 if hazard > config.instability_threshold else 0
        tower.instability_ticks = ticks
        if ticks >= config.instability_consecutive_ticks:
            instability_count += 1

        next_energy.append(e)
        next_heat.append(h)

    for tower, e, h in zip(state.towers, next_energy, next_heat):
        tower.energy = e
        tower.heat = h

    state.tick += 1

    energy_values = sorted(next_energy)
    heat_values = sorted(next_heat)
    energy_mean = sum(next_energy) / n
    heat_mean = sum(next_heat) / n
    heat_std = math.sqrt(sum((h - heat_mean) ** 2 for h in next_heat) / n)
    sign_balance = sum(1 for e in next_energy if e >= energy_mean) / n

    return EigenstateDelta(
        tick=state.tick,
        energy_lambda2=energy_values[1] if n > 1 else energy_values[0],
        energy_lambda3=energy_values[2] if n > 2 else energy_values[-1],
        fiedler_sign_balance=sign_balance,
        heat_mean=heat_mean,
        heat_std=heat_std,
        heat_q95=_quantile(heat_values, 0.95),
        instability_count=instability_count,
    )


def build_campaign_levels() -> list[dict[str, object]]:
    levels: list[dict[str, object]] = []
    archetypes = list(TowerArchetype)
    for level in range(1, 11):
        unlocked = archetypes[: min(len(archetypes), 4 + level // 2)]
        levels.append({
            "level": level,
            "required_generation": 45.0 + level * 3.0,
            "safe_heat_q95": 58.0 + level * 1.4,
            "unlocked": tuple(unlocked),
        })
    return levels


def advance_campaign(progress: CampaignProgress, won: bool) -> CampaignProgress:
    if not won:
        return progress
    completed = tuple(sorted(set(progress.completed_levels + (progress.current_level,))))
    return CampaignProgress(current_level=min(10, progress.current_level + 1), completed_levels=completed)
