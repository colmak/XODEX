# GODOT 4.6.1 STRICT – DECISION ENGINE UI v0.01.0
extends CanvasLayer

class_name LevelRoot

signal tower_selected(selection: Dictionary)
signal tower_info_requested(selection: Dictionary)
signal pause_pressed
signal speed_changed(multiplier: float)
signal retry_pressed
signal settings_pressed
signal start_wave_pressed
signal tower_upgrade_requested(tower_index: int)

const SPEEDS: Array[float] = [1.0, 2.0, 3.0]
const INFO_AUTO_COLLAPSE_SECONDS: float = 3.0

var speed_mode: int = 0
var global_heat_ratio: float = 0.0
var info_visible_for: float = 0.0

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
@onready var start_wave_button: Button = %StartWaveButton
@onready var timeline_label: Label = %TimelineLabel
@onready var tower_info_panel: PanelContainer = %TowerInfoPanel
@onready var tower_info_label: RichTextLabel = %TowerInfoLabel
@onready var tower_upgrade_button: Button = %TowerUpgradeButton

var current_tower_index: int = -1

func _ready() -> void:
	pause_button.pressed.connect(func() -> void: emit_signal("pause_pressed"))
	speed_button.pressed.connect(_on_speed_pressed)
	retry_button.pressed.connect(func() -> void: emit_signal("retry_pressed"))
	settings_button.pressed.connect(func() -> void: emit_signal("settings_pressed"))
	start_wave_button.pressed.connect(func() -> void: emit_signal("start_wave_pressed"))
	tower_upgrade_button.pressed.connect(_on_upgrade_pressed)
	tower_selection_panel.connect("tower_card_pressed", func(selection: Dictionary) -> void: emit_signal("tower_selected", selection))
	tower_selection_panel.connect("tower_card_long_pressed", func(selection: Dictionary) -> void: emit_signal("tower_info_requested", selection))
	tower_info_panel.visible = false

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
