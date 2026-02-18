# GODOT 4.6.1 STRICT – OPTIMIZED ARENA v0.00.8
extends Node

class_name ArenaCamera2D

const MIN_ZOOM: float = 0.8
const MAX_ZOOM: float = 1.6
const FOLLOW_LERP: float = 4.2

var zoom_factor: float = 1.0
var center: Vector2 = Vector2.ZERO
var _touch_points: Dictionary = {}
var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 1.0

func reset(arena_center: Vector2) -> void:
	center = arena_center
	zoom_factor = 1.0
	_touch_points.clear()
	_pinch_start_distance = 0.0
	_pinch_start_zoom = 1.0

func consume_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		var gesture: InputEventMagnifyGesture = event
		zoom_factor = clampf(zoom_factor / maxf(gesture.factor, 0.001), MIN_ZOOM, MAX_ZOOM)
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_touch_points[touch.index] = touch.position
		else:
			_touch_points.erase(touch.index)
		if _touch_points.size() < 2:
			_pinch_start_distance = 0.0
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if _touch_points.has(drag.index):
			_touch_points[drag.index] = drag.position
	if _touch_points.size() >= 2:
		var keys: Array = _touch_points.keys()
		var a: Vector2 = _touch_points[keys[0]]
		var b: Vector2 = _touch_points[keys[1]]
		var current_distance: float = a.distance_to(b)
		if _pinch_start_distance <= 0.0:
			_pinch_start_distance = current_distance
			_pinch_start_zoom = zoom_factor
		else:
			var ratio: float = _pinch_start_distance / maxf(current_distance, 0.001)
			zoom_factor = clampf(_pinch_start_zoom * ratio, MIN_ZOOM, MAX_ZOOM)

func update_follow(delta: float, towers: Array[Dictionary], arena_rect: Rect2) -> void:
	var desired: Vector2 = arena_rect.get_center()
	if not towers.is_empty():
		var sum: Vector2 = Vector2.ZERO
		for entry: Dictionary in towers:
			sum += Vector2(entry.get("pos", desired))
		desired = sum / float(towers.size())
	center = center.lerp(desired, clampf(delta * FOLLOW_LERP, 0.0, 1.0))
