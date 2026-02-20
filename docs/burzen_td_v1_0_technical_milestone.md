# BURZEN TD — Version 1.0 Technical Milestone

## Version
- Document version: **CODEX v1.0-draft.1**
- Payload baseline: **XDX1.<payload>.<checksum8>**

## Purpose & justification
This document converts the whiteboard plan into an implementation-grade contract for:
1. mathematically formalized 8 core towers,
2. precise energy/heat equations,
3. GitHub project board workflow columns, and
4. a Version 1.0 delivery milestone.

The design preserves CODEX boundary discipline: only Eigenstate summaries are exported across layer boundaries.

---

## 1) Layer boundaries and data contracts

### 1.1 Layer ownership
- **BURZEN core (engine):** full network state, local interactions, heat diffusion, spectral analysis.
- **WASMUTABLE orchestrator:** deterministic tick scheduling, seeded mutation application, payload framing.
- **Game surface:** finite player-facing state (UI, loadout, progression) derived only from Eigenstates.

### 1.2 Export prohibition
Raw per-cell or per-edge mutable state MUST NOT leave BURZEN. Public payloads must be aggregate/spectral only.

### 1.3 Payload frame
All cross-layer payloads use:

`XDX1.<payload_b64url>.<checksum8hex>`

- `XDX1`: protocol/version prefix.
- `payload_b64url`: canonical JSON bytes encoded in base64url.
- `checksum8hex`: first 8 hex chars of `SHA-256(canonical_json_bytes)`.

Determinism requirement: identical `(seed, map_id, tick, inputs)` produces identical payload bytes and checksum.

---

## 2) State model and symbols

Let the live tower graph be `G=(V,E)` at tick `t`.

For tower `i \in V`:
- `E_i(t)`: stored energy.
- `H_i(t)`: stored heat.
- `u_i(t)`: activity/control variable in `[0,1]`.
- `\theta_i`: heat tolerance threshold.
- `\rho_i`: dissipation coefficient.
- `\eta_i`: base conversion efficiency.
- `\mathcal{N}(i)`: neighbors from tower links/fields.

Global constants:
- `\Delta t`: simulation step.
- `\kappa_{ij}`: directed coupling weight from `j` to `i`.
- `\alpha`: heat-to-efficiency penalty slope.
- `\beta`: thermal instability amplification factor.

Clamps:
- `\mathrm{clip}_{[a,b]}(x)=\min(b,\max(a,x))`.

---

## 3) Core equations (energy + heat)

### 3.1 Effective efficiency under heat load
\[
\eta_i^{\mathrm{eff}}(t)=\eta_i \cdot \exp\left(-\alpha\,\max\left(0,\frac{H_i(t)-\theta_i}{\theta_i}\right)\right)
\]

### 3.2 Tower energy update
\[
E_i(t+1)=\mathrm{clip}_{[0,E_i^{\max}]}
\left(
E_i(t)
+\Delta t\left(P_i^{\mathrm{gen}}(t)-P_i^{\mathrm{use}}(t)+\sum_{j\in\mathcal{N}(i)}\kappa_{ij}(E_j-E_i)\right)
\right)
\]

Where:
- `P_i^{gen}(t)=u_i(t)\,g_i\,\eta_i^{eff}(t)`.
- `P_i^{use}(t)=u_i(t)\,c_i + s_i(t)` (`s_i` is burst/skill spend).

### 3.3 Tower heat update
\[
H_i(t+1)=\mathrm{clip}_{[0,H_i^{\max}]}
\left(
H_i(t)+\Delta t\left(
\gamma_i P_i^{\mathrm{use}}(t)
+\sum_{j\in\mathcal{N}(i)}d_{ij}(H_j-H_i)
-\rho_i H_i
\right)
\right)
\]

- `\gamma_i`: energy-to-heat conversion factor.
- `d_{ij}`: thermal diffusion edge weight.

### 3.4 Instability and chain reaction trigger
Define overflow ratio:
\[
\Omega_i(t)=\max\left(0,\frac{H_i(t)-\theta_i}{\theta_i}\right)
\]

Instability hazard:
\[
\lambda_i(t)=\beta\,\Omega_i(t)^2
\]

A deterministic chain event occurs when `\lambda_i(t)` exceeds tier threshold `\Lambda_{tier}` for `\tau` consecutive ticks.

### 3.5 System Eigenstate export
Let `L_E=D_K-K` be weighted Laplacian of the energy coupling matrix `K=[\kappa_{ij}]`.

Export principal spectral summary:
- `\lambda_1 \le \lambda_2 \le ...`: smallest non-trivial eigenvalues,
- `v_2`: Fiedler vector for network partition stress,
- thermal scalar moments `(\mu_H, \sigma_H, q_{95}(H))`.

Exported Eigenstate packet:
```json
{
  "schema": "eigenstate_delta_v1",
  "tick": 1234,
  "energy": {
    "lambda2": 0.183,
    "lambda3": 0.412,
    "fiedler_sign_balance": 0.51
  },
  "heat": {
    "mean": 11.2,
    "std": 3.8,
    "q95": 18.9,
    "instability_count": 2
  }
}
```

---

## 4) Formalized 8 core towers

All towers use the common equations above; each defines parameter tuples and transfer operators.

For each tower `T_k`, parameter vector:
`\Pi_k=(g_i,c_i,\eta_i,\gamma_i,\rho_i,\theta_i,\kappa\text{-profile},d\text{-profile})`.

### 4.1 Kinetic Tower (K)
- Role: direct impulse damage with low conversion complexity.
- Transfer: `D_K \propto u_i\,E_i\,\eta_i^{eff}`.
- Modifier: gains `+m_K` against high-velocity mobs.

