# Basic Game Mechanics Plan

## Version
- Document version: **CODEX v0.001**
- Scope target: **BURZEN TD baseline mechanics formalization**

## Purpose & justification
Formalize the core BURZEN TD gameplay loop into simple modifiable functions so contributors can rebalance behavior by editing parameters first and logic second.

## Input / output behavior
- **Inputs:** wave index, tower count, frame delta time, tower/enemy stats, overheat state.
- **Outputs:** placement allow/deny, per-wave enemy stats, frame-progressed enemy state, damage per step, kill reward value.

## Baseline function contract
The following functions in `simulation/basic_mechanics.py` define the canonical baseline:

1. `can_place_tower(current_towers, rules)`
   - Rule: allow placement while `current_towers < max_towers`.

2. `enemy_hp_for_wave(wave_index, rules)`
   - Rule: `base_enemy_hp * (1 + hp_growth * (wave_index - 1))`.

3. `enemy_speed_for_wave(wave_index, rules)`
   - Rule: `base_enemy_speed * (1 + speed_growth * (wave_index - 1))`.

4. `step_enemy(enemy, dt)`
   - Rule: `progress += speed * dt`.

5. `tower_hit_damage(tower, dt, overheated)`
   - Rule: if overheated then `0`; else `damage * fire_rate * dt`.

6. `apply_damage(enemy, damage)`
   - Rule: `hp = max(0, hp - damage)`.

7. `is_enemy_defeated(enemy)`
   - Rule: defeated when `hp <= 0`.

8. `reward_for_kill(wave_index, rules)`
   - Rule: simple linear reward growth by wave.

## Tunable parameter surface
`CoreRules` and `TowerStats` are the primary tuning points:

- `max_towers`
- `base_enemy_hp`, `enemy_hp_growth_per_wave`
- `base_enemy_speed`, `enemy_speed_growth_per_wave`
- `base_reward`
- `damage`, `fire_rate_per_second`, `range_px`

These defaults intentionally match the current prototype assumptions (single-lane pressure, fixed placement cap, deterministic wave scaling).

## Example balancing edits
- Make early game easier:
  - Reduce `base_enemy_hp` from `100` to `80`.
- Increase pacing in late waves:
  - Increase `enemy_speed_growth_per_wave` from `0.06` to `0.08`.
- Encourage anti-spam cadence:
  - Lower `fire_rate_per_second` or increase thermal pressure in `thermal_reference.py`.

## Validation
- Unit tests in `simulation/test_basic_mechanics.py` lock in behavior for placement cap, wave scaling, movement, damage, overheat gate, and reward scaling.
- Existing thermal tests remain source-of-truth for overheat transitions.

## Change log
- **v0.001:** Initial mechanics formalization plan centered on small pure simulation helpers.
