# GODOT 4.6.1 STRICT – LEVEL 3 FIX v0.01.0.1
extends CanvasLayer

class_name LevelRoot

signal tower_selected(selection: Dictionary)
signal tower_info_requested(selection: Dictionary)
signal pause_pressed
signal speed_changed(multiplier: float)
signal retry_pressed
signal settings_pressed
signal settings_changed(user_settings: Dictionary)
signal start_wave_pressed
signal tower_upgrade_requested(tower_index: int)

const SPEEDS: Array[float] = [1.0, 2.0, 3.0]
const INFO_AUTO_COLLAPSE_SECONDS: float = 3.0
const USER_SETTINGS_PATH: String = "user://user_settings.json"

var speed_mode: int = 0
var global_heat_ratio: float = 0.0
var info_visible_for: float = 0.0
var prep_overlay_dismissable: bool = true
var user_settings: Dictionary = {
	"tower_viz": "Geometric",
	"show_grid_highlights": true,
	"language": "EN",
}

@onready var top_section: Control = %TopSection
@onready var tower_selection_panel: Control = %TowerSelectionPanel
@onready var wave_label: Label = %WaveLabel
@onready var heat_label: Label = %HeatLabel
@onready var heat_income_label: Label = %HeatIncomeLabel
@onready var reward_label: Label = %RewardLabel
@onready var lives_label: Label = %LivesLabel
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_button: Button = %SpeedButton
@onready var retry_button: Button = %RetryButton
@onready var settings_button: Button = %SettingsButton
@onready var prep_overlay: PanelContainer = %PrepOverlay
@onready var overlay_center: CenterContainer = %OverlayCenter
@onready var overlay_close_button: Button = %OverlayCloseButton
@onready var overlay_dismiss_layer: Control = %OverlayDismissLayer
@onready var start_wave_button: Button = %StartWaveButton
@onready var timeline_label: Label = %TimelineLabel
@onready var tower_info_panel: PanelContainer = %TowerInfoPanel
@onready var tower_info_label: RichTextLabel = %TowerInfoLabel
@onready var tower_upgrade_button: Button = %TowerUpgradeButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var viz_option_button: OptionButton = %VizOptionButton
@onready var grid_highlights_toggle: CheckButton = %GridHighlightsToggle
@onready var language_option_button: OptionButton = %LanguageOptionButton
@onready var settings_close_button: Button = %SettingsCloseButton

var current_tower_index: int = -1

func _ready() -> void:
	pause_button.pressed.connect(func() -> void: emit_signal("pause_pressed"))
	speed_button.pressed.connect(_on_speed_pressed)
	retry_button.pressed.connect(func() -> void: emit_signal("retry_pressed"))
	settings_button.pressed.connect(_on_settings_pressed)
	start_wave_button.pressed.connect(func() -> void: emit_signal("start_wave_pressed"))
	overlay_close_button.pressed.connect(_dismiss_prep_overlay)
	overlay_dismiss_layer.gui_input.connect(_on_overlay_dismiss_layer_input)
	tower_upgrade_button.pressed.connect(_on_upgrade_pressed)
	tower_selection_panel.connect("tower_card_pressed", func(selection: Dictionary) -> void: emit_signal("tower_selected", selection))
	tower_selection_panel.connect("tower_card_long_pressed", func(selection: Dictionary) -> void: emit_signal("tower_info_requested", selection))
	tower_info_panel.visible = false
	_setup_settings_ui()
	_load_user_settings()
	_apply_user_settings_to_ui()

func _process(delta: float) -> void:
	if not tower_info_panel.visible:
		return
	info_visible_for += delta
	if info_visible_for >= INFO_AUTO_COLLAPSE_SECONDS:
		hide_tower_info()

func get_arena_rect() -> Rect2:
	return top_section.get_global_rect()

func configure_towers(next_heat_ratio: float, unlocked_towers: Array[String]) -> void:
	global_heat_ratio = next_heat_ratio
	tower_selection_panel.call("set_language", str(user_settings.get("language", "EN")))
	tower_selection_panel.call("configure", next_heat_ratio, unlocked_towers)

func set_metrics(wave: int, wave_total: int, enemies_alive: int, enemies_total: int, lives: int, heat_ratio: float) -> void:
	global_heat_ratio = heat_ratio
	wave_label.text = "Wave %d/%d | %d/%d enemies" % [wave, wave_total, enemies_alive, enemies_total]
	heat_label.text = "Heat %d°C" % int(round(heat_ratio * 100.0))
	heat_income_label.text = "+%.1f/tick" % maxf(0.2, 1.2 - heat_ratio * 0.6)
	reward_label.text = "Next: +%d Heat" % (20 + wave * 5)
	lives_label.text = "Leaks %d/10" % max(lives, 0)
	if lives <= 2:
		lives_label.modulate = Color(1.0, 0.4 + 0.2 * sin(Time.get_ticks_msec() * 0.012), 0.4, 1.0)
	else:
		lives_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_wave_preview(icons_text: String, forecast: String) -> void:
	timeline_label.text = "Preview: %s\n%s" % [icons_text, forecast]

func set_status(message: String) -> void:
	status_label.text = message