### 4.2 Thermal Tower (T)
- Role: damage-over-time via heat pressure.
- Transfer: injects `\Delta H_{mob}=a_T u_i E_i` and local `+\delta d_{ij}`.
- Risk: high `\gamma_i`, high throughput, faster overflow.

### 4.3 Energy Tower (E)
- Role: net generator and stabilizer.
- Transfer: raises neighbor generation term with
`g_j \leftarrow g_j(1+b_E w_{ij})`.
- Low direct damage, strongest graph support value.

### 4.4 Reaction Tower (R)
- Role: conditional conversion and detonation logic.
- Transfer: if target status set `S` satisfied, output
`D_R \leftarrow D_R(1+r_S)` and adds burst spend `s_i(t)`.
- Heat spikes are sparse but intense.

### 4.5 Pulse Tower (P)
- Role: periodic AoE pulses.
- Transfer: `u_i(t)=\mathbb{1}[t \bmod \tau_P=0]` for pulse windows.
- Strong synchronization effects on network resonance.

### 4.6 Field Tower (F)
- Role: continuous area topology manipulation.
- Transfer: modifies neighbor couplings:
`\kappa_{ij}\leftarrow\kappa_{ij}(1+f_F \phi_{ij})` within radius.
- Medium damage, high control utility.

### 4.7 Conversion Tower (C)
- Role: damage-type transmutation and resistance inversion.
- Transfer matrix on incoming channels:
`\mathbf{d}_{out}=M_C\mathbf{d}_{in}` with row-stochastic `M_C`.
- Efficiency depends on local heat gradient `|\nabla H|`.

### 4.8 Control Tower (CTL)
- Role: pathing/tempo/lockdown constraints.
- Transfer: crowd-control budget
`B_{ctl}=u_iE_i\eta_i^{eff}` allocated to slow/stun/redirect.
- Minimal raw damage, maximal curve-shaping.

### 4.9 Baseline balancing constraints
- Any 4-tower loadout must satisfy:
  - Generation adequacy: `\sum g_i \ge G_{min}(level)`.
  - Thermal stability: expected `q95(H) < \Theta_{safe}`.
  - Time-to-kill bound: `TTK_{wave} \le T_{cap}`.

---

## 5) 4-slot loadout constraint (campaign)

At level start, player chooses exactly four tower archetypes from the eight core set.

Formal constraint:
\[
\mathcal{L}_{level} \subseteq \{K,T,E,R,P,F,C,CTL\},\quad |\mathcal{L}_{level}|=4
\]

No mid-level substitution: `\mathcal{L}_{level}` immutable until level completion/failure.

UI contract must expose:
- selected 4-tower set,
- projected energy budget,
- projected heat risk indicator from pre-sim estimate.

---

## 6) GitHub project board draft columns

Recommended single board: **"BURZEN TD — v1.0 Execution"**.

Columns:
1. **Backlog (Validated)**
   - Scoped and accepted, not started.
2. **Ready (Spec Complete)**
   - Clear acceptance criteria, dependencies resolved.
3. **In Progress**
   - Active implementation.
4. **Review (Code + Design)**
   - PR open, awaiting technical/design review.
5. **Verification**
   - Determinism tests, balance checks, and QA scenario passes running.
6. **Release Candidate**
   - Merged, flagged for milestone cut.
7. **Done (Shipped)**
   - Included in tagged release with notes.

Metadata fields (suggested):
- `Layer`: Engine / Orchestrator / Gameplay / UI / Tooling.
- `Mode`: Campaign / Infinite / Custom.
- `Risk`: Low / Medium / High.
- `Determinism`: Required / N-A.
- `Milestone`: v0.5 / v0.8 / v1.0 / v2.0.

---

## 7) Version 1.0 milestone definition

### 7.1 Scope
Version 1.0 delivers a playable campaign + custom + basic infinite with deterministic payload exports.

### 7.2 Required features
1. **Campaign foundation**
   - 10 playable levels.
   - 4-slot pre-level loadout lock.
   - Progression tracking and unlock schedule.
2. **Tower system**
   - All 8 core towers implemented with shared energy/heat model.
   - At least 16 total playable variations via combinational derivatives.
3. **Custom mode**
   - Adjustable parameters (waves, geometry, energy density, heat rules, mob attributes).
   - Save/load presets.
4. **Infinite mode (basic)**
   - Random wave generation.
   - Difficulty scaling function and entropy control.
5. **Protocol reliability**
   - `XDX1` payload frame live.
   - Checksum determinism validated for replay seeds.

### 7.3 Exit criteria (must pass)
- Deterministic replay: 100/100 identical checksums for fixed seed scenario suite.
- Stability: no fatal instability loop in 30-minute stress run at target settings.
- Balance floor: each campaign level has >= 3 viable 4-tower loadouts.
- Performance: p95 frame/tick budget within platform target.
- Protocol: no raw CellState fields in exported payload audits.

### 7.4 Deferred to v2.0
- Inherited modifier stack expansion in infinite mode.
- Advanced long-horizon meta-progression.

---

## 8) Immediate implementation order
1. Lock numeric baselines `\Pi_k` for all 8 core towers.
2. Implement shared energy/heat solver + deterministic tests.
3. Complete 4-slot loadout UI with risk preview.
4. Ship fully playable Level 1 vertical slice.
5. Extend campaign progression to all 10 levels.
6. Deliver custom mode prototype tooling.
7. Add infinite basic generator/scaling.
8. Cut v1.0 release candidate with protocol audit.

## Change log
- **v1.0-draft.1:** Initial technical milestone formalization from structured whiteboard plan.
