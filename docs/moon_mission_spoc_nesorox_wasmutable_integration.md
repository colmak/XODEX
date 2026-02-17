# SPOC/NESOROX/WASMUTABLE Integration for XODEX Moon Mission Simulation

## Status
- Draft architecture proposal for internal technical leadership.
- Scope: adapt existing SPOC, NESOROX, and WASMUTABLE concepts into the current XODEX repository structure.

## 1) XODEX as a simulation scaffold
The current repository can be treated as a simulation framework baseline:

- `simulation/` is the integration point for mission dynamics, state machines, and telemetry transforms.
- `scripts/` can host scenario runners, validation harnesses, and reproducibility automation.
- The existing lightweight structure supports incremental hardening toward constrained mission simulation workflows.

## 2) SPOC constraints as runtime state guards
Model each simulation step as a constrained state transition:

```text
next_state = f(current_state, control_delta, constraint_set)
```

Operational flow:

1. Generate candidate control deltas (manual, scripted, or AI-assisted).
2. Evaluate candidates against SPOC constraint sets.
3. Project with NESOROX into an approved state or collapse to a safe baseline.
4. Persist telemetry and decision traces.

Reference pseudo-flow:

```python
for candidate in simulation_step_candidates:
    projection = nesorox.project(current_state, candidate, constraints)
    if projection.is_valid:
        current_state = projection.state
    else:
        current_state = nesorox.collapse(current_state, projection.violation)
    log_projection(projection)
```

## 3) Constraint library embedding
Constraint packs (for example `ORBINS-*`, `DOCK-*`, `REENTRY-*`) should be represented as versioned JSON artifacts and compiled/loaded into evaluators.

Recommended lifecycle:

1. Load constraint package.
2. Deserialize into typed evaluators.
3. Bind evaluator inputs to simulation telemetry/state.
4. Execute hard/soft violation handling policies.

```python
constraints = load_constraints("orbins_constraints.json")
violations = evaluate_constraints(state, constraints)
for violation in violations:
    if violation.severity == "hard":
        state = nesorox.collapse(state, violation)
        break
```

## 4) WASMUTABLE sandboxing pattern
Use WASMUTABLE modules to isolate rule execution from core simulation state mutation:

- Constraint/rule logic executes in WebAssembly sandboxes.
- Main simulation core receives validated outputs only.
- Faulting or runaway rule logic cannot directly corrupt host simulation memory.

Conceptual interface:

```javascript
const engine = loadWasm("orbins_engine.wasm")
const result = engine.evaluate(state_vector)
applyValidatedResult(result)
```

## 5) AI assistance boundaries
AI-generated proposals (e.g., scenario controls, timeline edits, state deltas) are advisory only.

Mandatory gate:

```text
AI proposal -> SPOC filter -> NESOROX projection/collapse -> WASMUTABLE execution -> immutable log
```

Design principle: AI never bypasses invariants or writes directly into mission state.

## 6) Moon mission scenario decomposition
Organize scenario development by mission phase:

- **Trans-lunar transfer:** ORBINS extension with TLI budgets and insertion tolerances.
- **Lunar orbit/rendezvous:** docking constraints for Gateway/LLO approach envelopes.
- **Surface operations:** descent and hazard-avoidance proposals evaluated as constrained transitions.

Each phase should expose explicit inputs, outputs, hard limits, and collapse behavior.

## 7) Traceability and audit
Every projection/collapse event should emit structured logs suitable for Git tracking:

- Constraint package/version used.
- Input state hash + candidate delta.
- Projection outcome and violated invariants.
- Collapse baseline chosen (if any).

This creates deterministic provenance for engineering review and external collaboration.

## 8) Physics engine validation strategy
Treat external physics engines as authoritative signal sources but still subject outputs to invariant checks:

- Wrap engine outputs via evaluator adapters.
- Validate transitions through SPOC/NESOROX gate.
- Reject or collapse transitions that violate hard mission constraints.

## Proposed repository implementation map
- `simulation/mission_core.py`: state transition host loop.
- `simulation/constraints/`: JSON constraint packs + schemas.
- `simulation/nesorox/`: projection/collapse adapters.
- `simulation/wasmutable/`: wasm loaders and host bindings.
- `simulation/logs/`: run output artifacts (optional `.gitkeep`, typically ignored in VCS).
- `scripts/run_moon_scenario.sh`: reproducible scenario entry point.
- `.gitignore`: enforce exclusion of generated simulation logs/binaries and local keystore material.

## Initial milestones
1. Build minimal state vector + transition loop in `simulation/`.
2. Add one ORBINS constraint pack and hard-violation collapse path.
3. Run deterministic scenario replay with logged projections.
4. Add wasm-isolated evaluator for one constraint subset.
5. Validate against an external propagator reference dataset.

## Outcome
This integration path allows XODEX to evolve from a generic simulation scaffold into a constrained, auditable mission simulation framework where:

- constraints are executable,
- AI remains bounded,
- safety invariants are preserved,
- and every state decision is traceable.
