# WASMUTABLE BURZEN TD – Muted Visual + Basic AI Tower Tutorial Spec

This specification defines a **non-neon, muted Doom-like color system**, transparent overlays with explicit close controls, and a **basic Godot setup tutorial** for AI-assisted tower placement in BURZEN TD.

## 1) Muted map/color rendering targets

Use constrained luminance so gameplay remains readable without extreme saturation.

- **Base map value range (RGB)**: `0.12–0.45`
- **Accent range (RGB)**: `0.35–0.62`
- **Saturation ceiling**: `S <= 0.32` (HSV/HSL equivalent)
- **Overlay alpha range**: `0.62–0.78`
- **Critical heat never uses neon**: no channel should spike above `0.70` while another remains under `0.20`.

Heat palette (normalized 0..1):

- Cool (`h <= 0.50`): `#56666F` style gray-blue
- Stressed (`0.50 < h <= 0.85`): `#7A6B59` warm muted bronze
- Critical (`0.85 < h <= 1.00`): `#935B56` muted rust

## 2) Overlay behavior

All modal overlays should be semi-transparent and dismissible with obvious controls.

- Wave preview panel alpha: `0.78`
- Tower info panel alpha: `0.72`
- Pause panel alpha: `0.75`
- Required dismiss control: top-right `✕` close button (minimum hitbox `38x38` px, recommended `42x42`).

## 3) Expandable tower menu behavior (pre-wave clarity)

Before a wave starts:

1. Show **Selectable Towers** menu section (expand/collapse).
2. Show **Preview Towers** menu section (expand/collapse) for towers not currently unlocked.
3. Preview towers remain visible but non-placeable until unlocked.
4. Card status label text: `Visible pre-wave • unlock to place`.

This preserves strategic planning while keeping placement validation strict.

## 4) Numeric thermal context using polygonal systems

For heat measurement tied to polygonal map geometry:

- Sample radius around tower center: `R = 1.8 tiles`
- Angular samples: `N = 6` (hex) or `N = 8` (octagon)
- Thermal ring weighting:
  - Inner ring `0.0R..0.6R`: weight `0.50`
  - Mid ring `0.6R..1.2R`: weight `0.35`
  - Outer ring `1.2R..1.8R`: weight `0.15`
- Heat score:

`H_local = Σ(sample_i * weight_ring_i) / Σ(weight_ring_i)`

- Dynamic pressure scalar:

`P = clamp(0.65 + 0.9*H_local + 0.25*enemy_density - 0.20*cooling_links, 0.0, 1.8)`

Use `P` to prioritize AI auto-play tower choices.

## 5) AI Auto Tower (basic setup) for Godot

For a basic tutorial implementation:

1. Build candidate list from currently selectable towers.
2. Compute each tower score:
   - `score = dps_norm*0.40 + range_norm*0.20 + utility_norm*0.15 + heat_tolerance*0.25 - projected_heat_delta*0.30`
3. If `P > 1.0`, increase heat tolerance term to `0.40` and penalty to `0.45`.
4. Pick highest score among valid placements.
5. If no valid placements, defer and keep preview visible.

### Suggested tutorial steps (Godot)

- Add a `TowerSelectionPanel` with two collapsible sections.
- Render locked towers with reduced opacity (`~0.56`) but keep icons/text visible.
- Hook `tower_card_pressed` only for selectable towers.
- Add `✕` close buttons for Wave Preview, Tower Info, and Pause modal panels.
- Keep map + UI in muted tones for readability under thermal stress.

## 6) WASMUTABLE implementation note

The values above are **engine-agnostic numeric targets**. They can be mirrored into:

- Godot runtime GDScript constants,
- Python simulation tests,
- Haskell thermal reference modules.

The important requirement is consistency of thresholds and scoring behavior, not a single rigid renderer implementation.
