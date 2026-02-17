# BURZEN TD v0.01.0 Folding Scaffolding

This scaffold introduces deterministic module boundaries required by the protein-residue feature set.

## Codex Runtime Modules

- `AffinityEngine` (`simulation/folding_engine.py`): residue-pair affinity lookup + environmental modifiers.
- `FoldingSolver` (`simulation/folding_engine.py`): deterministic neighbor interpretation and energy accounting.
- `TissueEmergence` (`simulation/folding_engine.py`): maps stabilized bond graph into secondary/tertiary motifs.
- `EducationalOverlay` (`simulation/folding_engine.py`): generates explanatory player-facing motif text.

## Data Contract

- `FoldRecordV1` dataclass in `simulation/folding_engine.py`
- JSON schema in `simulation/schema/fold_record_v1.schema.json`

## Godot Thin Client

- `android/BurzenTD/scripts/folding_bridge.gd`: receives deterministic graph/energy deltas from Codex and emits update signals.
- `android/BurzenTD/shaders/folding_pulse.gdshader`: sample fold animation and heat/misfold blending.

## Formal + Regression Layers

- Haskell reference: `simulation/haskell/BURZEN_Folding_v0_01_0.hs`
- Python regression: `simulation/test_folding_engine.py`
