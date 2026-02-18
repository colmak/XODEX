# Tower Recipe Book v1 (Canonical)

Synthesis mode is **active tower transformation** (not passive graph bonding).

## Runtime control flow

1. Player taps a crowded cell containing two nearby towers.
2. System checks `tower_recipe_book_v1.json` for matching ingredients and range.
3. UI emits a partner preview (`left + right -> result`).
4. Player confirms (Place button) or cancels (Sell button).
5. On confirm, `tower_synthesized` is emitted and source towers are replaced by result tower.

## Recipe data file

Path: `android/BurzenTD/data/synthesis/tower_recipe_book_v1.json`

Fields:

- `version`
- `synthesis_mode` (`active_transformation`)
- `recipes[]` where each recipe contains:
  - `recipe_id`
  - `ingredients` (2 tower IDs)
  - `result_tower_id`
  - `max_distance_cells`
  - `heat_credit_delta`
  - `summary`

This recipe book is the canonical balancing surface for synthesis behavior.
