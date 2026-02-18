# GODOT 4.6.1 STRICT – OPTIMIZED ARENA v0.00.8
extends CanvasLayer

class_name LeftStatusPanel

signal pause_pressed

@onready var heat_meter: TextureProgressBar = %HeatMeter
@onready var heat_label: Label = %HeatLabel
@onready var wave_label: Label = %WaveLabel
@onready var timer_label: Label = %TimerLabel
@onready var lives_label: Label = %LivesLabel
@onready var damage_label: Label = %DamageLabel
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton

func _ready() -> void:
	pause_button.pressed.connect(func() -> void: emit_signal("pause_pressed"))

func set_layout(left_width: float, viewport_height: float) -> void:
	var root: PanelContainer = get_node("LeftPanel") as PanelContainer
	root.offset_right = left_width
	root.offset_bottom = viewport_height

func set_metrics(wave: int, wave_total: int, timer_seconds: float, lives: int, heat_ratio: float, total_damage: float) -> void:
	heat_meter.value = clampf(heat_ratio * 100.0, 0.0, 100.0)
	heat_label.text = "Heat %d°C" % int(round(heat_ratio * 100.0))
	wave_label.text = "Wave %d/%d" % [wave, wave_total]
	timer_label.text = "Timer %.1fs" % maxf(timer_seconds, 0.0)
	lives_label.text = "Leaks %d" % max(lives, 0)
	damage_label.text = "Damage %d" % int(round(total_damage))

func set_status(message: String) -> void:
	status_label.text = message
