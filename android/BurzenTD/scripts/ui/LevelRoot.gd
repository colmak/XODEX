# GODOT 4.6.1 STRICT – SYNTAX HOTFIX + VERTICAL LAYOUT LOCK v0.00.9.1
extends CanvasLayer

class_name LevelRoot

signal tower_selected(selection: Dictionary)
signal tower_info_requested(selection: Dictionary)
signal pause_pressed
signal speed_changed(multiplier: float)
signal retry_pressed
signal settings_pressed
signal start_wave_pressed

const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

var speed_mode: int = 0
var global_heat_ratio: float = 0.0

@onready var top_section: Control = %TopSection
@onready var bottom_section: Control = %BottomSection
@onready var tower_panel: Node = %TowerSelectionPanel
@onready var wave_label: Label = %WaveLabel
@onready var heat_label: Label = %HeatLabel
@onready var lives_label: Label = %LivesLabel
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_button: Button = %SpeedButton
@onready var retry_button: Button = %RetryButton
@onready var settings_button: Button = %SettingsButton
@onready var prep_overlay: PanelContainer = %PrepOverlay
@onready var start_wave_button: Button = %StartWaveButton

func _ready() -> void:
	pause_button.pressed.connect(func() -> void: emit_signal("pause_pressed"))
	speed_button.pressed.connect(_on_speed_pressed)
	retry_button.pressed.connect(func() -> void: emit_signal("retry_pressed"))
	settings_button.pressed.connect(func() -> void: emit_signal("settings_pressed"))
	start_wave_button.pressed.connect(func() -> void: emit_signal("start_wave_pressed"))
	tower_panel.connect("tower_card_pressed", func(selection: Dictionary) -> void: emit_signal("tower_selected", selection))
	tower_panel.connect("tower_card_long_pressed", func(selection: Dictionary) -> void: emit_signal("tower_info_requested", selection))

func get_arena_rect() -> Rect2:
	return top_section.get_global_rect()

func configure_towers(next_heat_ratio: float, unlocked_towers: Array[String]) -> void:
	global_heat_ratio = next_heat_ratio
	tower_panel.call("configure", next_heat_ratio, unlocked_towers)

func set_metrics(wave: int, wave_total: int, lives: int, heat_ratio: float) -> void:
	global_heat_ratio = heat_ratio
	wave_label.text = "Wave %d/%d" % [wave, wave_total]
	heat_label.text = "Heat %d°C" % int(round(heat_ratio * 100.0))
	lives_label.text = "Leaks %d" % max(lives, 0)

func set_status(message: String) -> void:
	status_label.text = message

func set_pre_wave_visible(is_visible: bool) -> void:
	prep_overlay.visible = is_visible

func _on_speed_pressed() -> void:
	speed_mode = (speed_mode + 1) % SPEEDS.size()
	var speed: float = SPEEDS[speed_mode]
	speed_button.text = "×%.0f" % speed
	emit_signal("speed_changed", speed)
