extends Node

const LEVEL_SCENE := "res://scenes/level_scene.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const SETTINGS_FILE := "user://burzen_settings.cfg"
const HEAT_CONFIG_PATH := "res://settings/heat_config.json"

const DEFAULT_SETTINGS := {
	"general": {
		"master_volume": 0.8,
		"game_speed": 1.0,
		"hud_enabled": true,
	},
	"tower": {
		"attack_visualization": true,
		"range_overlay": true,
		"keystone_abilities": true,
	},
	"wave": {
		"spawn_rate_multiplier": 1.0,
		"difficulty_scale": 1.0,
	},
	"heat": {
		"difficulty_preset": "normal",
		"global_heat_multiplier": 1.0,
		"tower_heat_tolerance_boost": 0.0,
		"cooling_efficiency": 1.0,
		"visual_heat_feedback_intensity": 1.0,
		"educational_heat_tooltips": true,
	},
	"advanced": {
		"debug_logs": false,
		"simulation_mode": false,
	},
}

var level_index := 0
var current_seed := 0
var settings: Dictionary = {}

func _ready() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	_load_heat_config_into_defaults()
	load_settings()
	apply_audio_settings()
	_apply_heat_runtime_settings()

func start_new_run() -> void:
	level_index = 1
	current_seed = randi()
	_load_level_scene()

func retry_level() -> void:
	_load_level_scene()

func next_level() -> void:
	level_index += 1
	current_seed = randi()
	_load_level_scene()

func return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func get_level_config() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + level_index * 101
	var pattern := int(rng.randi_range(0, 4))
	var game_settings := get_settings()
	var wave_settings: Dictionary = game_settings.get("wave", {})
	var difficulty_scale: float = float(wave_settings.get("difficulty_scale", 1.0))
	var spawn_rate_multiplier: float = float(wave_settings.get("spawn_rate_multiplier", 1.0))

	var wave_count: int = clampi(int(round((2 + level_index) * difficulty_scale)), 2, 8)
	var enemies_per_wave: int = clampi(int(round((5 + level_index * 2) * difficulty_scale)), 5, 30)
	var enemy_speed: float = (105.0 + float(level_index) * 10.0) * difficulty_scale
	var spawn_interval: float = clampf(0.8 / maxf(spawn_rate_multiplier, 0.25), 0.45, 2.0)
	var path_points := _build_path(pattern, rng)

	return {
		"level_index": level_index,
		"seed": current_seed,
		"pattern": pattern,
		"wave_count": wave_count,
		"enemies_per_wave": enemies_per_wave,
		"enemy_speed": enemy_speed,
		"spawn_interval": spawn_interval,
		"path_points": path_points,
	}

func get_settings() -> Dictionary:
	return settings.duplicate(true)

func update_settings(section: String, key: String, value) -> void:
	if not settings.has(section):
		return
	var section_data: Dictionary = settings[section]
	section_data[key] = value
	settings[section] = section_data
	apply_audio_settings()
	_apply_heat_runtime_settings()
	save_settings()

func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	apply_audio_settings()
	_apply_heat_runtime_settings()
	save_settings()

