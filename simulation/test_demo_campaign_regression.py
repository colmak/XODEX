import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOWER_PATH = ROOT / "android" / "BurzenTD" / "data" / "towers" / "tower_definitions.json"
LEVEL_DIR = ROOT / "android" / "BurzenTD" / "levels" / "demo"

EXPECTED_IDS = [
    "hydrophobic_anchor",
    "polar_hydrator",
    "cationic_defender",
    "anionic_repulsor",
    "proline_hinge",
    "alpha_helix_pulsar",
    "beta_sheet_fortifier",
    "molecular_chaperone",
]

LEVEL_IDS = [
    "level_01_first_fold",
    "level_02_thermal_balance",
    "level_03_neighbor_bonds",
    "level_04_tissue_emergence",
    "level_05_pathway_design",
]


def _load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_tower_catalog_complete_and_unique():
    data = _load_json(TOWER_PATH)
    towers = data["towers"]
    ids = [t["tower_id"] for t in towers]
    assert len(towers) == 8
    assert ids == EXPECTED_IDS
    assert len(set(ids)) == 8


def test_tower_required_keys_present():
    required = {
        "tower_id",
        "display_name",
        "scene_path",
        "residue_class",
        "heat_gen_rate",
        "heat_tolerance",
        "preferred_bind",
        "special_ability",
        "tooltip",
        "affinity_modifiers",
        "visuals",
    }
    towers = _load_json(TOWER_PATH)["towers"]
    for tower in towers:
        assert required.issubset(set(tower.keys()))
        assert tower["scene_path"].startswith("res://towers/tower_")


def test_heat_contracts_for_specific_towers():
    towers = {t["tower_id"]: t for t in _load_json(TOWER_PATH)["towers"]}
    assert towers["molecular_chaperone"]["heat_gen_rate"] < 0
    assert towers["alpha_helix_pulsar"]["heat_tolerance"] == "low"
    assert towers["hydrophobic_anchor"]["heat_gen_rate"] > 1.0


def test_demo_levels_exist_and_progressive_unlocks():
    levels = [_load_json(LEVEL_DIR / f"{lid}.json") for lid in LEVEL_IDS]
    assert len(levels) == 5
    unlock_counts = [len(level["unlocked_towers"]) for level in levels]
    assert unlock_counts == [3, 5, 5, 7, 8]
    assert levels[0]["unlocked_towers"] == ["hydrophobic_anchor", "polar_hydrator", "molecular_chaperone"]
    assert levels[-1]["unlocked_towers"] == EXPECTED_IDS


def test_demo_level_conditions_and_shape():
    for lid in LEVEL_IDS:
        level = _load_json(LEVEL_DIR / f"{lid}.json")
        assert len(level["path_points"]) >= 2
        assert level["wave_count"] >= 3
        assert level["enemies_per_wave"] >= 4
        assert level["free_energy_threshold"] <= 0.62
        assert level["minimum_bonds"] >= 2
        assert len(level["tutorial_steps"]) == 3


def test_tower_scene_files_present():
    for idx, tower_id in enumerate(EXPECTED_IDS, start=1):
        scene = ROOT / "android" / "BurzenTD" / "towers" / f"tower_{idx:02d}_{tower_id}.tscn"
        assert scene.exists(), tower_id


def test_level_01_id():
    assert _load_json(LEVEL_DIR / "level_01_first_fold.json")["id"] == "level_01_first_fold"

def test_level_02_id():
    assert _load_json(LEVEL_DIR / "level_02_thermal_balance.json")["id"] == "level_02_thermal_balance"

def test_level_03_id():
    assert _load_json(LEVEL_DIR / "level_03_neighbor_bonds.json")["id"] == "level_03_neighbor_bonds"

def test_level_04_id():
    assert _load_json(LEVEL_DIR / "level_04_tissue_emergence.json")["id"] == "level_04_tissue_emergence"

def test_level_05_id():
    assert _load_json(LEVEL_DIR / "level_05_pathway_design.json")["id"] == "level_05_pathway_design"

def test_level_01_tower_count():
    assert len(_load_json(LEVEL_DIR / "level_01_first_fold.json")["unlocked_towers"]) == 3

def test_level_02_tower_count():
    assert len(_load_json(LEVEL_DIR / "level_02_thermal_balance.json")["unlocked_towers"]) == 5

def test_level_03_tower_count():
    assert len(_load_json(LEVEL_DIR / "level_03_neighbor_bonds.json")["unlocked_towers"]) == 5

def test_level_04_tower_count():
    assert len(_load_json(LEVEL_DIR / "level_04_tissue_emergence.json")["unlocked_towers"]) == 7

def test_level_05_tower_count():
    assert len(_load_json(LEVEL_DIR / "level_05_pathway_design.json")["unlocked_towers"]) == 8

def test_level_01_has_chaperone():
    assert "molecular_chaperone" in _load_json(LEVEL_DIR / "level_01_first_fold.json")["unlocked_towers"]

def test_level_05_has_all_towers():
    assert _load_json(LEVEL_DIR / "level_05_pathway_design.json")["unlocked_towers"] == EXPECTED_IDS

def test_tower_1_name():
    assert _load_json(TOWER_PATH)["towers"][0]["display_name"] == "Hydrophobic Anchor"

def test_tower_2_name():
    assert _load_json(TOWER_PATH)["towers"][1]["display_name"] == "Polar Hydrator"

def test_tower_3_name():
    assert _load_json(TOWER_PATH)["towers"][2]["display_name"] == "Cationic Defender"

def test_tower_4_name():
    assert _load_json(TOWER_PATH)["towers"][3]["display_name"] == "Anionic Repulsor"

def test_tower_5_name():
    assert _load_json(TOWER_PATH)["towers"][4]["display_name"] == "Proline Hinge"

def test_tower_6_name():
    assert _load_json(TOWER_PATH)["towers"][5]["display_name"] == "Alpha-Helix Pulsar"

def test_tower_7_name():
    assert _load_json(TOWER_PATH)["towers"][6]["display_name"] == "Beta-Sheet Fortifier"

def test_tower_8_name():
    assert _load_json(TOWER_PATH)["towers"][7]["display_name"] == "Molecular Chaperone"