func configure_pre_wave_overlay(show_overlay: bool, dismissable: bool) -> void:
	prep_overlay_dismissable = dismissable
	set_pre_wave_visible(show_overlay)
	overlay_close_button.visible = dismissable
	overlay_dismiss_layer.mouse_filter = Control.MOUSE_FILTER_STOP if dismissable else Control.MOUSE_FILTER_IGNORE

func set_pre_wave_visible(visible_state: bool) -> void:
	prep_overlay.visible = visible_state

func show_tower_info(tower_index: int, tower_data: Dictionary) -> void:
	current_tower_index = tower_index
	var heat_gen: float = float(tower_data.get("heat_gen_rate", 0.0))
	var title: String = str(tower_data.get("display_name", tower_data.get("tower_id", "Residue")))
	var pulse: String = str(tower_data.get("folding_role", "Pulse"))
	var dps: float = 47.0 * (1.0 + maxf(0.0, float(tower_data.get("heat_tolerance_value", 0.8)) - 0.7))
	var fire_rate: float = 1.0 + heat_gen * 0.25
	var range: float = float(tower_data.get("radius", 180.0))
	var upgrade_cost: int = int(round(16.0 + heat_gen * 8.0))
	tower_upgrade_button.text = "+12 DPS | +10%% Speed | Cost: %d°C" % upgrade_cost
	tower_info_label.text = "[b]%s[/b]\nDPS: %.1f\nFire Rate: %.2f\nHeat Gen: %.2f\nRange: %.0f\nSpecial: %s" % [title, dps, fire_rate, heat_gen, range, pulse]
	tower_info_panel.visible = true
	info_visible_for = 0.0

func hide_tower_info() -> void:
	tower_info_panel.visible = false
	current_tower_index = -1
	info_visible_for = 0.0

func get_user_settings() -> Dictionary:
	return user_settings.duplicate(true)

func _on_upgrade_pressed() -> void:
	if current_tower_index < 0:
		return
	emit_signal("tower_upgrade_requested", current_tower_index)
	info_visible_for = 0.0

func _on_speed_pressed() -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	speed_mode = (speed_mode + 1) % SPEEDS.size()
	var speed: float = SPEEDS[speed_mode]
	speed_button.text = "×%.0f" % speed
	emit_signal("speed_changed", speed)

func _on_settings_pressed() -> void:
	emit_signal("settings_pressed")
	settings_panel.visible = not settings_panel.visible

func _on_overlay_dismiss_layer_input(event: InputEvent) -> void:
	if not prep_overlay.visible or not prep_overlay_dismissable:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and not overlay_center.get_global_rect().has_point(mouse_event.position):
			_dismiss_prep_overlay()
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and not overlay_center.get_global_rect().has_point(touch.position):
			_dismiss_prep_overlay()

func _dismiss_prep_overlay() -> void:
	if not prep_overlay_dismissable:
		return
	prep_overlay.visible = false

func _setup_settings_ui() -> void:
	viz_option_button.clear()
	viz_option_button.add_item("Geometric")
	viz_option_button.add_item("Realistic PDB")
	viz_option_button.add_item("Custom")
	language_option_button.clear()
	language_option_button.add_item("EN")
	language_option_button.add_item("CN")
	language_option_button.add_item("RU")
	viz_option_button.item_selected.connect(_on_settings_field_changed)
	grid_highlights_toggle.toggled.connect(func(_pressed: bool) -> void: _on_settings_field_changed(0))
	language_option_button.item_selected.connect(_on_settings_field_changed)
	settings_close_button.pressed.connect(func() -> void: settings_panel.visible = false)

func _on_settings_field_changed(_index: int) -> void:
	user_settings["tower_viz"] = viz_option_button.get_item_text(viz_option_button.selected)
	user_settings["show_grid_highlights"] = grid_highlights_toggle.button_pressed
	user_settings["language"] = language_option_button.get_item_text(language_option_button.selected)
	_save_user_settings()
	emit_signal("settings_changed", get_user_settings())

func _load_user_settings() -> void:
	if not FileAccess.file_exists(USER_SETTINGS_PATH):
		return
	var settings_file: FileAccess = FileAccess.open(USER_SETTINGS_PATH, FileAccess.READ)
	if settings_file == null:
		return
	var parsed: Variant = JSON.parse_string(settings_file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	user_settings = user_settings.merged(Dictionary(parsed), true)

func _save_user_settings() -> void:
	var settings_file: FileAccess = FileAccess.open(USER_SETTINGS_PATH, FileAccess.WRITE)
	if settings_file == null:
		return
	settings_file.store_string(JSON.stringify(user_settings, "\t"))

func _apply_user_settings_to_ui() -> void:
	var viz_index: int = 0
	for i: int in range(viz_option_button.item_count):
		if viz_option_button.get_item_text(i) == str(user_settings.get("tower_viz", "Geometric")):
			viz_index = i
			break
	viz_option_button.select(viz_index)
	grid_highlights_toggle.button_pressed = bool(user_settings.get("show_grid_highlights", true))
	var lang_index: int = 0
	for i: int in range(language_option_button.item_count):
		if language_option_button.get_item_text(i) == str(user_settings.get("language", "EN")):
			lang_index = i
			break
	language_option_button.select(lang_index)
	emit_signal("settings_changed", get_user_settings())
