"""Regression tests for BURZEN TD Protein Phase 1 graph foundation."""

from __future__ import annotations

import json
import unittest
from random import Random

from simulation.tower_graph import (
    AffinityTable,
    TowerGraph,
    TowerNode,
    normalize_tower_definitions,
)


class TowerGraphTests(unittest.TestCase):
    def test_normalize_tower_definitions_assigns_residue_class(self) -> None:
        defs = normalize_tower_definitions(["triangle", "water", "synthesis_hub", "unknown"])
        self.assertEqual(defs[0].residue_class, "nonpolar")
        self.assertEqual(defs[1].residue_class, "polar_uncharged")
        self.assertEqual(defs[2].modifiers, ("turn_preference",))
        self.assertEqual(defs[3].residue_class, "special")

    def test_affinity_table_hot_swap(self) -> None:
        graph = TowerGraph()
        graph.place_tower(TowerNode(1, "triangle", "nonpolar", 0, 0, 0.0))
        graph.place_tower(TowerNode(2, "water", "polar_uncharged", 1, 0, 0.0))
        graph.tick()
        baseline = list(graph.bonds.values())[0].strength

        swapped = AffinityTable.from_serialized(
            {
                "matrix": {
                    "nonpolar|polar_uncharged": 0.9,
                },
                "thermal_penalty_gain": 0.4,
                "distance_falloff": 0.12,
                "orientation_gain": 0.05,
            }
        )
        graph.set_affinity_table(swapped)
        graph.tick()
        boosted = list(graph.bonds.values())[0].strength
        self.assertGreater(boosted, baseline)

    def test_thermal_state_reduces_affinity(self) -> None:
        table = AffinityTable.defaults()
        left = TowerNode(1, "triangle", "nonpolar", 0, 0, 0.0)
        right = TowerNode(2, "square", "nonpolar", 1, 0, 0.0)
        cold, _ = table.evaluate(left, right)
        hot, _ = table.evaluate(
            TowerNode(1, "triangle", "nonpolar", 0, 0, 1.0),
            TowerNode(2, "square", "nonpolar", 1, 0, 1.0),
        )
        self.assertLess(hot, cold)

    def test_round_trip_serialization(self) -> None:
        graph = TowerGraph()
        graph.place_tower(TowerNode(1, "triangle", "nonpolar", 0, 0, 0.1))
        graph.place_tower(TowerNode(2, "fire", "positively_charged", 1, 0, 0.2))
        graph.tick()
        payload = graph.serialize()
        encoded = json.dumps(payload)
        restored = TowerGraph.from_serialized(json.loads(encoded))
        self.assertEqual(restored.serialize()["bonds"], payload["bonds"])
        self.assertEqual(restored.serialize()["towers"], payload["towers"])

    def test_placement_and_removal_rebuilds_edges(self) -> None:
        graph = TowerGraph()
        graph.place_tower(TowerNode(1, "triangle", "nonpolar", 0, 0, 0.0))
        graph.place_tower(TowerNode(2, "square", "nonpolar", 1, 0, 0.0))
        self.assertEqual(len(graph.bonds), 1)
        graph.remove_tower(2)
        self.assertEqual(len(graph.bonds), 0)

    def test_seeded_determinism_25_cases(self) -> None:
        for seed in range(25):
            with self.subTest(seed=seed):
                rng = Random(seed)
                graph_a = TowerGraph()
                graph_b = TowerGraph()
                for tower_id in range(1, 16):
                    residue = rng.choice(
                        [
                            "nonpolar",
                            "polar_uncharged",
                            "positively_charged",
                            "negatively_charged",
                            "special",
                        ]
                    )
                    x = rng.randint(0, 4)
                    y = rng.randint(0, 4)
                    thermal = round(rng.random(), 4)
                    node = TowerNode(tower_id, f"t_{tower_id}", residue, x, y, thermal)
                    graph_a.place_tower(node)
                    graph_b.place_tower(node)

                tick_a = graph_a.tick()
                tick_b = graph_b.tick()
                self.assertEqual(tick_a.bonds, tick_b.bonds)
                self.assertAlmostEqual(tick_a.graph_stats.avg_stability, tick_b.graph_stats.avg_stability, places=12)
                self.assertAlmostEqual(tick_a.graph_stats.misfold_risk, tick_b.graph_stats.misfold_risk, places=12)


if __name__ == "__main__":
    unittest.main()