func apply_audio_settings() -> void:
	var general_settings: Dictionary = settings.get("general", {})
	var volume: float = clampf(float(general_settings.get("master_volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for section in settings.keys():
		var section_data: Dictionary = settings[section]
		for key in section_data.keys():
			cfg.set_value(section, key, section_data[key])
	cfg.save(SETTINGS_FILE)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	for section in DEFAULT_SETTINGS.keys():
		if not settings.has(section):
			settings[section] = {}
		var section_data: Dictionary = settings[section]
		var defaults: Dictionary = DEFAULT_SETTINGS[section]
		for key in defaults.keys():
			section_data[key] = cfg.get_value(section, key, defaults[key])
		settings[section] = section_data
	_apply_heat_runtime_settings()

func _load_heat_config_into_defaults() -> void:
	var file: FileAccess = FileAccess.open(HEAT_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var heat_defaults: Dictionary = settings.get("heat", {})
	heat_defaults["global_heat_multiplier"] = float(parsed.get("global_heat_multiplier", heat_defaults.get("global_heat_multiplier", 1.0)))
	settings["heat"] = heat_defaults

func _apply_heat_runtime_settings() -> void:
	if HeatEngine == null:
		return
	var heat_settings: Dictionary = settings.get("heat", {})
	HeatEngine.set_runtime_settings({
		"difficulty": str(heat_settings.get("difficulty_preset", "normal")),
		"global_heat_multiplier": float(heat_settings.get("global_heat_multiplier", 1.0)),
		"tower_heat_tolerance_boost": float(heat_settings.get("tower_heat_tolerance_boost", 0.0)),
		"cooling_efficiency": float(heat_settings.get("cooling_efficiency", 1.0)),
		"visual_heat_feedback_intensity": float(heat_settings.get("visual_heat_feedback_intensity", 1.0)),
		"educational_heat_tooltips": bool(heat_settings.get("educational_heat_tooltips", true)),
	})

func _load_level_scene() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)

func _build_path(pattern: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	match pattern:
		0:
			return _path_straight(rng)
		1:
			return _path_zigzag(rng)
		2:
			return _path_s_curve(rng)
		3:
			return _path_two_bends(rng)
		_:
			return _path_stepped(rng)

func _path_straight(rng: RandomNumberGenerator) -> PackedVector2Array:
	var mid_y: float = rng.randf_range(500.0, 780.0)
	return PackedVector2Array([
		Vector2(40.0, mid_y),
		Vector2(680.0, mid_y),
	])

func _path_zigzag(rng: RandomNumberGenerator) -> PackedVector2Array:
	var y0: float = rng.randf_range(460.0, 820.0)
	var y1: float = clampf(y0 - rng.randf_range(160.0, 240.0), 260.0, 980.0)
	var y2: float = clampf(y1 + rng.randf_range(180.0, 280.0), 260.0, 980.0)
	return PackedVector2Array([
		Vector2(40.0, y0),
		Vector2(220.0, y1),
		Vector2(430.0, y2),
		Vector2(680.0, y1),
	])

func _path_s_curve(rng: RandomNumberGenerator) -> PackedVector2Array:
	var top: float = rng.randf_range(300.0, 500.0)
	var mid: float = rng.randf_range(560.0, 760.0)
	var low: float = clampf(mid + rng.randf_range(170.0, 260.0), 760.0, 1040.0)
	return PackedVector2Array([
		Vector2(40.0, mid),
		Vector2(190.0, top),
		Vector2(360.0, mid),
		Vector2(540.0, low),
		Vector2(680.0, mid),
	])

func _path_two_bends(rng: RandomNumberGenerator) -> PackedVector2Array:
	var first: float = rng.randf_range(350.0, 560.0)
	var second: float = clampf(first + rng.randf_range(220.0, 320.0), 520.0, 980.0)
	return PackedVector2Array([
		Vector2(40.0, first),
		Vector2(170.0, first),
		Vector2(260.0, second),
		Vector2(500.0, second),
		Vector2(680.0, first),
	])

func _path_stepped(rng: RandomNumberGenerator) -> PackedVector2Array:
	var lane_a: float = rng.randf_range(360.0, 520.0)
	var lane_b: float = clampf(lane_a + rng.randf_range(170.0, 250.0), 520.0, 900.0)
	var lane_c: float = clampf(lane_b - rng.randf_range(110.0, 190.0), 360.0, 760.0)
	return PackedVector2Array([
		Vector2(40.0, lane_a),
		Vector2(170.0, lane_a),
		Vector2(300.0, lane_b),
		Vector2(450.0, lane_b),
		Vector2(570.0, lane_c),
		Vector2(680.0, lane_c),
	])
