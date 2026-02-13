# XODEX.PROTEIN_TOWER — BURZEN TD v0.00.3.0(N)

## System classification
- **Tower type:** Adaptive Structural Resolver
- **Footprint:** 2×2 tiles
- **Domain role:** Geometry prediction under energy constraints
- **Version:** v0.00.3.0(N)

The Protein Tower is modeled as constrained function approximation over local creep geometry rather than direct linear DPS.

## Mathematical mapping
- Protein-folding analog: `s -> x*`
- TD reinterpretation: `Phi_t -> Psi*`
  - `Phi_t`: local creep distribution tensor
  - `Psi*`: optimized disruption field minimizing creep escape energy

## Runtime tick model
Each tick the tower:
1. Samples a local 8×8 neighborhood.
2. Encodes pairwise creep relationships in mutable state `Theta`.
3. Estimates an energy manifold.
4. Applies a perturbation field.

Effects include path bending, speed modulation, localized DoT, and heat redistribution.

## Emergent damage model
Damage derives from field instability:

`D = alpha * Laplacian(Psi)`

Where high-density swarm geometry increases local curvature and therefore distributed damage.

## Mutable update rule
Tower parameters adapt during each wave:

`Theta_(t+1) = Theta_t + eta * Delta`

- `eta`: adaptation rate (wave-dependent, mildly decaying)
- `Delta`: error between predicted and realized disruption outcome

Heat accumulation can trigger temporary field collapse when instability exceeds threshold.

## Wave scaling
- Damage scale: `alpha_w = alpha_0 * (1 + 0.08w)`
- Adaptation rate decreases per wave and is lower-bounded.
- Heat cap scaling depends on entropy and map pressure constraints.

## Constraints and balance
- Effective radius bounded to 6–8 tiles.
- Requires dense creep presence for full value.
- Instability threshold prevents runaway dominance.
- Cannot directly dominate sparse elite pathing on short sample windows.

## Reference implementation mapping
The simulation module `simulation/protein_tower.py` implements this specification with:
- `ProteinTowerConfig` for constraints,
- `ProteinTowerState` for mutable tensor/heat state,
- `step_protein_tower(...)` for per-tick disruption, damage, adaptation, and collapse logic.
