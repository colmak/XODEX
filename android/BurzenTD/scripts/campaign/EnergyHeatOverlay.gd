extends Node2D

class_name EnergyHeatOverlay

var _energy_links: Array = []
var _heat_points: Array = []
var _max_heat: float = 1.0

func update_energy_graph(energy_graph: Array) -> void:
	_energy_links = energy_graph.duplicate(true)
	queue_redraw()

func update_heat_map(heat_map: Array, heat_max: float) -> void:
	_heat_points = heat_map.duplicate(true)
	_max_heat = maxf(heat_max, 0.001)
	queue_redraw()

func _draw() -> void:
	for link: Variant in _energy_links:
		if not (link is Dictionary):
			continue
		var from_pos: Vector2 = _to_vec2(link.get("from", Vector2.ZERO))
		var to_pos: Vector2 = _to_vec2(link.get("to", Vector2.ZERO))
		var energy_flow: float = maxf(float(link.get("flow", 0.0)), 0.0)
		var width: float = 1.0 + energy_flow * 4.0
		draw_line(from_pos, to_pos, Color(0.2, 0.7, 1.0, 0.65), width, true)
	for point: Variant in _heat_points:
		if not (point is Dictionary):
			continue
		var pos: Vector2 = _to_vec2(point.get("position", Vector2.ZERO))
		var value: float = clampf(float(point.get("value", 0.0)) / _max_heat, 0.0, 1.0)
		var radius: float = lerpf(12.0, 72.0, value)
		draw_circle(pos, radius, Color(1.0, 0.5, 0.1, 0.08 + value * 0.2))

func _to_vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO
