# GODOT 4.6.1 STRICT – DEMO CAMPAIGN v0.00.6
extends Node

class_name HeatEngine

const CONFIG_PATH: String = "res://settings/heat_config.json"

var config: Dictionary = {}
var runtime: Dictionary = {
	"difficulty": "normal",
	"global_heat_multiplier": 1.0,
	"tower_heat_tolerance_boost": 0.0,
	"cooling_efficiency": 1.0,
	"visual_heat_feedback_intensity": 1.0,
	"educational_heat_tooltips": true,
}

func _ready() -> void:
	load_config()

func load_config() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		config = _default_config()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		config = _default_config()
		return
	config = parsed

func _default_config() -> Dictionary:
	return {
		"base_heat_generation": 0.8,
		"heat_dissipation_rate": 0.35,
		"overheat_threshold": {
			"nonpolar": 65.0,
			"polar_uncharged": 45.0,
			"positively_charged": 58.0,
			"negatively_charged": 56.0,
			"special": 62.0,
		},
		"thermal_sensitivity": 0.012,
		"misfold_curve": {"low": 0.05, "medium": 0.25, "high": 0.65},
		"global_heat_multiplier": 1.0,
		"difficulty_scalars": {"easy": 0.6, "normal": 1.0, "hard": 1.65},
	}

func set_runtime_settings(next_runtime: Dictionary) -> void:
	for key: Variant in next_runtime.keys():
		runtime[str(key)] = next_runtime[key]

func apply_tower_tick(tower: Dictionary, delta: float, nearby_mob_density: float, fired: bool) -> Dictionary:
	var next_tower: Dictionary = tower.duplicate(true)
	var residue_class: String = str(next_tower.get("residue_class", "special"))
	var heat: float = float(next_tower.get("heat_score", 0.0))
	var base_generation: float = float(tower.get("heat_gen_rate", config.get("base_heat_generation", 0.8)))
	var difficulty_scalar: float = _difficulty_scalar()
	var global_multiplier: float = float(runtime.get("global_heat_multiplier", 1.0))
	var shot_gain: float = 1.0 if fired else 0.0
	var density_gain: float = maxf(0.0, nearby_mob_density)
	heat += (base_generation * (shot_gain + density_gain) * difficulty_scalar * global_multiplier) * delta
	var cooling: float = float(config.get("heat_dissipation_rate", 0.35)) * float(runtime.get("cooling_efficiency", 1.0))
	heat = maxf(0.0, heat - cooling * delta)
	var threshold: float = _threshold_for_residue(residue_class)
	var tower_tolerance: float = float(tower.get("heat_tolerance_value", 1.0))
	var tolerance_boost: float = (1.0 + float(runtime.get("tower_heat_tolerance_boost", 0.0))) * tower_tolerance
	threshold *= tolerance_boost
	var normalized_heat: float = clampf(heat / maxf(threshold, 0.001), 0.0, 2.0)
	next_tower["heat_score"] = heat
	next_tower["normalized_heat"] = normalized_heat
	next_tower["thermal_state"] = normalized_heat
	next_tower["misfold_probability"] = misfold_probability(normalized_heat)
	next_tower["is_misfolded"] = bool(next_tower.get("is_misfolded", false)) or normalized_heat >= 1.0
	if str(tower.get("tower_id", "")) == "molecular_chaperone":
		heat = maxf(0.0, heat - 0.8 * delta)
		next_tower["rescues_misfold"] = true
	return next_tower

func bond_strength(base_strength: float, left_normalized_heat: float, right_normalized_heat: float) -> float:
	var thermal_sensitivity: float = float(config.get("thermal_sensitivity", 0.012))
	var normalized_heat: float = (left_normalized_heat + right_normalized_heat) * 0.5
	var attenuated: float = 1.0 - thermal_sensitivity * normalized_heat * 100.0
	return base_strength * maxf(0.0, attenuated)

func misfold_probability(normalized_heat: float) -> float:
	var curve: Dictionary = config.get("misfold_curve", {})
	var low: float = float(curve.get("low", 0.05))
	var medium: float = float(curve.get("medium", 0.25))
	var high: float = float(curve.get("high", 0.65))
	if normalized_heat < 0.6:
		return low
	if normalized_heat < 1.0:
		return medium
	return high

func educational_tooltip(tower: Dictionary) -> String:
	if not bool(runtime.get("educational_heat_tooltips", true)):
		return ""
	var ratio: float = float(tower.get("normalized_heat", 0.0))
	if ratio < 0.6:
		return "Low thermal agitation: stable fold and strong residue binding."
	if ratio < 1.0:
		return "Thermal agitation rising: bond affinity decays and misfold risk increases."
	return "Critical heat threshold reached: denaturation-like behavior expected."

func _threshold_for_residue(residue_class: String) -> float:
	var thresholds: Dictionary = config.get("overheat_threshold", {})
	return float(thresholds.get(residue_class, thresholds.get("special", 62.0)))

func _difficulty_scalar() -> float:
	var difficulty_scalars: Dictionary = config.get("difficulty_scalars", {})
	var difficulty_key: String = str(runtime.get("difficulty", "normal"))
	return float(difficulty_scalars.get(difficulty_key, 1.0))
