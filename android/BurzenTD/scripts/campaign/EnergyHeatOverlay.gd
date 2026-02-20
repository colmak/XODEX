extends Node2D

class_name EnergyHeatOverlay

var energy_edges: Array[Dictionary] = []
var heat_points: Array[Dictionary] = []

func update_energy_overlay(next_edges: Array) -> void:
	energy_edges.clear()
	for edge: Variant in next_edges:
		if edge is Dictionary:
			energy_edges.append(edge)
	queue_redraw()

func update_heat_overlay(next_heat: Array) -> void:
	heat_points.clear()
	for point: Variant in next_heat:
		if point is Dictionary:
			heat_points.append(point)
	queue_redraw()

func _draw() -> void:
	for edge: Dictionary in energy_edges:
		var from_pos: Vector2 = edge.get("from", Vector2.ZERO)
		var to_pos: Vector2 = edge.get("to", Vector2.ZERO)
		var magnitude: float = clampf(float(edge.get("flow", 0.0)), 0.0, 1.0)
		var width: float = lerpf(1.0, 8.0, magnitude)
		draw_line(from_pos, to_pos, Color(0.25, 0.6, 1.0, 0.4 + (magnitude * 0.6)), width)

	for source: Dictionary in heat_points:
		var pos: Vector2 = source.get("pos", Vector2.ZERO)
		var heat: float = clampf(float(source.get("value", 0.0)), 0.0, 1.0)
		var radius: float = lerpf(12.0, 72.0, heat)
		draw_circle(pos, radius, Color(1.0, 0.32, 0.1, 0.08 + (heat * 0.2)))
