"""Residue-class affinity and bond graph model for BURZEN TD v0.00.5.0.

Phase 1 scope:
- residue classification attached to tower definitions,
- hot-swappable affinity table with thermal/distance/orientation modifiers,
- deterministic 4-connectivity graph updates,
- FoldGraph v0.1 round-trip serialization.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Literal

ResidueClass = Literal[
    "nonpolar",
    "polar_uncharged",
    "positively_charged",
    "negatively_charged",
    "special",
]


DEFAULT_TOWER_RESIDUE_CLASS: dict[str, ResidueClass] = {
    # Geometric defaults.
    "triangle": "nonpolar",
    "square": "nonpolar",
    "hexagon": "nonpolar",
    # Elemental defaults.
    "water": "polar_uncharged",
    "oxygen": "polar_uncharged",
    "fire": "positively_charged",
    "air": "negatively_charged",
    "earth": "special",
    # Keystone/control style towers.
    "keystone": "special",
    "synthesis_hub": "special",
}


@dataclass(frozen=True)
class TowerDefinition:
    id: str
    residue_class: ResidueClass
    modifiers: tuple[str, ...] = ()


@dataclass(frozen=True)
class TowerNode:
    id: int
    tower_id: str
    residue_class: ResidueClass
    pos_x: int
    pos_y: int
    thermal_state: float = 0.0
    modifiers: tuple[str, ...] = ()


@dataclass(frozen=True)
class Bond:
    from_id: int
    to_id: int
    affinity_type: str
    strength: float
    contrib: float
    timestamp: int


@dataclass(frozen=True)
class GraphStats:
    total_bonds: int
    avg_stability: float
    misfold_risk: float


@dataclass(frozen=True)
class FoldGraphSnapshot:
    foldgraph_version: float
    towers: tuple[TowerNode, ...]
    bonds: tuple[Bond, ...]
    graph_stats: GraphStats


@dataclass
class AffinityTable:
    """Serializable, hot-swappable affinity table and modifiers."""

    matrix: dict[tuple[ResidueClass, ResidueClass], float]
    thermal_penalty_gain: float = 0.40
    distance_falloff: float = 0.12
    orientation_gain: float = 0.05

    @classmethod
    def defaults(cls) -> "AffinityTable":
        values: dict[tuple[ResidueClass, ResidueClass], float] = {
            ("nonpolar", "nonpolar"): 0.95,
            ("nonpolar", "polar_uncharged"): -0.35,
            ("nonpolar", "positively_charged"): -0.20,
            ("nonpolar", "negatively_charged"): -0.20,
            ("nonpolar", "special"): 0.22,
            ("polar_uncharged", "polar_uncharged"): 0.50,
            ("polar_uncharged", "positively_charged"): 0.40,
            ("polar_uncharged", "negatively_charged"): 0.40,
            ("polar_uncharged", "special"): 0.18,
            ("positively_charged", "positively_charged"): -0.72,
            ("positively_charged", "negatively_charged"): 0.88,
            ("positively_charged", "special"): 0.24,
            ("negatively_charged", "negatively_charged"): -0.72,
            ("negatively_charged", "special"): 0.24,
            ("special", "special"): 0.08,
        }
        for (left, right), v in list(values.items()):
            values[(right, left)] = v
        return cls(matrix=values)

    @classmethod
    def from_serialized(cls, payload: dict[str, object]) -> "AffinityTable":
        matrix_payload = payload.get("matrix", {})
        matrix: dict[tuple[ResidueClass, ResidueClass], float] = {}
        for pair_key, value in matrix_payload.items():
            left, right = str(pair_key).split("|")
            pair = (left, right)
            matrix[pair] = float(value)
            matrix[(right, left)] = float(value)
        return cls(
            matrix=matrix,
            thermal_penalty_gain=float(payload.get("thermal_penalty_gain", 0.40)),
            distance_falloff=float(payload.get("distance_falloff", 0.12)),
            orientation_gain=float(payload.get("orientation_gain", 0.05)),
        )

    def serialize(self) -> dict[str, object]:
        unique: dict[str, float] = {}
        for (left, right), value in self.matrix.items():
            if f"{right}|{left}" in unique:
                continue
            unique[f"{left}|{right}"] = value
        return {
            "matrix": unique,
            "thermal_penalty_gain": self.thermal_penalty_gain,
            "distance_falloff": self.distance_falloff,
            "orientation_gain": self.orientation_gain,
        }

    def evaluate(self, left: TowerNode, right: TowerNode, *, diagonal: bool = False) -> tuple[float, str]:
        base = self.matrix[(left.residue_class, right.residue_class)]
        thermal = (left.thermal_state + right.thermal_state) * 0.5
        thermal_mod = max(0.0, 1.0 - thermal * self.thermal_penalty_gain)
        dx = abs(left.pos_x - right.pos_x)
        dy = abs(left.pos_y - right.pos_y)
        manhattan = dx + dy
        distance_mod = max(0.0, 1.0 - max(0, manhattan - 1) * self.distance_falloff)
        orientation_mod = 1.0 + self.orientation_gain if (diagonal and dx == 1 and dy == 1) else 1.0
        score = base * thermal_mod * distance_mod * orientation_mod
        affinity_type = "attractive" if score > 0 else "repulsive" if score < 0 else "neutral"
        return score, affinity_type


@dataclass
class TowerGraph:
    affinity_table: AffinityTable = field(default_factory=AffinityTable.defaults)
    bond_threshold: float = 0.20
    diagonal_connectivity: bool = False
    towers: dict[int, TowerNode] = field(default_factory=dict)
    bonds: dict[tuple[int, int], Bond] = field(default_factory=dict)
    tick_counter: int = 0

    def set_affinity_table(self, table: AffinityTable) -> None:
        self.affinity_table = table

    def place_tower(self, node: TowerNode) -> None:
        self.towers[node.id] = node
        self._recompute_local(node.id)

    def remove_tower(self, tower_id: int) -> None:
        self.towers.pop(tower_id, None)
        for edge in [k for k in self.bonds if tower_id in k]:
            self.bonds.pop(edge, None)

    def update_tower_thermal_state(self, tower_id: int, thermal_state: float) -> None:
        old = self.towers[tower_id]
        self.towers[tower_id] = TowerNode(
            id=old.id,
            tower_id=old.tower_id,
            residue_class=old.residue_class,
            pos_x=old.pos_x,
            pos_y=old.pos_y,
            thermal_state=thermal_state,
            modifiers=old.modifiers,
        )
        self._recompute_local(tower_id)

    def tick(self) -> FoldGraphSnapshot:
        self.tick_counter += 1
        for tower_id in sorted(self.towers):
            self._recompute_local(tower_id)
        return self.snapshot()

    def snapshot(self) -> FoldGraphSnapshot:
        bonds = tuple(self.bonds[k] for k in sorted(self.bonds))
        stats = self._stats(bonds)
        return FoldGraphSnapshot(
            foldgraph_version=0.1,
            towers=tuple(self.towers[k] for k in sorted(self.towers)),
            bonds=bonds,
            graph_stats=stats,
        )

    def serialize(self) -> dict[str, object]:
        snap = self.snapshot()
        return {
            "foldgraph_version": snap.foldgraph_version,
            "towers": [dict(asdict(t), modifiers=list(t.modifiers)) for t in snap.towers],
            "bonds": [asdict(b) for b in snap.bonds],
            "graph_stats": asdict(snap.graph_stats),
            "tick_counter": self.tick_counter,
        }

    @classmethod
    def from_serialized(cls, payload: dict[str, object], affinity_table: AffinityTable | None = None) -> "TowerGraph":
        graph = cls(affinity_table=affinity_table or AffinityTable.defaults())
        graph.tick_counter = int(payload.get("tick_counter", 0))
        for tower in payload.get("towers", []):
            normalized = dict(tower)
            normalized["modifiers"] = tuple(normalized.get("modifiers", ()))
            node = TowerNode(**normalized)
            graph.towers[node.id] = node
        for bond in payload.get("bonds", []):
            record = Bond(**bond)
            edge = tuple(sorted((record.from_id, record.to_id)))
            graph.bonds[edge] = record
        return graph

    def _recompute_local(self, tower_id: int) -> None:
        node = self.towers.get(tower_id)
        if node is None:
            return
        for neighbor in self._candidate_neighbors(node):
            edge = tuple(sorted((node.id, neighbor.id)))
            strength, affinity_type = self.affinity_table.evaluate(node, neighbor, diagonal=self.diagonal_connectivity)
            if abs(strength) >= self.bond_threshold:
                self.bonds[edge] = Bond(
                    from_id=edge[0],
                    to_id=edge[1],
                    affinity_type=affinity_type,
                    strength=strength,
                    contrib=strength,
                    timestamp=self.tick_counter,
                )
            else:
                self.bonds.pop(edge, None)

    def _candidate_neighbors(self, node: TowerNode) -> list[TowerNode]:
        out: list[TowerNode] = []
        for other in self.towers.values():
            if other.id == node.id:
                continue
            dx = abs(node.pos_x - other.pos_x)
            dy = abs(node.pos_y - other.pos_y)
            orthogonal = dx + dy == 1
            diagonal = self.diagonal_connectivity and dx == 1 and dy == 1
            if orthogonal or diagonal:
                out.append(other)
        return out

    def _stats(self, bonds: tuple[Bond, ...]) -> GraphStats:
        if not bonds:
            return GraphStats(total_bonds=0, avg_stability=0.0, misfold_risk=0.0)
        avg_stability = sum(b.contrib for b in bonds) / len(bonds)
        negative = sum(1 for b in bonds if b.contrib < 0)
        return GraphStats(
            total_bonds=len(bonds),
            avg_stability=avg_stability,
            misfold_risk=negative / len(bonds),
        )


def normalize_tower_definitions(tower_ids: list[str]) -> list[TowerDefinition]:
    """Attach mandatory residue classes to legacy taxonomy IDs."""

    definitions: list[TowerDefinition] = []
    for tower_id in tower_ids:
        residue_class = DEFAULT_TOWER_RESIDUE_CLASS.get(tower_id, "special")
        modifiers: tuple[str, ...] = ()
        if residue_class == "nonpolar":
            modifiers = ("hydrophobic_core",)
        if tower_id in {"earth", "synthesis_hub"}:
            modifiers = tuple(sorted(set(modifiers + ("turn_preference",))))
        definitions.append(TowerDefinition(id=tower_id, residue_class=residue_class, modifiers=modifiers))
    return definitions
