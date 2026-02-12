# Engineering Handoff Plan (v0.00.3.x → v0.00.4+)

This plan turns current prototype priorities into execution-ready workstreams for new contributors.

## Suggested execution order

1. Stabilization & Android export reliability
2. Thermal integrity and regression expansion
3. Input/gesture robustness
4. Procedural/path readability polish *(parallel with #5)*
5. Enemy/wave progression depth *(parallel with #4)*
6. UI/UX onboarding polish
7. Extensibility and collaboration infrastructure

## Workstreams

### 1) Stabilization & Android Export Reliability

**Goal:** deterministic, fast APK export and stable installs on Android 13–15.

**Definition of done:**
- Build completes in under 2 minutes on a clean environment.
- APK installs and launches across a small tested device matrix.
- Portrait orientation is locked and stable.
- Debug overlay includes seed, wave, FPS, heat state.

### 2) Thermal Integrity & Regression Expansion

**Goal:** harden thermal formula implementation and protect against regressions.

**Definition of done:**
- Test sweep documented with pass/fail history.
- Additional thermal edge-case tests exist (8+ new cases).
- Heat visuals map intuitively from cool → overheat.

### 3) Input & Gesture Robustness

**Goal:** improve touch confidence and reduce accidental actions.

**Definition of done:**
- Placement ghost clearly indicates valid/invalid tiles.
- Retry gesture works reliably (>95% in manual QA runs).
- Long press behavior and haptics are consistent across DPI classes.

### 4) Procedural Generation & Path Readability

**Goal:** make seeded runs deterministic and visually parseable.

**Definition of done:**
- Same seed reproduces the same geometry/pathing.
- Overlay cycle (thermal/vector/WASMUTABLE) remains stable.
- Corridor constraints prevent impossible routes.

### 5) Enemy & Wave Progression Depth

**Goal:** increase variety while keeping thermal gameplay central.

**Definition of done:**
- Runner/swarm/tank distinctions are both visual and mechanical.
- Wave scaling feels fair with rising pressure.
- Environmental trigger tile stubs are available for v0.00.4.

### 6) UI/UX Onboarding

**Goal:** help new players understand loop quickly without full tutorial mode.

**Definition of done:**
- Settings are functional (not placeholders).
- Persistence survives restart.
- Win/lose flows have clear next actions and score summary.

### 7) Extensibility & Collaboration

**Goal:** improve contributor throughput and consistency.

**Definition of done:**
- Contributing standards and issue templates exist.
- Extension pathways for towers/enemies/WASMUTABLE are documented.
- New contributors can execute a small feature with low friction.

## Handoff artifacts checklist

For each completed stream, include:

- Short implementation summary
- Test evidence (`./scripts/run_tests.sh` output)
- Device/platform validation notes
- Docs updates and follow-up TODOs
