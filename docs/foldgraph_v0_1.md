# FoldGraph v0.1 (BURZEN TD v0.00.5.0)

Phase 1 introduces deterministic residue classification, pair affinity, and a live tower bond graph.

## Tower extension

Each tower definition now includes:

- `residue_class`: one of `nonpolar`, `polar_uncharged`, `positively_charged`, `negatively_charged`, `special`
- `modifiers`: optional list, e.g. `hydrophobic_core`, `turn_preference`

## AffinityTable

- Serializable matrix keyed by residue-class pair.
- Supports positive (attractive) and negative (repulsive) values.
- Runtime modifiers:
  - thermal attenuation
  - distance falloff
  - orientation gain (for optional diagonal mode)
- Hot-swappable through WASMUTABLE patch payloads.

## FoldGraph v0.1 record

```yaml
foldgraph_version: 0.1
towers: [{id, tower_id, residue_class, pos_x, pos_y, thermal_state, modifiers}]
bonds: [{from_id, to_id, affinity_type, strength, contrib, timestamp}]
graph_stats: {total_bonds, avg_stability, misfold_risk}
tick_counter: 0
```

Round-trip serialization is implemented in `simulation/tower_graph.py` and validated in `simulation/test_tower_graph.py`.
