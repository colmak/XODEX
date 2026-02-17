# GODOT 4.6.1 STRICT – DEMO CAMPAIGN v0.00.6
extends Control

class_name TowerSelectionUI

signal tower_selected(selection: Dictionary)
signal tower_confirmed(selection: Dictionary, position: Vector2)

const TOWER_DEFINITIONS_PATH: String = "res://data/towers/tower_definitions.json"

var catalog: Array[Dictionary] = []
var active_tab: String = "all"
var active_selection: Dictionary = {}

func _ready() -> void:
	catalog = _load_catalog(TOWER_DEFINITIONS_PATH)

func set_catalog(next_catalog: Array[Dictionary]) -> void:
	catalog = next_catalog.duplicate(true)

func set_tab(tab: String) -> void:
	active_tab = tab

func visible_catalog(global_heat_ratio: float, unlocked_towers: Array[String] = []) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for entry: Dictionary in catalog:
		var tower_id: String = str(entry.get("tower_id", ""))
		if not unlocked_towers.is_empty() and not unlocked_towers.has(tower_id):
			continue
		if active_tab == "heat_tolerant" and not _is_high_tolerance(str(entry.get("heat_tolerance", "low"))):
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
		var tolerance_score: float = 1.0 if _is_high_tolerance(str(entry.get("heat_tolerance", "low"))) else 0.4
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

func _load_catalog(path: String) -> Array[Dictionary]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var towers_variant: Variant = Dictionary(parsed).get("towers", [])
	if typeof(towers_variant) != TYPE_ARRAY:
		return []
	var parsed_array: Array = towers_variant
	var loaded: Array[Dictionary] = []
	for item: Variant in parsed_array:
		if typeof(item) == TYPE_DICTIONARY:
			loaded.append(Dictionary(item))
	return loaded

func _is_high_tolerance(label: String) -> bool:
	return label == "high" or label == "very_high"
