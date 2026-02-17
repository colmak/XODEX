# GODOT 4.6.1 STRICT – HEAT & SELECTION MODULE
extends Control

class_name TowerSelectionUI

signal tower_selected(selection: Dictionary)
signal tower_confirmed(selection: Dictionary, position: Vector2)

const DEFAULT_CATALOG: Array[Dictionary] = [
	{"tower_id": "triangle", "residue_class": "nonpolar", "heat_tolerance": "high", "heat_gen_rate": 0.9, "preferred_bind": "nonpolar", "folding_role": "hydrophobic_core", "build_cost": 14},
	{"tower_id": "water", "residue_class": "polar_uncharged", "heat_tolerance": "medium", "heat_gen_rate": 0.6, "preferred_bind": "polar_uncharged", "folding_role": "surface_stabilizer", "build_cost": 10},
	{"tower_id": "fire", "residue_class": "positively_charged", "heat_tolerance": "medium", "heat_gen_rate": 1.1, "preferred_bind": "negatively_charged", "folding_role": "allosteric_trigger", "build_cost": 16},
	{"tower_id": "air", "residue_class": "negatively_charged", "heat_tolerance": "medium", "heat_gen_rate": 1.0, "preferred_bind": "positively_charged", "folding_role": "sheet_rigidity", "build_cost": 15},
	{"tower_id": "synthesis_hub", "residue_class": "special", "heat_tolerance": "high", "heat_gen_rate": 0.5, "preferred_bind": "special", "folding_role": "chaperone", "build_cost": 20},
]

var catalog: Array[Dictionary] = DEFAULT_CATALOG.duplicate(true)
var active_tab: String = "all"
var active_selection: Dictionary = {}

func set_catalog(next_catalog: Array[Dictionary]) -> void:
	catalog = next_catalog.duplicate(true)

func set_tab(tab: String) -> void:
	active_tab = tab

func visible_catalog(global_heat_ratio: float) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for entry: Dictionary in catalog:
		if active_tab == "heat_tolerant" and str(entry.get("heat_tolerance", "low")) != "high":
			continue
		if global_heat_ratio > 0.5 and str(entry.get("heat_tolerance", "low")) == "low":
			continue
		filtered.append(entry)
	return filtered

func select_tower(tower_id: String) -> Dictionary:
	for entry: Dictionary in catalog:
		if str(entry.get("tower_id", "")) != tower_id:
			continue
		active_selection = entry.duplicate(true)
		emit_signal("tower_selected", active_selection)
		return active_selection
	active_selection = {}
	return active_selection

func projected_heat_delta(tower_definition: Dictionary, nearby_density: float) -> float:
	var baseline: float = float(tower_definition.get("heat_gen_rate", 0.8))
	return baseline + maxf(0.0, nearby_density) * 0.3

func optimize_for_current_heat(global_heat_ratio: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = INF
	for entry: Dictionary in visible_catalog(global_heat_ratio):
		var tolerance_score: float = 1.0 if str(entry.get("heat_tolerance", "low")) == "high" else 0.4
		var score: float = projected_heat_delta(entry, global_heat_ratio) - tolerance_score
		if score < best_score:
			best_score = score
			best = entry
	return best.duplicate(true)

func confirm_selection(position: Vector2, nearby_density: float) -> Dictionary:
	if active_selection.is_empty():
		return {}
	var payload: Dictionary = active_selection.duplicate(true)
	payload["projected_heat_delta"] = projected_heat_delta(payload, nearby_density)
	emit_signal("tower_confirmed", payload, position)
	return payload
