# GODOT 4.6.1 STRICT TYPING – CLEAN FIRST LAUNCH
extends Node

class_name TowerGraph

signal graph_delta_ready(delta_payload: Dictionary)

var affinity_table: AffinityTable = AffinityTable.create_default()
var bond_threshold: float = 0.20
var diagonal_connectivity: bool = false
var towers: Array[Dictionary] = []
var bonds: Array[Dictionary] = []

func configure(table: AffinityTable, threshold: float = 0.20, use_diagonal: bool = false) -> void:
	affinity_table = table
	bond_threshold = threshold
	diagonal_connectivity = use_diagonal

func sync_from_towers(next_towers: Array[Dictionary]) -> Dictionary:
	towers = next_towers.duplicate(true)
	bonds.clear()
	for i: int in range(towers.size()):
		for j: int in range(i + 1, towers.size()):
			var left: Dictionary = towers[i]
			var right: Dictionary = towers[j]
			if not _neighbors(left, right):
				continue
			var pair_eval: Dictionary = affinity_table.evaluate_pair(left, right, diagonal_connectivity)
			var strength: float = float(pair_eval["strength"])
			if absf(strength) < bond_threshold:
				continue
			bonds.append({
				"from_id": int(left.get("id", 0)),
				"to_id": int(right.get("id", 0)),
				"from": left.get("pos", Vector2.ZERO),
				"to": right.get("pos", Vector2.ZERO),
				"strength": strength,
				"affinity_type": str(pair_eval["affinity_type"]),
			})
	var payload: Dictionary = {
		"foldgraph_version": 0.1,
		"towers": towers.duplicate(true),
		"bonds": bonds.duplicate(true),
		"graph_stats": _graph_stats(),
	}
	emit_signal("graph_delta_ready", payload)
	return payload

func _neighbors(left: Dictionary, right: Dictionary) -> bool:
	var dx: int = absi(int(left.get("grid_x", 0)) - int(right.get("grid_x", 0)))
	var dy: int = absi(int(left.get("grid_y", 0)) - int(right.get("grid_y", 0)))
	var orthogonal: bool = dx + dy == 1
	var diagonal: bool = diagonal_connectivity and dx == 1 and dy == 1
	return orthogonal or diagonal

func _graph_stats() -> Dictionary:
	var total: int = bonds.size()
	if total == 0:
		return {"total_bonds": 0, "avg_stability": 0.0, "misfold_risk": 0.0}
	var stability_sum: float = 0.0
	var negatives: int = 0
	for bond: Dictionary in bonds:
		var strength: float = float(bond["strength"])
		stability_sum += strength
		if strength < 0.0:
			negatives += 1
	return {
		"total_bonds": total,
		"avg_stability": stability_sum / float(total),
		"misfold_risk": float(negatives) / float(total),
	}
