# Tower Selection Module (v0.00.5.0)

Choose your residues wisely — every placement seeds a living protein fold. Heat score determines long-term stability.

## Overview

The Tower Selection Module adds a heat-aware, residue-informed placement workflow that bridges gameplay and protein biophysics:
- heat is tracked as thermal agitation pressure on each tower,
- tower cards disclose tolerance, generation rate, binding preference, and folding role,
- previews estimate projected heat delta before placement,
- smart suggestions help stabilize partially formed fold graphs under pressure.

See also:
- [Extensibility Guide](./extensibility_guide.md#tower-selection-module-v00050)
- [BURZEN Engine Formalization](./burzen_engine_formalization.md#tower-selection-module-v00050)

## Tower Catalog (Residue + Heat Taxonomy)

| Tower Type | Residue Class | Heat Tolerance | Heat Gen Rate | Preferred Bind | Folding Role | Educational Note |
|---|---|---:|---:|---|---|---|
| Triangle | nonpolar | High | 0.90 | nonpolar | Hydrophobic core seed | Like leucine zipper packing; likes compact neighborhoods. |
| Square | nonpolar | High | 0.85 | nonpolar | Core extension | Nonpolar clustering reduces solvent exposure. |
| Hexagon | nonpolar | High | 0.95 | nonpolar | Dense shell anchor | High packing supports fold nucleus growth. |
| Water | polar_uncharged | Medium | 0.60 | polar_uncharged | Surface stabilizer | Polar side-chains assist solvent-facing loops. |
| Oxygen | polar_uncharged | Medium | 0.65 | polar_uncharged | Cooling bridge | Polar edges can aid local heat dissipation. |
| Fire | positively_charged | Medium | 1.10 | negatively_charged | Allosteric trigger | Ionic pairing can be strong but heat-sensitive. |
| Air | negatively_charged | Medium | 1.00 | positively_charged | Beta-sheet rigidity | Charge complementarity reinforces directional edges. |
| Earth | special | Medium | 0.75 | special | Turn organizer | Flexible role for turn/hinge structures. |
| Keystone | special | High | 0.55 | special | Chaperone regulator | Chaperone-like balancing under thermal stress. |
| Synthesis Hub | special | High | 0.50 | special | Domain stabilizer | Supports whole-domain heat smoothing. |

## Build Options (Player-Facing)

1. **Preset Folds**
   - Minimal Alpha-Helix Line
   - Beta-Sheet Wall
   - Allosteric Sensor Complex

2. **Free Placement Mode**
   - Ghost-bond preview of expected neighbors.
   - Projected heat delta and fold stability score before lock-in.

3. **Smart Suggest**
   - `Optimize for current heat` recommends the best residue class based on current heat ratio and tolerance map.

4. **Heat-Aware Filters**
   - Auto-prioritizes high-tolerance towers when global heat exceeds 50%.

5. **Modding Hook**
   - Drop custom JSON tower definitions in `user_towers/` with keys:
     - `residue_class`
     - `heat_tolerance`
     - `heat_gen_rate`
     - `preferred_bind`
     - `folding_role`

## Integration Notes for Coders

### Runtime scripts
- `res://scripts/ui/TowerSelectionUI.gd`
  - Provides tabs: All / By Residue Class / Heat-Tolerant / Folding Role.
  - Tracks active card and emits confirmation payloads.
- `res://scripts/HeatEngine.gd`
  - Supplies projected heat curve and misfold risk feedback.

### Data contracts
- Tower card payload fields:
  - `tower_id`, `residue_class`, `heat_tolerance`, `heat_gen_rate`, `preferred_bind`, `folding_role`, `build_cost`
- Placement confirmation includes:
  - `projected_heat_delta`

### WASMUTABLE exposure
- Keep heat sliders mapped to `LevelManager.settings["heat"]`:
  - `global_heat_multiplier`
  - `tower_heat_tolerance_boost`
  - `cooling_efficiency`
  - `visual_heat_feedback_intensity`
  - `educational_heat_tooltips`
- Hot-swapping works by forwarding updated values to `HeatEngine.set_runtime_settings(...)`.

## v0.00.6 Demo Campaign Implementation Notes

The runtime now consumes `res://data/towers/tower_definitions.json` as the canonical tower catalog for the playable demo campaign.

Implemented 8-tower set:
1. Hydrophobic Anchor (`hydrophobic_anchor`)
2. Polar Hydrator (`polar_hydrator`)
3. Cationic Defender (`cationic_defender`)
4. Anionic Repulsor (`anionic_repulsor`)
5. Proline Hinge (`proline_hinge`)
6. Alpha-Helix Pulsar (`alpha_helix_pulsar`)
7. Beta-Sheet Fortifier (`beta_sheet_fortifier`)
8. Molecular Chaperone (`molecular_chaperone`)

Integration points:
- `TowerSelectionUI.gd` loads catalog entries from JSON and exposes educational tooltips.
- `HeatEngine.gd` applies tower-specific generation/tolerance values, including chaperone cooling hooks.
- `LevelManager.gd` loads `res://levels/demo/*.json` data-driven campaign levels.
- `TutorialManager.gd` tracks step progression and completion persistence per demo level.

## v0.00.7 Mobile-First Playability Additions

- `res://ui/level_hud.tscn` is the shared touch HUD for all tower levels.
- `TowerSelectionPanel.gd` now renders large (56dp+) horizontal cards with tap-select and long-press tooltip behavior.
- `TowerPlacementController.gd` owns touch-native placement state (drag ghost preview + release-to-place + cancel paths).
- Two-finger tap remains mapped to instant level retry for rapid mobile iteration.
- Placement preview now surfaces live fold context through bond-line rendering, projected heat pressure, and stability guidance.
- Live HUD damage (`DamageTracker`) and end-level score modal (`level_complete.tscn`) complete the combat feedback loop.

### New Runtime Wiring

- `LevelScene` instantiates:
  - `LevelHUD` (top bar, bottom dock, side speed control)
  - `TowerPlacementController` (single source of truth for touch placement)
  - `LevelCompleteScreen` (modal post-wave summary)
- `DamageTracker` is autoloaded in `project.godot` and records per-tower contribution for scoring.
