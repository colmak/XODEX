"""Deterministic protein-folding gameplay model for BURZEN TD v0.01.0 scaffolding.

This module provides hot-swappable, serializable engines used by Codex runtime layers:
- AffinityEngine: residue pair affinity + environment modifiers
- FoldingSolver: deterministic graph update and energy accounting
- TissueEmergence: motif/domain extraction from stabilized bonds
- EducationalOverlay: human-readable explanations for formed motifs
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Dict, Iterable, Literal

ResidueClass = Literal["polar", "nonpolar", "charged+", "charged-", "special"]
BondType = Literal["hbond", "hydrophobic", "electrostatic", "vdw", "steric"]
ConformationState = Literal["unfolded", "partial", "native", "misfolded"]


@dataclass(frozen=True)
class EnvironmentState:
    thermal_state: float = 0.0
    ph: float = 7.0
    phosphorylation_flags: frozenset[str] = frozenset()


@dataclass(frozen=True)
class TowerResidueNode:
    id: int
    residue_class: ResidueClass
    pos: tuple[int, int]
    thermal_state: float = 0.0


@dataclass(frozen=True)
class BondRecord:
    from_id: int
    to_id: int
    type: BondType
    strength: float
    energy_contrib: float


@dataclass(frozen=True)
class DomainRecord:
    id: str
    motif_type: str
    stability: float
    function: str
    bounding_box: tuple[int, int, int, int]


@dataclass(frozen=True)
class TickResult:
    global_energy: float
    conformation_per_domain: dict[str, ConformationState]
    bonds: tuple[BondRecord, ...]
    domains: tuple[DomainRecord, ...]
    misfold_events: tuple[str, ...]


@dataclass
class FoldRecordV1:
    fold_version: int
    map_seed: int
    river_slice: list[tuple[int, int]]
    towers: list[dict]
    bonds: list[dict]
    domains: list[dict]
    global_energy: float
    conformation_history: list[float]
    misfold_events: list[str]

    @classmethod
    def from_state(
        cls,
        map_seed: int,
        river_slice: list[tuple[int, int]],
        towers: Iterable[TowerResidueNode],
        tick: TickResult,
        conformation_history: list[float],
    ) -> "FoldRecordV1":
        return cls(
            fold_version=1,
            map_seed=map_seed,
            river_slice=river_slice,
            towers=[asdict(t) for t in towers],
            bonds=[asdict(b) for b in tick.bonds],
            domains=[asdict(d) for d in tick.domains],
            global_energy=tick.global_energy,
            conformation_history=conformation_history,
            misfold_events=list(tick.misfold_events),
        )


@dataclass
class AffinityEngine:
    pair_affinity: dict[tuple[ResidueClass, ResidueClass], float]
    thermal_penalty_gain: float = 0.14
    ph_sensitivity: float = 0.05
    phosphorylation_bonus: float = 0.25

    @classmethod
    def defaults(cls) -> "AffinityEngine":
        data: dict[tuple[ResidueClass, ResidueClass], float] = {
            ("polar", "polar"): -0.8,
            ("polar", "charged+"): -1.1,
            ("polar", "charged-"): -1.1,
            ("polar", "nonpolar"): 0.4,
            ("polar", "special"): -0.2,
            ("nonpolar", "nonpolar"): -1.3,
            ("nonpolar", "charged+"): 0.8,
            ("nonpolar", "charged-"): 0.8,
            ("nonpolar", "special"): 0.2,
            ("charged+", "charged-"): -1.8,
            ("charged+", "charged+"): 1.2,
            ("charged+", "special"): -0.3,
            ("charged-", "charged-"): 1.2,
            ("charged-", "special"): -0.3,
            ("special", "special"): 0.1,
        }
        # Symmetric completion for lookup simplicity.
        for (a, b), v in list(data.items()):
            data[(b, a)] = v
        return cls(pair_affinity=data)

    def pair_energy(self, left: TowerResidueNode, right: TowerResidueNode, env: EnvironmentState) -> float:
        base = self.pair_affinity[(left.residue_class, right.residue_class)]
        thermal_penalty = env.thermal_state * self.thermal_penalty_gain
        ph_penalty = abs(env.ph - 7.0) * self.ph_sensitivity
        phosphorylation_mod = -self.phosphorylation_bonus if "stabilize" in env.phosphorylation_flags else 0.0
        return base + thermal_penalty + ph_penalty + phosphorylation_mod


@dataclass
class FoldingSolver:
    affinity: AffinityEngine = field(default_factory=AffinityEngine.defaults)
    bond_cutoff: float = -0.2
    diagonal_connectivity: bool = True

    def _neighbors(self, nodes: list[TowerResidueNode]) -> list[tuple[TowerResidueNode, TowerResidueNode]]:
        pairs: list[tuple[TowerResidueNode, TowerResidueNode]] = []
        for i, left in enumerate(nodes):
            for right in nodes[i + 1 :]:
                dx = abs(left.pos[0] - right.pos[0])
                dy = abs(left.pos[1] - right.pos[1])
                orthogonal = (dx + dy) == 1
                diagonal = self.diagonal_connectivity and dx == 1 and dy == 1
                if orthogonal or diagonal:
                    pairs.append((left, right))
        return pairs

    def _bond_type_for(self, energy: float, left: TowerResidueNode, right: TowerResidueNode) -> BondType:
        if energy > 1.0:
            return "steric"
        if {left.residue_class, right.residue_class} == {"charged+", "charged-"}:
            return "electrostatic"
        if left.residue_class == "nonpolar" and right.residue_class == "nonpolar":
            return "hydrophobic"
        if "special" in (left.residue_class, right.residue_class):
            return "vdw"
        return "hbond"

    def tick(self, nodes: list[TowerResidueNode], env: EnvironmentState) -> TickResult:
        bonds: list[BondRecord] = []
        e_bonds = 0.0
        e_hydrophobic = 0.0
        e_electrostatic = 0.0
        e_steric = 0.0
        misfold_events: list[str] = []

        for left, right in self._neighbors(nodes):
            energy = self.affinity.pair_energy(left, right, env)
            btype = self._bond_type_for(energy, left, right)
            if btype == "steric":
                e_steric += energy
            if btype == "hydrophobic":
                e_hydrophobic += energy
            if btype == "electrostatic":
                e_electrostatic += energy
            e_bonds += energy
            if energy <= self.bond_cutoff:
                bonds.append(
                    BondRecord(
                        from_id=left.id,
                        to_id=right.id,
                        type=btype,
                        strength=min(1.0, abs(energy) / 2.5),
                        energy_contrib=energy,
                    )
                )

        e_thermal_penalty = env.thermal_state * 0.2 * len(nodes)
        total = e_bonds + e_hydrophobic + e_electrostatic + e_steric + e_thermal_penalty

        motifs = TissueEmergence().extract_domains(nodes, bonds)
        conformations: dict[str, ConformationState] = {}
        for d in motifs:
            if env.thermal_state > 0.8 and d.stability < 0.65:
                conformations[d.id] = "misfolded"
                misfold_events.append(f"{d.id}: thermal instability")
            elif d.stability >= 0.75:
                conformations[d.id] = "native"
            elif d.stability >= 0.45:
                conformations[d.id] = "partial"
            else:
                conformations[d.id] = "unfolded"

        return TickResult(
            global_energy=total,
            conformation_per_domain=conformations,
            bonds=tuple(bonds),
            domains=tuple(motifs),
            misfold_events=tuple(misfold_events),
        )


@dataclass
class TissueEmergence:
    def extract_domains(self, nodes: list[TowerResidueNode], bonds: list[BondRecord]) -> list[DomainRecord]:
        by_id = {n.id: n for n in nodes}
        adjacency: dict[int, set[int]] = {n.id: set() for n in nodes}
        for b in bonds:
            adjacency[b.from_id].add(b.to_id)
            adjacency[b.to_id].add(b.from_id)

        motifs: list[DomainRecord] = []
        for node in nodes:
            degree = len(adjacency[node.id])
            if degree == 0:
                continue
            nbs = [by_id[nid] for nid in adjacency[node.id]]
            x_vals = [node.pos[0], *[n.pos[0] for n in nbs]]
            y_vals = [node.pos[1], *[n.pos[1] for n in nbs]]
            bbox = (min(x_vals), min(y_vals), max(x_vals), max(y_vals))
            width = bbox[2] - bbox[0]
            height = bbox[3] - bbox[1]
            if degree >= 2 and (width == 0 or height == 0):
                motif = "alpha_helix"
                function = "rhythmic_pulse"
            elif degree >= 2 and width > 0 and height > 0:
                motif = "beta_sheet"
                function = "rigid_barrier"
            elif degree >= 3:
                motif = "allosteric_complex"
                function = "global_signal"
            else:
                motif = "tertiary_core"
                function = "localized_damage"
            stability = min(1.0, 0.25 + 0.2 * degree)
            motifs.append(
                DomainRecord(
                    id=f"domain_{node.id}",
                    motif_type=motif,
                    stability=stability,
                    function=function,
                    bounding_box=bbox,
                )
            )
        return motifs


@dataclass
class EducationalOverlay:
    def explain(self, domain: DomainRecord, state: ConformationState) -> str:
        intro = {
            "alpha_helix": "This α-helix is pulsing damage like a contractile filament.",
            "beta_sheet": "This β-sheet behaves like a rigid structural wall.",
            "allosteric_complex": "This allosteric complex relays sensing into global response.",
            "tertiary_core": "This tertiary domain is performing localized tower work.",
        }.get(domain.motif_type, "Protein domain formed.")
        return f"{intro} Current state: {state}. Stability: {domain.stability:.2f}."
