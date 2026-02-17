# BURZEN Tower Defense Prototype (XODEX)

Open-source Android + simulation prototype for **BURZEN TD**, currently tracked as:

- **Runtime baseline:** `v0.00.3.0` (playable loop, procedural level routing, thermal tower mechanics)
- **Design/scene expansion draft:** `v0.00.4.0` (mockup scene tree + UI wiring + expanded tower taxonomy scaffolding)

This repository intentionally keeps **prototype runtime stability** and **forward design experiments** side by side so contributors can iterate without blocking core gameplay.

---

## 1) Project Status and Versioning

### Current stable gameplay layer (`v0.00.3.0`)
Implemented in the primary Godot scenes/scripts and simulation modules:

- Touch-first placement loop
- Thermal overheat/recovery tower state behavior
- Procedural wave/path progression shell
- Win/loss state transitions and menu flow
- Deterministic simulation test coverage for baseline mechanics

### Forward prototype layer (`v0.00.4.0` draft)
The repository includes a **Godot UI/scene mockup** for the planned expansion:

- Expanded tower catalog UI (geometric + elemental + keystone classes)
- Placement safety concept (NESOROX-style safe-state rollback checks)
- Mock mob stats overlays and settings panel structure
- Integration notes for future GDScript and optional GDNative/Haskell bridge

> Important: `v0.00.4.0` assets are currently **prototype scaffolding**, not yet full gameplay parity with the stable `v0.00.3.0` runtime loop.

### Versioning policy
BURZEN TD uses incremental pre-1.0 semantics:

- `v0.00.x.y` where:
  - `x` = feature increment (prototype scope expansion)
  - `y` = patch/prototype refinement
- Stable gameplay claims are made only when reflected in both:
  1. runtime scenes/scripts
  2. automated simulation/regression checks

---

## 2) Implemented Capabilities (Today)

### Gameplay/runtime capabilities
- Main menu and level routing shell
- Procedural path variants and level progression
- Wave spawning and enemy traversal
- Life tracking, score accumulation, retry/next/menu transitions
- Tap placement, spacing/path safety constraints, long-press highlight behavior

### Simulation capabilities
- Thermal pressure and overheat state transitions
- Basic wave scaling and mechanics checks
- Deterministic checks suitable for CI-style gating

### Expansion-ready capabilities
- Additional tower taxonomy and metadata schema
- UI container structure for collapsible tower/settings panels
- Mock event points for safety-state projection and wave composition overlays

---

## 3) Architecture at a Glance

- **Godot app root:** `android/BurzenTD/`
- **Runtime scenes:** `android/BurzenTD/scenes/`
- **Runtime scripts:** `android/BurzenTD/scripts/`
- **Python simulation tests:** `simulation/`
- **Prototype formal experiments (Haskell):** `simulation/haskell/`
- **Product/engineering docs:** `docs/`

Design principle: keep rendering/input logic in Godot while preserving deterministic mechanics models in simulation layers for rapid verification.

---

## 4) Build & Validation

### Build Android APK
```bash
./scripts/build_apk.sh
```

Prerequisites:
1. Godot 4 with Android export templates
2. Android signing/export settings in `android/BurzenTD/export_presets.cfg`

### Run full local validation gate
```bash
./scripts/run_tests.sh
```

This executes simulation tests plus release metadata/export dry-run checks.

---

## 5) Controls (Current Runtime)

### Menu
- **Play:** starts a procedural run from Level 1
- **Settings:** placeholder/UI status behavior
- **Quit:** exits app

### Gameplay
- **Tap on empty space:** place tower (up to configured max)
- **Long-press tower:** trigger heat highlight pulse
- **Two-finger tap:** retry current level seed

---

## 6) Cross-Compatible Open-Source Implementation Notes

BURZEN TD is prototype-focused, but intentionally aligns with widely used open-source game/sim stacks for easier contributor portability.

### Engine and scripting compatibility
- **Godot 4.x (MIT):** primary runtime and UI composition model
  - SceneTree + signal architecture maps directly to BURZEN tower/mob/event hooks
  - GDScript-first approach keeps iteration speed high for prototype balancing
