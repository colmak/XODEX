# Tower Schema v1 (Canonical)

`tower_schema_v1` is the canonical catalog contract for tower definitions in BurzenTD.

## Root contract

- `tower_schema`: must be `tower_schema_v1`.
- `version`: content version of the catalog.
- `compatibility_layer.legacy_key_map`: explicit mapping from legacy flat keys to structured paths.
- `towers[]`: array of tower definitions.

## Legacy compatibility mapping

The loader maps old keys to `base_stats` automatically:

- `heat_gen_rate` -> `base_stats.heat.generation_rate`
- `build_cost` -> `base_stats.economy.build_cost`
- `heat_tolerance` -> `base_stats.heat.tolerance_label`
- `heat_tolerance_value` -> `base_stats.heat.tolerance_value`
- `preferred_bind` -> `base_stats.binding.preferred_partner`
- `folding_role` -> `base_stats.combat.folding_role`

## Tower object

Each tower must include:

- Identity: `tower_id`, localized display names, `scene_path`
- Presentation: `visuals.shape`, `visuals.primary_color`, optional `visuals.icon_path`
- Gameplay:
  - `base_stats.economy.build_cost`
  - `base_stats.heat.generation_rate`, `tolerance_label`, `tolerance_value`
  - `base_stats.binding.residue_class`, `preferred_partner`, `affinity_modifiers`
  - `base_stats.combat.folding_role`, `radius`
- Synthesis metadata: `synthesis.synthesis_class`, `synthesis.recipe_tags`

This file is the canonical source for schema expectations; runtime compatibility is implemented in `TowerSchema` loader.
