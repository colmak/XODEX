# GODOT 4.6.1 STRICT – OPTIMIZED ARENA v0.00.8
extends CanvasLayer

class_name RightSelectionPanel

signal tower_selected(selection: Dictionary)
signal tower_info_requested(selection: Dictionary)
signal speed_changed(multiplier: float)
signal retry_pressed
signal optimize_pressed(selection: Dictionary)

const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

var speed_mode: int = 0
var global_heat_ratio: float = 0.0

@onready var tower_panel: Node = %TowerSelectionPanel
@onready var speed_button: Button = %SpeedButton
@onready var optimize_button: Button = %OptimizeButton
@onready var retry_button: Button = %RetryButton

func _ready() -> void:
	tower_panel.connect("tower_card_pressed", func(selection: Dictionary) -> void: emit_signal("tower_selected", selection))
	tower_panel.connect("tower_card_long_pressed", func(selection: Dictionary) -> void: emit_signal("tower_info_requested", selection))
	speed_button.pressed.connect(_on_speed_pressed)
	retry_button.pressed.connect(func() -> void: emit_signal("retry_pressed"))
	optimize_button.pressed.connect(_on_optimize_pressed)

func set_layout(right_width: float, viewport_size: Vector2) -> void:
	var panel: PanelContainer = get_node("RightPanel") as PanelContainer
	panel.offset_left = viewport_size.x - right_width
	panel.offset_bottom = viewport_size.y
	panel.offset_right = viewport_size.x

func configure_towers(next_heat_ratio: float, unlocked_towers: Array[String]) -> void:
	global_heat_ratio = next_heat_ratio
	tower_panel.call("configure", next_heat_ratio, unlocked_towers)

func set_global_heat_ratio(next_heat_ratio: float) -> void:
	global_heat_ratio = next_heat_ratio

func _on_speed_pressed() -> void:
	speed_mode = (speed_mode + 1) % SPEEDS.size()
	var speed: float = SPEEDS[speed_mode]
	speed_button.text = "×%.0f" % speed
	emit_signal("speed_changed", speed)

func _on_optimize_pressed() -> void:
	var module_obj: Variant = tower_panel.get("module")
	if module_obj == null:
		return
	var candidate: Dictionary = (module_obj as Object).call("optimize_for_current_heat", global_heat_ratio)
	if candidate.is_empty():
		return
	emit_signal("optimize_pressed", candidate)
