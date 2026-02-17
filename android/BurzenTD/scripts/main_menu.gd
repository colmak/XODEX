extends Control

@onready var version_label: Label = %VersionLabel
@onready var settings_popup: PopupPanel = %SettingsPopup
@onready var volume_label: Label = %VolumeLabel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var game_speed_label: Label = %GameSpeedLabel
@onready var game_speed_slider: HSlider = %GameSpeedSlider
@onready var hud_toggle: CheckBox = %HudToggle
@onready var attack_viz_toggle: CheckBox = %AttackVizToggle
@onready var range_overlay_toggle: CheckBox = %RangeOverlayToggle
@onready var keystone_toggle: CheckBox = %KeystoneToggle
@onready var spawn_rate_label: Label = %SpawnRateLabel
@onready var spawn_rate_slider: HSlider = %SpawnRateSlider
@onready var difficulty_label: Label = %DifficultyLabel
@onready var difficulty_slider: HSlider = %DifficultySlider
@onready var debug_logs_toggle: CheckBox = %DebugLogsToggle
@onready var simulation_mode_toggle: CheckBox = %SimulationModeToggle

func _ready() -> void:
	version_label.text = "v0.00.3.0 runtime | v0.00.4.0 settings scaffold"
	_sync_ui_from_settings()

func _sync_ui_from_settings() -> void:
	var settings: Dictionary = LevelManager.get_settings()
	var general: Dictionary = settings.get("general", {})
	var tower: Dictionary = settings.get("tower", {})
	var wave: Dictionary = settings.get("wave", {})
	var advanced: Dictionary = settings.get("advanced", {})

	var volume: float = float(general.get("master_volume", 0.8))
	var game_speed: float = float(general.get("game_speed", 1.0))
	var spawn_rate: float = float(wave.get("spawn_rate_multiplier", 1.0))
	var difficulty: float = float(wave.get("difficulty_scale", 1.0))

	volume_slider.value = volume
	game_speed_slider.value = game_speed
	spawn_rate_slider.value = spawn_rate
	difficulty_slider.value = difficulty

	hud_toggle.button_pressed = bool(general.get("hud_enabled", true))
	attack_viz_toggle.button_pressed = bool(tower.get("attack_visualization", true))
	range_overlay_toggle.button_pressed = bool(tower.get("range_overlay", true))
	keystone_toggle.button_pressed = bool(tower.get("keystone_abilities", true))
	debug_logs_toggle.button_pressed = bool(advanced.get("debug_logs", false))
	simulation_mode_toggle.button_pressed = bool(advanced.get("simulation_mode", false))

	_update_slider_labels()

func _update_slider_labels() -> void:
	volume_label.text = "Master Volume: %d%%" % int(round(volume_slider.value * 100.0))
	game_speed_label.text = "Game Speed: %.2fx" % game_speed_slider.value
	spawn_rate_label.text = "Spawn Rate: %.2fx" % spawn_rate_slider.value
	difficulty_label.text = "Difficulty: %.2fx" % difficulty_slider.value

func _on_play_pressed() -> void:
	LevelManager.start_new_run()

func _on_settings_pressed() -> void:
	_sync_ui_from_settings()
	settings_popup.popup_centered()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	LevelManager.update_settings("general", "master_volume", value)
	_update_slider_labels()

func _on_game_speed_changed(value: float) -> void:
	LevelManager.update_settings("general", "game_speed", value)
	_update_slider_labels()

func _on_hud_toggled(button_pressed: bool) -> void:
	LevelManager.update_settings("general", "hud_enabled", button_pressed)

func _on_attack_viz_toggled(button_pressed: bool) -> void:
	LevelManager.update_settings("tower", "attack_visualization", button_pressed)

func _on_range_overlay_toggled(button_pressed: bool) -> void:
	LevelManager.update_settings("tower", "range_overlay", button_pressed)

func _on_keystone_toggled(button_pressed: bool) -> void:
	LevelManager.update_settings("tower", "keystone_abilities", button_pressed)

func _on_spawn_rate_changed(value: float) -> void:
	LevelManager.update_settings("wave", "spawn_rate_multiplier", value)
	_update_slider_labels()

func _on_difficulty_changed(value: float) -> void:
	LevelManager.update_settings("wave", "difficulty_scale", value)
	_update_slider_labels()

func _on_debug_logs_toggled(button_pressed: bool) -> void:
	LevelManager.update_settings("advanced", "debug_logs", button_pressed)

func _on_simulation_mode_toggled(button_pressed: bool) -> void:
	LevelManager.update_settings("advanced", "simulation_mode", button_pressed)

func _on_reset_button_pressed() -> void:
	LevelManager.reset_settings()
	_sync_ui_from_settings()

func _on_close_button_pressed() -> void:
	settings_popup.hide()
