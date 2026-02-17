# BURZEN TD v0.00.4.0 Scene Tree + UI Mockup Draft

This draft maps the prototype expansion into a Godot-ready scene and scripting contract. It is designed to be used directly from `android/BurzenTD/scenes/td_v0_00_4_mockup.tscn` and `android/BurzenTD/scripts/td_v0_00_4_mockup.gd`.

## 1) Scene Tree (Godot)

```text
TDPrototypeV004 (Control)
├─ WorldLayer (ColorRect)
│  └─ RangeOverlay (Control)
├─ TopBar (PanelContainer)
│  └─ TopBarMargin (MarginContainer)
│     └─ TopBarHBox (HBoxContainer)
│        ├─ VersionLabel
│        ├─ WaveLabel
│        ├─ MobBudgetLabel
│        └─ SettingsButton
├─ RightPanel (PanelContainer)
│  └─ RightMargin (MarginContainer)
│     └─ RightVBox (VBoxContainer)
│        ├─ TowerMenuHeader
│        ├─ TowerMenu (Tree)
│        ├─ SnapToGridCheck
│        └─ StatsPanel
│           └─ StatsMargin
│              └─ StatsVBox
│                 ├─ TowerDetailLabel
│                 ├─ MobOverlayLabel
│                 └─ SafetyStateLabel
├─ BottomPanel (PanelContainer)
│  └─ BottomMargin (MarginContainer)
│     └─ BottomHBox (HBoxContainer)
│        ├─ PlacementHintLabel
│        ├─ SimulateWaveButton
│        └─ ClearPlacementsButton
└─ SettingsPopup (PopupPanel)
   └─ SettingsMargin (MarginContainer)
      └─ SettingsVBox (VBoxContainer)
         ├─ GeneralSection
         ├─ TowerSection
         ├─ WaveSection
         └─ AdvancedSection
```

## 2) UI Mockup Behavior Map

### Tower Menu (collapsible categories)
- Categories: **Geometric**, **Elemental**, **Keystone**.
- Tower rows contain label/icon glyph and DPS column.
- Selection updates live panel with cooldown, range, and special effect summary.

### Placement & Safety Checks
- World clicks place the currently selected tower.
- Optional snap-to-grid (`GRID_SIZE = 48`).
- Invalid placements auto-collapse to safe state when:
  - Tower overlap violates local spacing.
  - Placement is too close to path routing lane (`PATH_SAFE_DISTANCE = 72`).
- Safety status shown in `SafetyStateLabel` as NESOROX-like state projection feedback.

### Mob Overlay Mock
- Simulated wave button updates summary line for tank/runner/affinity composition.
- Placement count modifies previewed HP/armor/speed envelope to communicate scaling.

## 3) Tower Dataset Included

`td_v0_00_4_mockup.gd` includes all eight requested towers:
- Geometric: `△`, `▢`, `▭`.
- Elemental: `火`, `水`, `土`, `风`.
- Keystone: `Ж`.

Each entry has prototype fields:
- `id`, `label`, `dps`, `range`, `cooldown`, `special`.

## 4) Scripting Integration Contract

### Suggested signals to add in next increment
- `tower_selected(tower_id: String)`
- `tower_placed(tower_id: String, at: Vector2)`
- `placement_reverted(reason: String)`
- `wave_simulation_requested(seed: int)`

### Suggested module ownership
- `tower.gd`: attack runtime + effect application (`burn`, `slow`, `armor break`, `knockback`).
- `mob.gd`: defense type matrix + state stack (`shielded`, `flying`, `regen`, affinity).
- `state_manager.gd`: deterministic candidate->safe-state projection.
- `interface.gd`: tooltip depth, menu collapse/expand, and settings foldout persistence.

## 5) GDScript ↔ GDNative Haskell Bridge Notes

For a GDNative Haskell binding path, keep this UI scene as the presentation layer and expose deterministic hooks:
- `request_validate_placement(candidate: PlacementCandidate) -> PlacementResult`
- `request_wave_plan(wave_index: int, difficulty: float) -> WavePlan`
- `request_target_priority(mob_state: MobState, tower_state: TowerState) -> float`

This keeps logic side-effect free and allows SPOC/NESOROX style verification in Haskell while Godot renders and routes events.