- **GDNative/GDExtension ecosystem:** supports extending hot paths in native languages
  - BURZEN’s deterministic state hooks can be exported to native modules without rewriting scene layouts

### Deterministic simulation and balancing
- **Python test ecosystem (CPython + unittest/pytest-compatible workflows):**
  - Simple reproducible combat/thermal regressions
  - Easy CI integration for balancing assertions
- **Haskell prototype path (GHC/runghc):**
  - Strong fit for pure-state transition experiments (SPOC/NESOROX-style modeling)
  - Useful for proving candidate placement/wave policies before porting to GDScript

### Data-oriented compatibility approach
BURZEN tower/mob specs are represented as serializable dictionary-like structures in prototype scripts. This makes migration straightforward to:

- JSON/YAML balancing pipelines
- ECS-style component models
- External wave/tower tuning tools

### Open-source projects/pattern families BURZEN can interoperate with
(Reference families for implementation style; not direct bundled dependencies.)

- **Godot demo/project patterns** for TD/pathing UI composition
- **OpenRA-style deterministic RTS/TD simulation thinking** (state-first, deterministic outcomes)
- **Mindustry-style data-driven unit/tower tuning workflows**
- **Luanti/Minetest modding philosophy** for rapid gameplay extension through scriptable primitives

These references are included to encourage contributors to adopt familiar open-source design heuristics while keeping BURZEN’s own architecture and naming stable.

---

## 7) Key Design & Engineering Documents

- Extensibility guide: `docs/extensibility_guide.md`
- Engineering handoff plan: `docs/engineering_handoff_plan_v003.md`
- BURZEN engine formalization: `docs/burzen_engine_formalization.md`
- Tower selection module (heat-aware residue placement): `docs/tower_selection_module.md`
- Moon-mission SPOC/NESOROX/WASMUTABLE integration: `docs/moon_mission_spoc_nesorox_wasmutable_integration.md`
- v0.00.4.0 scene tree/UI mockup notes: `docs/td_v0_00_4_scene_tree_and_ui_mockup.md`

---

## 8) Roadmap Snapshot

- **v0.00.4.x:** expanded tower classes + richer overlays + safer placement/state checks
- **v0.00.5.x:** adaptive wave composition and stronger mob defense typing
- **v0.01.0:** deeper WASMUTABLE-style rule shifts and specialization systems

---

## 9) Repository Hygiene

- Simulation logs go under `simulation/logs/` (ignored except marker files)
- Signing keys (`*.jks`, `*.keystore`) must remain out of source control
- APK/AAB artifacts under `builds/<version>/` remain ignored unless explicitly staged for release flow

---

## 10) First Launch Instructions – zero errors expected

For the `v0.00.5.0` milestone, the Godot prototype scripts are now updated for strict typed parsing expectations.

1. `git clone https://github.com/nesorox/XODEX.git`
2. Open `android/BurzenTD/project.godot` in **Godot 4.6.1.stable**
3. Keep **Treat warnings as errors** enabled
4. Press **Play** (or reload project)

Expected result: no parse errors and no Variant-inference warning output on first launch.

Protein Phase 1 scaffolding is included in:
- `android/BurzenTD/scripts/ResidueEngine.gd`
- `android/BurzenTD/scripts/AffinityTable.gd`
- `android/BurzenTD/scripts/TowerGraph.gd`
- `android/BurzenTD/scripts/td_v0_00_4_mockup.gd` (typed integration + bond-renderer stub)

## 11) Play the Demo Campaign in 2 clicks

1. Open `android/BurzenTD/project.godot` in Godot 4.6.1.
2. Press **Play** then tap **Demo Campaign** and choose any of the five tutorial levels.

Campaign assets:
- Level-select UI: `android/BurzenTD/ui/campaign_select.tscn`
- Demo levels: `android/BurzenTD/levels/demo/`
- Tower definitions: `android/BurzenTD/data/towers/tower_definitions.json`
