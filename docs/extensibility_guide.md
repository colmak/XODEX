# Extensibility Guide

This document explains how to extend the current BURZEN prototype without destabilizing its core simulation loop.

## Core principle

The thermal model is the central balancing axis. New content should preserve this priority:

- Tower output should interact with heat.
- Enemy behavior should react to heat states.
- WASMUTABLE events should mutate systems in ways that remain readable to players.

## Add a new tower type

1. **Define tower identity**
   - Role (`single-target`, `splash`, `support`, etc.)
   - Base damage, fire interval, heat gain per shot
   - Upgrade multipliers
2. **Wire simulation behavior**
   - Keep damage compatible with the existing formula (`base × role × upgrade × heat`).
   - Add guard rails (no negative damage, no NaN heat values).
3. **Expose visual/debug state**
   - Include heat visualization updates for new tower states.
   - Ensure overlay mode displays meaningful values.
4. **Regression checks**
   - Add/adjust simulation tests under `simulation/`.
   - Confirm no regressions via `./scripts/run_tests.sh`.

## Add a new enemy class

1. Define class profile with explicit values:
   - HP
   - Speed
   - Heat vulnerability/resistance
   - Any pathing quirks
2. Integrate into wave spawner tables.
3. Verify behavior against overheated and cool tower states.
4. Add documentation notes (table row in design docs or README if user-facing).

## Add a WASMUTABLE event

WASMUTABLE events should be deterministic per seed/wave and visible to the player.

### JSON event schema (recommended)

Use a shape like:

```json
{
  "id": "cost_flip_01",
  "wave": 7,
  "type": "cost_flip",
  "duration_seconds": 10,
  "payload": {
    "tower_cost_multiplier": -1
  }
}
```

### Event integration checklist

- Validate event fields before runtime application.
- Log event activation/deactivation in debug overlay.
- Ensure mutation cleanly reverts after duration.
- Add deterministic tests for seeded replay consistency.

## Safety checklist for all extensions

- Keep deterministic behavior for identical seed input.
- Avoid hidden state that bypasses save/load and replay assumptions.
- Keep Android performance in mind (avoid frame spikes in per-frame loops).
- Update docs whenever extension points change.


## Tower selection module (v0.00.5.0)

Heat-aware placement now routes through `TowerSelectionUI` + `HeatEngine` contracts.

- Add new residue cards in `android/BurzenTD/scripts/ui/TowerSelectionUI.gd` catalog payloads.
- Keep heat fields (`heat_tolerance`, `heat_gen_rate`) explicit for WASMUTABLE patchability.
- Update educational notes in `docs/tower_selection_module.md` when introducing new residue classes.
- If extending live settings, map new values through `LevelManager.settings["heat"]` and forward to `HeatEngine.set_runtime_settings(...)`.
