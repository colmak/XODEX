# GODOT 4.6.1 STRICT – DEMO CAMPAIGN v0.00.6
extends Node

class_name TutorialManager

const SAVE_PATH: String = "user://demo_tutorial_progress.cfg"

var current_level_id: String = ""
var current_steps: Array[String] = []
var current_step_index: int = 0
var completed_levels: Dictionary = {}

func _ready() -> void:
	_load_progress()

func begin_level(level_id: String, steps: Array[String]) -> void:
	current_level_id = level_id
	current_steps = steps.duplicate()
	current_step_index = 0
	if is_completed(level_id):
		current_step_index = current_steps.size()

func current_step_text() -> String:
	if current_step_index >= current_steps.size():
		return ""
	return current_steps[current_step_index]

func advance_step() -> void:
	if current_step_index < current_steps.size():
		current_step_index += 1

func complete_level() -> void:
	if current_level_id.is_empty():
		return
	completed_levels[current_level_id] = true
	_save_progress()

func is_completed(level_id: String) -> bool:
	return bool(completed_levels.get(level_id, false))

func skip_level_tutorial(level_id: String) -> void:
	completed_levels[level_id] = true
	_save_progress()

func _load_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var keys: PackedStringArray = cfg.get_section_keys("tutorial")
	for key: String in keys:
		completed_levels[key] = bool(cfg.get_value("tutorial", key, false))

func _save_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: Variant in completed_levels.keys():
		cfg.set_value("tutorial", str(key), bool(completed_levels[key]))
	cfg.save(SAVE_PATH)
