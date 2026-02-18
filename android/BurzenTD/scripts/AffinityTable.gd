# GODOT 4.6.1 STRICT – SINGLETON ARCHITECTURE FIXED – v0.00.6.1
extends RefCounted

class_name AffinityTable

var matrix: Dictionary = {}
var compatibility_matrix: Dictionary = {}
var thermal_penalty_gain: float = 0.40
var distance_falloff: float = 0.12
var orientation_gain: float = 0.05

static func create_default() -> AffinityTable:
	var table: AffinityTable = AffinityTable.new()
	table.matrix = {
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
	table.compatibility_matrix = {
		"nonpolar": {
			"nonpolar": 0.95,
			"polar_uncharged": 0.30,
			"positively_charged": 0.40,
			"negatively_charged": 0.40,
			"special": 0.61,
		},
		"polar_uncharged": {
			"polar_uncharged": 0.75,
			"positively_charged": 0.70,
			"negatively_charged": 0.70,
			"special": 0.59,
		},
		"positively_charged": {
			"positively_charged": 0.14,
			"negatively_charged": 0.94,
			"special": 0.62,
		},
		"negatively_charged": {
			"negatively_charged": 0.14,
			"special": 0.62,
		},
		"special": {
			"special": 0.54,
		},
	}
	return table

static func from_serialized(payload: Dictionary) -> AffinityTable:
	var table: AffinityTable = AffinityTable.new()
	table.matrix = payload.get("matrix", {}).duplicate(true)
	table.compatibility_matrix = payload.get("compatibility_matrix", {}).duplicate(true)
	table.thermal_penalty_gain = float(payload.get("thermal_penalty_gain", 0.40))
	table.distance_falloff = float(payload.get("distance_falloff", 0.12))
	table.orientation_gain = float(payload.get("orientation_gain", 0.05))
	return table

func serialize() -> Dictionary:
	return {
		"matrix": matrix.duplicate(true),
		"compatibility_matrix": compatibility_matrix.duplicate(true),
		"thermal_penalty_gain": thermal_penalty_gain,
		"distance_falloff": distance_falloff,
		"orientation_gain": orientation_gain,
	}

static func load_from_json(path: String) -> AffinityTable:
	if not FileAccess.file_exists(path):
		push_warning("AffinityTable JSON file missing at %s, using defaults." % path)
		return create_default()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("AffinityTable could not open %s, using defaults." % path)
		return create_default()

	var parse: Variant = JSON.parse_string(file.get_as_text())
	if not (parse is Dictionary):
		push_warning("AffinityTable JSON payload invalid at %s, using defaults." % path)
		return create_default()

	var payload: Dictionary = parse
	var table: AffinityTable = create_default()
	table.thermal_penalty_gain = float(payload.get("thermal_penalty_gain", table.thermal_penalty_gain))
	table.distance_falloff = float(payload.get("distance_falloff", table.distance_falloff))
	table.orientation_gain = float(payload.get("orientation_gain", table.orientation_gain))

	if payload.has("matrix"):
		table.matrix = payload.get("matrix", {}).duplicate(true)
	if payload.has("compatibility_matrix"):
		table.compatibility_matrix = payload.get("compatibility_matrix", {}).duplicate(true)

	return table

func calculate_synthesis_potential(residue_a: String, residue_b: String) -> float:
	var direct: Variant = compatibility_matrix.get(residue_a, {}).get(residue_b, null)
	if direct == null:
		direct = compatibility_matrix.get(residue_b, {}).get(residue_a, null)
	if direct != null:
		return clampf(float(direct), 0.0, 1.0)

	var pair_key: String = "%s|%s" % [residue_a, residue_b]
	var reverse_key: String = "%s|%s" % [residue_b, residue_a]
	var signed_score: float = float(matrix.get(pair_key, matrix.get(reverse_key, 0.0)))
	return clampf((signed_score + 1.0) * 0.5, 0.0, 1.0)

func evaluate_pair(left: Dictionary, right: Dictionary, diagonal: bool = false) -> Dictionary:
	var left_residue: String = str(left.get("residue_class", "special"))
	var right_residue: String = str(right.get("residue_class", "special"))
	var pair_key: String = "%s|%s" % [left_residue, right_residue]
	var reverse_key: String = "%s|%s" % [right_residue, left_residue]
	var base: float = float(matrix.get(pair_key, matrix.get(reverse_key, 0.0)))
	if base == 0.0:
		var synthesis_score: float = calculate_synthesis_potential(left_residue, right_residue)
		base = synthesis_score * 2.0 - 1.0
	var thermal_left: float = float(left.get("thermal_state", 0.0))
	var thermal_right: float = float(right.get("thermal_state", 0.0))
	var thermal_mod: float = maxf(0.0, 1.0 - ((thermal_left + thermal_right) * 0.5) * thermal_penalty_gain)
	var dx: int = absi(int(left.get("grid_x", 0)) - int(right.get("grid_x", 0)))
	var dy: int = absi(int(left.get("grid_y", 0)) - int(right.get("grid_y", 0)))
	var manhattan: int = dx + dy
	var distance_mod: float = maxf(0.0, 1.0 - max(0, manhattan - 1) * distance_falloff)
	var orientation_mod: float = 1.0 + orientation_gain if diagonal and dx == 1 and dy == 1 else 1.0
	var score: float = base * thermal_mod * distance_mod * orientation_mod
	var left_heat: float = float(left.get("normalized_heat", thermal_left))
	var right_heat: float = float(right.get("normalized_heat", thermal_right))
	score = HeatEngine.bond_strength(score, left_heat, right_heat)
	return {
		"strength": score,
		"affinity_type": "attractive" if score > 0.0 else "repulsive" if score < 0.0 else "neutral",
	}
