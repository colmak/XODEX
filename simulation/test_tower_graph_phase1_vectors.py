"""Deterministic Phase 1 affinity regression vectors (Python/Haskell mirror)."""

from __future__ import annotations

import unittest

from simulation.tower_graph import AffinityTable, TowerNode


REGRESSION_VECTORS: list[tuple[int, str, str, float, float, float]] = [
    (0, "nonpolar", "positively_charged", 0.50, 0.51, -0.1596),
    (1, "nonpolar", "polar_uncharged", 0.89, 0.62, -0.2443),
    (2, "negatively_charged", "special", 0.55, 0.73, 0.17856),
    (3, "negatively_charged", "special", 0.44, 0.00, 0.21888),
    (4, "nonpolar", "nonpolar", 0.29, 0.10, 0.87590),
    (5, "nonpolar", "negatively_charged", 0.68, 0.21, -0.1644),
    (6, "positively_charged", "positively_charged", 0.98, 0.93, -0.44496),
    (7, "negatively_charged", "special", 0.64, 0.72, 0.17472),
    (8, "nonpolar", "special", 0.54, 0.29, 0.18348),
    (9, "polar_uncharged", "special", 0.31, 0.85, 0.13824),
    (10, "positively_charged", "positively_charged", 0.46, 0.09, -0.6408),
    (11, "special", "special", 0.50, 0.12, 0.07008),
    (12, "special", "special", 0.88, 0.40, 0.05952),
    (13, "special", "positively_charged", 0.84, 0.56, 0.17280),
    (14, "negatively_charged", "special", 0.52, 0.03, 0.21360),
    (15, "polar_uncharged", "polar_uncharged", 0.82, 0.96, 0.32200),
    (16, "special", "nonpolar", 0.72, 0.43, 0.16940),
    (17, "polar_uncharged", "negatively_charged", 0.88, 0.85, 0.26160),
    (18, "nonpolar", "negatively_charged", 0.67, 0.71, -0.1448),
    (19, "special", "positively_charged", 0.56, 0.67, 0.18096),
    (20, "positively_charged", "special", 0.80, 0.50, 0.17760),
    (21, "negatively_charged", "negatively_charged", 0.43, 0.29, -0.61632),
    (22, "positively_charged", "nonpolar", 0.03, 0.66, -0.1724),
    (23, "special", "negatively_charged", 0.80, 0.93, 0.15696),
    (24, "positively_charged", "polar_uncharged", 0.26, 0.49, 0.34000),
    (25, "special", "negatively_charged", 0.81, 0.56, 0.17424),
]


class Phase1MirrorVectorTests(unittest.TestCase):
    def test_affinity_vectors_match_haskell_mirror(self) -> None:
        table = AffinityTable.defaults()
        for idx, left, right, left_thermal, right_thermal, expected in REGRESSION_VECTORS:
            with self.subTest(vector=idx):
                node_a = TowerNode(idx * 2 + 1, "left", left, 0, 0, left_thermal)
                node_b = TowerNode(idx * 2 + 2, "right", right, 1, 0, right_thermal)
                strength, _ = table.evaluate(node_a, node_b)
                self.assertAlmostEqual(strength, expected, places=9)


if __name__ == "__main__":
    unittest.main()
