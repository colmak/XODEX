extends Node

class_name TowerGraphSync

signal graph_delta_ready(delta_payload: Dictionary)

var bond_threshold: float = 0.2
var diagonal_connectivity: bool = false
var towers: Array[Dictionary] = []
var bonds: Array[Dictionary] = []

var affinity_table: Dictionary = {
	"nonpolar|nonpolar": 0.95,
	"nonpolar|polar_uncharged": -0.35,
	"nonpolar|positively_charged": -0.20,
	"nonpolar|negatively_charged": -0.20,
	"nonpolar|special": 0.22,
	"polar_uncharged|polar_uncharged": 0.50,
	"polar_uncharged|positively_charged": 0.40,
	"polar_uncharged|negatively_charged": 0.40,
	"polar_uncharged|special": 0.18,
	"positively_charged|positively_charged": -0.72,
	"positively_charged|negatively_charged": 0.88,
	"positively_charged|special": 0.24,
	"negatively_charged|negatively_charged": -0.72,
	"negatively_charged|special": 0.24,
	"special|special": 0.08,
}

func apply_wasmutable_patch(patch: Dictionary) -> void:
	if patch.has("affinity_table"):
		affinity_table = patch["affinity_table"].duplicate(true)
	if patch.has("bond_threshold"):
		bond_threshold = float(patch["bond_threshold"])
	if patch.has("diagonal_connectivity"):
		diagonal_connectivity = bool(patch["diagonal_connectivity"])

func sync_from_towers(next_towers: Array[Dictionary]) -> Dictionary:
	towers = next_towers.duplicate(true)
	bonds.clear()
	for i in range(towers.size()):
		for j in range(i + 1, towers.size()):
			var a: Dictionary = towers[i]
			var b: Dictionary = towers[j]
			if not _neighbors(a, b):
				continue
			var score: float = _affinity_score(a, b)
			if absf(score) < bond_threshold:
				continue
			bonds.append({
				"from_id": int(a["id"]),
				"to_id": int(b["id"]),
				"strength": score,
				"affinity_type": "attractive" if score > 0.0 else "repulsive",
			})
	var payload: Dictionary = {
		"tower_count": towers.size(),
		"bond_count": bonds.size(),
		"bonds": bonds,
	}
	emit_signal("graph_delta_ready", payload)
	return payload

func _neighbors(a: Dictionary, b: Dictionary) -> bool:
	var ax: int = int(a.get("grid_x", 0))
	var ay: int = int(a.get("grid_y", 0))
	var bx: int = int(b.get("grid_x", 0))
	var by: int = int(b.get("grid_y", 0))
	var dx: int = absi(ax - bx)
	var dy: int = absi(ay - by)
	var orthogonal: bool = dx + dy == 1
	var diagonal: bool = diagonal_connectivity and dx == 1 and dy == 1
	return orthogonal or diagonal

func _affinity_score(a: Dictionary, b: Dictionary) -> float:
	var left: String = str(a.get("residue_class", "special"))
	var right: String = str(b.get("residue_class", "special"))
	var key: String = "%s|%s" % [left, right]
	var rev_key: String = "%s|%s" % [right, left]
	var base: float = float(affinity_table.get(key, affinity_table.get(rev_key, 0.0)))
	var t_left: float = float(a.get("thermal_state", 0.0))
	var t_right: float = float(b.get("thermal_state", 0.0))
	var thermal_mod: float = maxf(0.0, 1.0 - ((t_left + t_right) * 0.5) * 0.4)
	return base * thermal_mod
