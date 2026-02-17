"""Regression checks for baseline BURZEN TD core mechanic helpers."""

import unittest

from simulation.basic_mechanics import (
    CoreRules,
    EnemySnapshot,
    TowerStats,
    apply_damage,
    can_place_tower,
    enemy_hp_for_wave,
    enemy_speed_for_wave,
    is_enemy_defeated,
    reward_for_kill,
    step_enemy,
    tower_hit_damage,
)


class BasicMechanicsTests(unittest.TestCase):
    def test_tower_placement_limit(self) -> None:
        rules = CoreRules(max_towers=5)
        self.assertTrue(can_place_tower(4, rules))
        self.assertFalse(can_place_tower(5, rules))

    def test_wave_scaling_increases_stats(self) -> None:
        rules = CoreRules()
        self.assertGreater(enemy_hp_for_wave(3, rules), enemy_hp_for_wave(1, rules))
        self.assertGreater(enemy_speed_for_wave(3, rules), enemy_speed_for_wave(1, rules))

    def test_enemy_step_and_damage_resolution(self) -> None:
        tower = TowerStats(damage=20.0, fire_rate_per_second=1.5)
        enemy = EnemySnapshot(hp=100.0, progress_px=10.0, speed_px_s=80.0)

        moved = step_enemy(enemy, dt=0.25)
        self.assertEqual(moved.progress_px, 30.0)

        damage = tower_hit_damage(tower, dt=0.25, overheated=False)
        damaged = apply_damage(moved, damage)

        self.assertLess(damaged.hp, moved.hp)
        self.assertFalse(is_enemy_defeated(damaged))

    def test_overheated_tower_deals_no_damage(self) -> None:
        tower = TowerStats()
        self.assertEqual(tower_hit_damage(tower, dt=0.5, overheated=True), 0.0)

    def test_reward_scales_with_wave(self) -> None:
        rules = CoreRules(base_reward=5)
        self.assertGreaterEqual(reward_for_kill(4, rules), reward_for_kill(1, rules))


if __name__ == "__main__":
    unittest.main()
