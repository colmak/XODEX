# GODOT 4.6.1 STRICT – MOBILE UI v0.00.7
extends Node

class_name TowerPlacementController

signal placement_preview_changed(position: Vector2)
signal placement_committed(selection: Dictionary, position: Vector2)
signal placement_canceled

var selected_tower: Dictionary = {}
var placement_mode: bool = false
var ghost_position: Vector2 = Vector2.ZERO

func start(selection: Dictionary) -> void:
	selected_tower = selection.duplicate(true)
	placement_mode = true

func cancel() -> void:
	selected_tower.clear()
	placement_mode = false
	emit_signal("placement_canceled")

func handle_input(event: InputEvent) -> void:
	if not placement_mode:
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		ghost_position = drag.position
		emit_signal("placement_preview_changed", ghost_position)
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			ghost_position = touch.position
			emit_signal("placement_preview_changed", ghost_position)
		else:
			emit_signal("placement_committed", selected_tower.duplicate(true), touch.position)
			placement_mode = false
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		ghost_position = motion.position
		emit_signal("placement_preview_changed", ghost_position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			emit_signal("placement_committed", selected_tower.duplicate(true), mb.position)
			placement_mode = false

func is_active() -> bool:
	return placement_mode
