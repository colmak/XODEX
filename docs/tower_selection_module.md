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
