from codex_eigenstate import decode_payload, encode_payload
from burzen_td import (
    BurzenTDState,
    CampaignProgress,
    SimulationConfig,
    TowerArchetype,
    TowerState,
    advance_campaign,
    burzen_step,
    validate_loadout,
)
from orchestrator import WasmutableOrchestrator


def test_energy_heat_updates_deterministic():
    towers = [
        TowerState(archetype=TowerArchetype.ENERGY, energy=30.0, heat=5.0),
        TowerState(archetype=TowerArchetype.THERMAL, energy=28.0, heat=6.0),
        TowerState(archetype=TowerArchetype.KINETIC, energy=26.0, heat=7.0),
        TowerState(archetype=TowerArchetype.FIELD, energy=24.0, heat=8.0),
    ]
    state = BurzenTDState(towers=towers, tick=0)
    n = len(towers)
    couplings = [[0.0 if i == j else 0.09 for j in range(n)] for i in range(n)]
    heat_diff = [[0.0 if i == j else 0.04 for j in range(n)] for i in range(n)]

    delta_a = burzen_step(state, couplings, heat_diff, SimulationConfig())

    towers_b = [
        TowerState(archetype=TowerArchetype.ENERGY, energy=30.0, heat=5.0),
        TowerState(archetype=TowerArchetype.THERMAL, energy=28.0, heat=6.0),
        TowerState(archetype=TowerArchetype.KINETIC, energy=26.0, heat=7.0),
        TowerState(archetype=TowerArchetype.FIELD, energy=24.0, heat=8.0),
    ]
    state_b = BurzenTDState(towers=towers_b, tick=0)
    delta_b = burzen_step(state_b, couplings, heat_diff, SimulationConfig())

    assert delta_a == delta_b


def test_loadout_rule_requires_exactly_4_slots():
    validate_loadout(
        (
            TowerArchetype.KINETIC,
            TowerArchetype.THERMAL,
            TowerArchetype.ENERGY,
            TowerArchetype.FIELD,
        )
    )

    try:
        validate_loadout((TowerArchetype.KINETIC, TowerArchetype.THERMAL))
    except ValueError as exc:
        assert "exactly 4" in str(exc)
    else:
        raise AssertionError("Expected 4-slot validation failure")


def test_campaign_progression_and_orchestrator_payloads():
    orchestrator = WasmutableOrchestrator()

    start_payload = encode_payload(
        {
            "schema": "burzen_action_v1",
            "level": 1,
            "loadout": ["kinetic", "thermal", "energy", "reaction"],
        }
    )
    started = decode_payload(orchestrator.start_level(start_payload))
    assert started["slot_limit"] == 4

    tick_payload = encode_payload(
        {
            "schema": "burzen_action_v1",
            "tick": 0,
            "loadout": ["kinetic", "thermal", "energy", "reaction"],
        }
    )
    delta = decode_payload(orchestrator.run_level_tick(tick_payload))
    assert delta["schema"] == "eigenstate_delta_v1"
    assert "heat" in delta and "energy" in delta

    progress = decode_payload(orchestrator.complete_level(True))
    assert progress["current_level"] == 2


def test_advance_campaign_caps_at_level_10():
    p = CampaignProgress(current_level=10, completed_levels=(1, 2, 3))
    next_p = advance_campaign(p, won=True)
    assert next_p.current_level == 10
