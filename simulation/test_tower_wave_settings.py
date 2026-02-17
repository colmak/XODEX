"""Tests for wave mob generation and heat-aware tower damage settings."""

import unittest
from random import Random

from simulation.tower_wave_settings import (
    DEFAULT_TERRAINS,
    DEFAULT_TOWERS,
    generate_wave_mobs,
    simulate_wave_damage,
    tower_setting_options,
)


class TowerWaveSettingsTests(unittest.TestCase):
    def test_wave_generation_scales_by_level_and_wave(self) -> None:
        rng = Random(7)
        mobs_w1 = generate_wave_mobs(level_index=1, wave_index=1, rng=rng, terrain=DEFAULT_TERRAINS[0])
        rng = Random(7)
        mobs_w4 = generate_wave_mobs(level_index=3, wave_index=4, rng=rng, terrain=DEFAULT_TERRAINS[0])

        self.assertGreater(len(mobs_w4), len(mobs_w1))
        self.assertGreater(sum(m.hp for m in mobs_w4), sum(m.hp for m in mobs_w1))

    def test_heat_bias_changes_average_wave_heat(self) -> None:
        rng = Random(21)
        ash = generate_wave_mobs(level_index=2, wave_index=2, rng=rng, terrain=DEFAULT_TERRAINS[1])
        rng = Random(21)
        frost = generate_wave_mobs(level_index=2, wave_index=2, rng=rng, terrain=DEFAULT_TERRAINS[2])

        ash_avg = sum(m.heat for m in ash) / len(ash)
        frost_avg = sum(m.heat for m in frost) / len(frost)
        self.assertGreater(ash_avg, frost_avg)

    def test_heat_aware_damage_can_clear_more_on_cool_terrain(self) -> None:
        rng = Random(42)
        ash_wave = generate_wave_mobs(level_index=2, wave_index=3, rng=rng, terrain=DEFAULT_TERRAINS[1])
        rng = Random(42)
        frost_wave = generate_wave_mobs(level_index=2, wave_index=3, rng=rng, terrain=DEFAULT_TERRAINS[2])

        loadout = ("triangle", "fire", "water")
        ash_report = simulate_wave_damage(
            placed_tower_ids=loadout,
            towers=DEFAULT_TOWERS,
            mobs=ash_wave,
            terrain=DEFAULT_TERRAINS[1],
        )
        frost_report = simulate_wave_damage(
            placed_tower_ids=loadout,
            towers=DEFAULT_TOWERS,
            mobs=frost_wave,
            terrain=DEFAULT_TERRAINS[2],
        )

        self.assertGreaterEqual(frost_report.kills, ash_report.kills)
        self.assertLessEqual(frost_report.remaining_hp, ash_report.remaining_hp)

    def test_tower_options_include_targeting_and_replacements(self) -> None:
        options = tower_setting_options(DEFAULT_TOWERS)
        self.assertIn("triangle", options)
        self.assertEqual(options["triangle"]["targeting"], "closest")
        self.assertIn("fire", options["triangle"]["replacements"])
        self.assertEqual(options["triangle"]["residue_class"], "nonpolar")
        self.assertIn("hydrophobic_core", options["triangle"]["modifiers"])


if __name__ == "__main__":
    unittest.main()
