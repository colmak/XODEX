from __future__ import annotations

from dataclasses import dataclass

from codex_eigenstate import decode_payload, encode_payload
from burzen_td import (
    FOUR_SLOT_LOADOUT,
    BurzenTDState,
    CampaignProgress,
    CustomSettings,
    InfiniteMode,
    SimulationConfig,
    TowerArchetype,
    TowerState,
    advance_campaign,
    burzen_step,
    build_campaign_levels,
    validate_loadout,
)


@dataclass
class LevelRuntime:
    progress: CampaignProgress
    level_tick: int = 0


class WasmutableOrchestrator:
    """Deterministic payload-only orchestrator for BURZEN TD v1.0."""

    def __init__(self) -> None:
        self.levels = build_campaign_levels()
        self.runtime = LevelRuntime(progress=CampaignProgress())

    def _decode_action(self, action_payload: str) -> dict[str, object]:
        payload = decode_payload(action_payload)
        if payload.get("schema") != "burzen_action_v1":
            raise ValueError("Unsupported action schema")
        return payload

    def start_level(self, action_payload: str) -> str:
        action = self._decode_action(action_payload)
        loadout = tuple(TowerArchetype(item) for item in action.get("loadout", []))
        validate_loadout(loadout)

        level_index = int(action.get("level", self.runtime.progress.current_level))
        level_cfg = self.levels[level_index - 1]
        unlocked = set(level_cfg["unlocked"])
        if not set(loadout).issubset(unlocked):
            raise ValueError("Loadout contains locked towers for level")

        self.runtime.level_tick = 0
        return encode_payload(
            {
                "schema": "burzen_level_started_v1",
                "level": level_index,
                "tick": self.runtime.level_tick,
                "slot_limit": FOUR_SLOT_LOADOUT,
                "loadout": [t.value for t in loadout],
                "required_generation": level_cfg["required_generation"],
                "safe_heat_q95": level_cfg["safe_heat_q95"],
            }
        )

    def run_level_tick(self, action_payload: str) -> str:
        action = self._decode_action(action_payload)
        loadout = tuple(TowerArchetype(item) for item in action["loadout"])
        validate_loadout(loadout)

        config = SimulationConfig()
        if "custom" in action:
            custom = action["custom"]
            settings = CustomSettings(
                allowed_towers=tuple(TowerArchetype(item) for item in custom.get("allowed_towers", [t.value for t in TowerArchetype])),
                map_energy_scalar=float(custom.get("map_energy_scalar", 1.0)),
                map_heat_scalar=float(custom.get("map_heat_scalar", 1.0)),
                override_alpha=custom.get("alpha"),
                override_beta=custom.get("beta"),
            )
            if settings.override_alpha is not None:
                config.alpha = float(settings.override_alpha)
            if settings.override_beta is not None:
                config.beta = float(settings.override_beta)

        towers = [TowerState(archetype=t) for t in loadout]
        state = BurzenTDState(towers=towers, tick=int(action.get("tick", 0)))
        n = len(towers)
        couplings = [[0.0 if i == j else 0.08 for j in range(n)] for i in range(n)]
        heat_diff = [[0.0 if i == j else 0.05 for j in range(n)] for i in range(n)]
        delta = burzen_step(state, couplings, heat_diff, config=config)

        self.runtime.level_tick = state.tick
        return encode_payload(
            {
                "schema": "eigenstate_delta_v1",
                "tick": delta.tick,
                "energy": {
                    "lambda2": delta.energy_lambda2,
                    "lambda3": delta.energy_lambda3,
                    "fiedler_sign_balance": delta.fiedler_sign_balance,
                },
                "heat": {
                    "mean": delta.heat_mean,
                    "std": delta.heat_std,
                    "q95": delta.heat_q95,
                    "instability_count": delta.instability_count,
                },
            }
        )

    def complete_level(self, won: bool) -> str:
        self.runtime.progress = advance_campaign(self.runtime.progress, won)
        return encode_payload(
            {
                "schema": "campaign_progress_v1",
                "current_level": self.runtime.progress.current_level,
                "completed_levels": list(self.runtime.progress.completed_levels),
            }
        )

    def next_infinite_wave(self, seed: int, wave_index: int, entropy: float = 0.2) -> str:
        mode = InfiniteMode(seed=seed, wave_index=wave_index, entropy=entropy)
        strength = mode.next_wave_strength()
        return encode_payload(
            {
                "schema": "infinite_wave_v1",
                "seed": seed,
                "wave_index": wave_index,
                "difficulty": strength,
            }
        )
