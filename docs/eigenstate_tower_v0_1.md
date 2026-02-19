# XODEX EIGENSTATE Tower Integration v0.1

This document defines the v0.1 integration contract for BURZEN C engine, NESOROX Haskell core,
and WASMUTABLE Python orchestration.

## Boundary Rule

All cross-layer payload exchange uses CODEX `XDX1.<payload>.<checksum8>` strings carrying only Eigenstate vectors.
Raw `CellState` values are internal-only and must never cross language boundaries.

## Implemented Surfaces

- C BURZEN core: `simulation/c/burzen_engine.c` / `.h`
  - `burzen_step` emits `EigenstateDelta`
  - `burzen_export_eigenstate` emits principal vector
  - `codex_encode_eigenstate` serializes boundary payload
- Haskell NESOROX core: `simulation/haskell/NESOROX_Eigenstate_v0_1.hs`
  - `computeEigenstate :: CellState -> Eigenstate`
  - `toCodexPayload :: Eigenstate -> ByteString`
  - `c_eigenstate_compute` FFI export emits CODEX payload only
- Python WASMUTABLE orchestrator: `simulation/orchestrator.py`
  - multiprocessing jobs accept and return CODEX payloads
  - no direct C/Haskell calls
- Web CODEX functions: `docs/core/codec.js`
  - `encodeEigenstate` / `decodeEigenstate`
  - aliases `codex_encode_eigenstate` / `codex_decode_eigenstate`
- Godot membrane updates:
  - `ResidueEngine.apply_eigenstate_vector`
  - `TowerGraph.sync_from_eigenstate`

## Validation

Python tests enforce CODEX round-trip behavior in `simulation/test_codex_eigenstate.py`.
