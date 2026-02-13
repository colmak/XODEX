"""Regression checks for XODEX.PROTEIN_TOWER model behavior."""

import unittest

from simulation.protein_tower import (
    LocalFlowState,
    ProteinTowerConfig,
    ProteinTowerState,
    adaptation_rate_for_wave,
    alpha_for_wave,
    step_protein_tower,
)


def uniform_grid(value: float, size: int = 8) -> list[list[float]]:
    return [[value for _ in range(size)] for _ in range(size)]


class ProteinTowerTests(unittest.TestCase):
    def test_wave_alpha_scaling(self) -> None:
        config = ProteinTowerConfig(alpha_0=2.0)
        self.assertEqual(alpha_for_wave(0, config), 2.0)
        self.assertAlmostEqual(alpha_for_wave(5, config), 2.8)

    def test_adaptation_rate_decays_with_wave(self) -> None:
        config = ProteinTowerConfig(base_adaptation_rate=0.2, adaptation_decay_per_wave=0.01, min_adaptation_rate=0.05)
        self.assertGreater(adaptation_rate_for_wave(1, config), adaptation_rate_for_wave(8, config))
        self.assertEqual(adaptation_rate_for_wave(40, config), 0.05)

    def test_swarm_curvature_increases_damage(self) -> None:
        state = ProteinTowerState(theta=0.8)
        sparse = LocalFlowState(
            creep_density=uniform_grid(0.2),
            flow_speed=uniform_grid(1.0),
            wall_block=uniform_grid(0.4),
        )
        swarm_density = uniform_grid(0.2)
        swarm_density[4][4] = 2.0
        swarm_density[3][4] = 1.5
        swarm_density[5][4] = 1.5
        swarm = LocalFlowState(
            creep_density=swarm_density,
            flow_speed=uniform_grid(1.0),
            wall_block=uniform_grid(0.4),
        )

        sparse_tick = step_protein_tower(state, sparse, wave_index=4, realized_escape_energy=0.4)
        swarm_tick = step_protein_tower(state, swarm, wave_index=4, realized_escape_energy=0.4)

        self.assertGreater(swarm_tick.curvature, sparse_tick.curvature)
        self.assertGreater(swarm_tick.damage, sparse_tick.damage)

    def test_state_mutates_from_prediction_error(self) -> None:
        state = ProteinTowerState(theta=0.5)
        flow = LocalFlowState(
            creep_density=uniform_grid(0.7),
            flow_speed=uniform_grid(1.2),
            wall_block=uniform_grid(0.3),
        )
        tick = step_protein_tower(state, flow, wave_index=2, realized_escape_energy=0.0)
        self.assertGreater(tick.state.theta, state.theta)

    def test_instability_triggers_collapse_and_recovery_path(self) -> None:
        config = ProteinTowerConfig(instability_threshold=1.0, heat_per_tick=2.0, heat_decay_per_tick=0.0)
        state = ProteinTowerState(theta=1.0)
        flow = LocalFlowState(
            creep_density=uniform_grid(1.0),
            flow_speed=uniform_grid(1.0),
            wall_block=uniform_grid(1.0),
        )

        collapsed_tick = step_protein_tower(state, flow, wave_index=1, realized_escape_energy=0.0, config=config)
        self.assertTrue(collapsed_tick.state.collapsed)
        self.assertEqual(collapsed_tick.damage, 0.0)

        cool_cfg = ProteinTowerConfig(instability_threshold=1.0, heat_per_tick=0.0, heat_decay_per_tick=1.0)
        recovering_state = ProteinTowerState(theta=collapsed_tick.state.theta, heat=0.4, collapsed=True)
        recovering_tick = step_protein_tower(recovering_state, flow, wave_index=1, realized_escape_energy=0.0, config=cool_cfg)
        self.assertFalse(recovering_tick.state.collapsed)


if __name__ == "__main__":
    unittest.main()
