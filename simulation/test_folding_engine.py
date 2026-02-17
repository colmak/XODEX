"""Regression tests for deterministic folding engine scaffolding."""

import unittest

from simulation.folding_engine import (
    AffinityEngine,
    EducationalOverlay,
    EnvironmentState,
    FoldRecordV1,
    FoldingSolver,
    TowerResidueNode,
)


class FoldingEngineTests(unittest.TestCase):
    def test_affinity_is_symmetric(self) -> None:
        engine = AffinityEngine.defaults()
        a = TowerResidueNode(id=1, residue_class="charged+", pos=(0, 0))
        b = TowerResidueNode(id=2, residue_class="charged-", pos=(1, 0))
        env = EnvironmentState()
        self.assertAlmostEqual(engine.pair_energy(a, b, env), engine.pair_energy(b, a, env))

    def test_solver_is_deterministic(self) -> None:
        nodes = [
            TowerResidueNode(id=1, residue_class="charged+", pos=(0, 0)),
            TowerResidueNode(id=2, residue_class="charged-", pos=(1, 0)),
            TowerResidueNode(id=3, residue_class="polar", pos=(2, 0)),
        ]
        solver = FoldingSolver()
        env = EnvironmentState(thermal_state=0.2, ph=7.0)
        tick_a = solver.tick(nodes, env)
        tick_b = solver.tick(nodes, env)

        self.assertAlmostEqual(tick_a.global_energy, tick_b.global_energy, places=9)
        self.assertEqual(tick_a.bonds, tick_b.bonds)
        self.assertEqual(tick_a.conformation_per_domain, tick_b.conformation_per_domain)

    def test_thermal_instability_can_trigger_misfold(self) -> None:
        nodes = [
            TowerResidueNode(id=1, residue_class="charged+", pos=(0, 0)),
            TowerResidueNode(id=2, residue_class="charged-", pos=(1, 0)),
        ]
        tick = FoldingSolver().tick(nodes, EnvironmentState(thermal_state=1.0))
        self.assertTrue(any(state == "misfolded" for state in tick.conformation_per_domain.values()))

    def test_fold_record_round_trip_shape(self) -> None:
        nodes = [
            TowerResidueNode(id=1, residue_class="polar", pos=(0, 0)),
            TowerResidueNode(id=2, residue_class="polar", pos=(1, 0)),
        ]
        tick = FoldingSolver().tick(nodes, EnvironmentState())
        record = FoldRecordV1.from_state(
            map_seed=123,
            river_slice=[(0, 0), (1, 0)],
            towers=nodes,
            tick=tick,
            conformation_history=[tick.global_energy],
        )
        self.assertEqual(record.fold_version, 1)
        self.assertEqual(len(record.bonds), len(tick.bonds))
        self.assertEqual(record.global_energy, tick.global_energy)

    def test_educational_overlay_contains_motif_hint(self) -> None:
        nodes = [
            TowerResidueNode(id=1, residue_class="polar", pos=(0, 0)),
            TowerResidueNode(id=2, residue_class="polar", pos=(1, 0)),
            TowerResidueNode(id=3, residue_class="polar", pos=(2, 0)),
        ]
        tick = FoldingSolver().tick(nodes, EnvironmentState())
        first = tick.domains[0]
        line = EducationalOverlay().explain(first, tick.conformation_per_domain[first.id])
        self.assertIn("Current state", line)


if __name__ == "__main__":
    unittest.main()
