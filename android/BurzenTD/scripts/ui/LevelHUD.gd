# GODOT 4.6.1 STRICT – MOBILE UI v0.00.7
extends CanvasLayer

class_name LevelHUD

signal pause_pressed
signal speed_changed(multiplier: float)
signal tower_selected(selection: Dictionary)
signal tower_info_requested(selection: Dictionary)

@onready var wave_label: Label = %WaveLabel
@onready var heat_label: Label = %HeatLabel
@onready var lives_label: Label = %LivesLabel
@onready var damage_label: Label = %DamageLabel
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_button: Button = %SpeedButton
@onready var tower_panel: Node = %TowerSelectionPanel
@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_label: Label = %TooltipLabel

var speed_mode: int = 0
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

func _ready() -> void:
	pause_button.pressed.connect(func() -> void: emit_signal("pause_pressed"))
	speed_button.pressed.connect(_on_speed_pressed)
	tower_panel.connect("tower_card_pressed", func(selection: Dictionary) -> void: emit_signal("tower_selected", selection))
	tower_panel.connect("tower_card_long_pressed", func(selection: Dictionary) -> void: emit_signal("tower_info_requested", selection))
	tooltip_panel.visible = false

func configure_towers(global_heat_ratio: float, unlocked_towers: Array[String]) -> void:
	tower_panel.call("configure", global_heat_ratio, unlocked_towers)

func set_header(wave: int, wave_total: int, lives: int, heat_ratio: float, total_damage: float) -> void:
	wave_label.text = "Wave %d/%d" % [wave, wave_total]
	heat_label.text = "Heat %d°C" % int(round(heat_ratio * 100.0))
	lives_label.text = "Leaks %d" % max(lives, 0)
	damage_label.text = "Damage %d" % int(round(total_damage))

func set_status(message: String) -> void:
	status_label.text = message

func show_tooltip(text: String) -> void:
	tooltip_panel.visible = true
	tooltip_label.text = text

func hide_tooltip() -> void:
	tooltip_panel.visible = false

func _on_speed_pressed() -> void:
	speed_mode = (speed_mode + 1) % SPEEDS.size()
	var speed: float = SPEEDS[speed_mode]
	speed_button.text = "×%.0f" % speed
	emit_signal("speed_changed", speed)
