"""Regression tests for HeatEngine biophysical expansion."""

from __future__ import annotations

import unittest

from simulation.heat_engine import (
    HeatConfig,
    RuntimeHeatSettings,
    apply_bond_strength,
    apply_heat_tick,
    misfold_probability,
)


class HeatEngineTests(unittest.TestCase):
    def test_tick_increases_heat_on_fire(self) -> None:
        out = apply_heat_tick(0.0, fired=True, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        self.assertGreater(out["heat_score"], 0.0)

    def test_tick_cools_without_fire(self) -> None:
        out = apply_heat_tick(10.0, fired=False, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        self.assertLess(out["heat_score"], 10.0)

    def test_heat_never_negative(self) -> None:
        out = apply_heat_tick(0.01, fired=False, nearby_mob_density=0.0, delta=100.0, threshold=50.0)
        self.assertEqual(out["heat_score"], 0.0)

    def test_density_adds_heat(self) -> None:
        low = apply_heat_tick(0.0, fired=False, nearby_mob_density=0.1, delta=1.0, threshold=50.0)
        high = apply_heat_tick(0.0, fired=False, nearby_mob_density=1.2, delta=1.0, threshold=50.0)
        self.assertGreater(high["heat_score"], low["heat_score"])

    def test_difficulty_scalar_affects_heat(self) -> None:
        normal = apply_heat_tick(0.0, fired=True, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        hard = apply_heat_tick(
            0.0,
            fired=True,
            nearby_mob_density=0.0,
            delta=1.0,
            threshold=50.0,
            runtime=RuntimeHeatSettings(difficulty_scalar=1.65),
        )
        self.assertGreater(hard["heat_score"], normal["heat_score"])

    def test_global_multiplier_affects_heat(self) -> None:
        low = apply_heat_tick(0.0, fired=True, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        high = apply_heat_tick(
            0.0,
            fired=True,
            nearby_mob_density=0.0,
            delta=1.0,
            threshold=50.0,
            runtime=RuntimeHeatSettings(global_heat_multiplier=2.0),
        )
        self.assertGreater(high["heat_score"], low["heat_score"])

    def test_cooling_efficiency_affects_dissipation(self) -> None:
        low = apply_heat_tick(10.0, fired=False, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        high = apply_heat_tick(
            10.0,
            fired=False,
            nearby_mob_density=0.0,
            delta=1.0,
            threshold=50.0,
            runtime=RuntimeHeatSettings(cooling_efficiency=2.0),
        )
        self.assertLess(high["heat_score"], low["heat_score"])

    def test_threshold_boost_reduces_normalized_heat(self) -> None:
        base = apply_heat_tick(30.0, fired=True, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        boosted = apply_heat_tick(
            30.0,
            fired=True,
            nearby_mob_density=0.0,
            delta=1.0,
            threshold=50.0,
            runtime=RuntimeHeatSettings(tower_heat_tolerance_boost=0.5),
        )
        self.assertLess(boosted["normalized_heat"], base["normalized_heat"])

    def test_misfold_false_below_threshold(self) -> None:
        out = apply_heat_tick(5.0, fired=False, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        self.assertFalse(out["is_misfolded"])

    def test_misfold_true_above_threshold(self) -> None:
        out = apply_heat_tick(100.0, fired=True, nearby_mob_density=2.0, delta=1.0, threshold=50.0)
        self.assertTrue(out["is_misfolded"])

    def test_misfold_probability_low_region(self) -> None:
        self.assertEqual(misfold_probability(0.1), 0.05)

    def test_misfold_probability_medium_region(self) -> None:
        self.assertEqual(misfold_probability(0.8), 0.25)

    def test_misfold_probability_high_region(self) -> None:
        self.assertEqual(misfold_probability(1.2), 0.65)

    def test_bond_strength_drops_with_heat(self) -> None:
        cold = apply_bond_strength(1.0, 0.0, 0.0)
        hot = apply_bond_strength(1.0, 1.0, 1.0)
        self.assertLess(hot, cold)

    def test_bond_strength_zero_floor(self) -> None:
        cfg = HeatConfig(thermal_sensitivity=1.0)
        self.assertEqual(apply_bond_strength(1.0, 1.0, 1.0, cfg), 0.0)

    def test_delta_scaling(self) -> None:
        a = apply_heat_tick(0.0, fired=True, nearby_mob_density=0.0, delta=0.5, threshold=50.0)
        b = apply_heat_tick(0.0, fired=True, nearby_mob_density=0.0, delta=1.0, threshold=50.0)
        self.assertLess(a["heat_score"], b["heat_score"])


if __name__ == "__main__":
    unittest.main()
