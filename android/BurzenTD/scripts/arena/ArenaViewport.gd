# GODOT 4.6.1 STRICT – OPTIMIZED ARENA v0.00.8
extends Node2D

class_name ArenaViewport

const GRID_COLUMNS_DEFAULT: int = 12
const GRID_ROWS_DEFAULT: int = 8

var arena_rect: Rect2 = Rect2(160.0, 120.0, 400.0, 920.0)
var grid_columns: int = GRID_COLUMNS_DEFAULT
var grid_rows: int = GRID_ROWS_DEFAULT
var path_points: PackedVector2Array = PackedVector2Array()
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var tower_bonds: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var death_vfx: Array[Dictionary] = []
var ghost_position: Vector2 = Vector2.ZERO
var placement_active: bool = false
var sim_time: float = 0.0
var camera_center: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0

@onready var river_ribbon: Line2D = $RiverRibbon

func set_layout(viewport_size: Vector2, left_ratio: float, right_ratio: float) -> void:
	var left_width: float = viewport_size.x * left_ratio
	var right_width: float = viewport_size.x * right_ratio
	arena_rect = Rect2(left_width, 0.0, viewport_size.x - left_width - right_width, viewport_size.y)
	grid_columns = 14 if viewport_size.x > 900.0 else GRID_COLUMNS_DEFAULT
	grid_rows = 9 if viewport_size.x > 900.0 else GRID_ROWS_DEFAULT
	queue_redraw()


func set_rect(next_rect: Rect2) -> void:
	arena_rect = next_rect
	grid_columns = GRID_COLUMNS_DEFAULT
	grid_rows = GRID_ROWS_DEFAULT
	queue_redraw()

func set_camera(next_center: Vector2, next_zoom: float) -> void:
	camera_center = next_center
	camera_zoom = next_zoom

func update_state(next_path: PackedVector2Array, next_towers: Array[Dictionary], next_enemies: Array[Dictionary], next_bonds: Array[Dictionary], next_floating: Array[Dictionary], next_death: Array[Dictionary], next_ghost: Vector2, is_placing: bool, next_time: float) -> void:
	path_points = next_path
	towers = next_towers
	enemies = next_enemies
	tower_bonds = next_bonds
	floating_texts = next_floating
	death_vfx = next_death
	ghost_position = next_ghost
	placement_active = is_placing
	sim_time = next_time
	queue_redraw()

func get_arena_rect() -> Rect2:
	return arena_rect

func is_point_inside_arena(point: Vector2) -> bool:
	return arena_rect.has_point(point)

func _world_to_draw(point: Vector2) -> Vector2:
	return arena_rect.get_center() + (point - camera_center) * camera_zoom

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("040713"), true)
	draw_rect(arena_rect, Color(0.05, 0.09, 0.16, 0.94), true)
	_draw_grid()
	_sync_river_line()
	_draw_river_glow()
	_draw_spawn_pores()
	_draw_bonds()
	_draw_towers()
	_draw_enemies()
	if placement_active:
		var g: Vector2 = _world_to_draw(ghost_position)
		draw_circle(g, 26.0 * camera_zoom, Color(0.4, 0.95, 0.82, 0.33))
		draw_arc(g, 175.0 * camera_zoom, 0.0, TAU, 56, Color(0.3, 0.85, 0.75, 0.2), 2.0)
	_draw_effects()

func _draw_grid() -> void:
	var cell_w: float = arena_rect.size.x / float(grid_columns)
	var cell_h: float = arena_rect.size.y / float(grid_rows)
	for x: int in range(grid_columns + 1):
		var px: float = arena_rect.position.x + x * cell_w
		draw_line(Vector2(px, arena_rect.position.y), Vector2(px, arena_rect.end.y), Color(0.23, 0.45, 0.62, 0.2), 1.0)
	for y: int in range(grid_rows + 1):
		var py: float = arena_rect.position.y + y * cell_h
		draw_line(Vector2(arena_rect.position.x, py), Vector2(arena_rect.end.x, py), Color(0.23, 0.45, 0.62, 0.2), 1.0)
	for x: int in range(grid_columns + 1):
		for y: int in range(grid_rows + 1):
			var glow: float = 0.12 + 0.08 * sin(sim_time * 1.1 + float(x + y))
			var p: Vector2 = Vector2(arena_rect.position.x + x * cell_w, arena_rect.position.y + y * cell_h)
			draw_circle(p, 1.6, Color(0.25, 0.9, 1.0, glow))

func _sync_river_line() -> void:
	if river_ribbon == null:
		return
	if path_points.size() < 2:
		river_ribbon.points = PackedVector2Array()
		return
	var transformed: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in path_points:
		transformed.append(_world_to_draw(point))
	river_ribbon.points = transformed
	river_ribbon.width = 36.0 * camera_zoom

func _draw_river_glow() -> void:
	if path_points.size() < 2:
		return
	var transformed: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in path_points:
		transformed.append(_world_to_draw(point))
	draw_polyline(transformed, Color(0.61, 0.92, 1.0, 0.45), 8.0 * camera_zoom, true)

func _draw_spawn_pores() -> void:
	if path_points.is_empty():
		return
	var spawn: Vector2 = _world_to_draw(path_points[0])
	for i: int in range(3):
		var radius: float = 17.0 + i * 9.0 + 4.0 * sin(sim_time * 3.2 + float(i))
		draw_circle(spawn, radius * camera_zoom, Color(0.9, 0.35 + 0.15 * i, 0.95, 0.17))

func _draw_bonds() -> void:
	for bond: Dictionary in tower_bonds:
		var p_from: Vector2 = _world_to_draw(Vector2(bond.get("from", Vector2.ZERO)))
		var p_to: Vector2 = _world_to_draw(Vector2(bond.get("to", Vector2.ZERO)))
		var intensity: float = clampf(absf(float(bond.get("strength", 0.0))), 0.2, 1.0)
		draw_line(p_from, p_to, Color(0.45, 1.0, 0.95, 0.25 + intensity * 0.45), 2.0 + 2.0 * intensity)
		var pulse: float = 0.5 + 0.5 * sin(sim_time * 5.2 + p_from.distance_to(p_to) * 0.02)
		var pulse_pos: Vector2 = p_from.lerp(p_to, pulse)
		draw_circle(pulse_pos, 3.2 * camera_zoom, Color(0.65, 1.0, 0.95, 0.75))

func _draw_towers() -> void:
	for t: Dictionary in towers:
		var p: Vector2 = _world_to_draw(Vector2(t.get("pos", Vector2.ZERO)))
		var tower_id: String = str(t.get("tower_id", "tower"))
		var thermal: Dictionary = Dictionary(t.get("thermal", {}))
		var heat_ratio: float = clampf(float(thermal.get("heat", 0.0)) / maxf(float(thermal.get("capacity", 100.0)), 0.001), 0.0, 1.0)
		var base: Color = Color(0.2 + heat_ratio * 0.8, 0.5 + (1.0 - heat_ratio) * 0.35, 1.0 - heat_ratio * 0.65, 1.0)
		draw_circle(p + Vector2(0, 8), 23.0 * camera_zoom, Color(0.0, 0.0, 0.0, 0.2))
		if bool(thermal.get("overheated", false)):
			base = Color(1.0, 0.22, 0.16, 1.0)
		var idle_scale: float = 1.0 + 0.06 * sin(sim_time * 1.8 + float(t.get("id", 0)))
		draw_circle(p, 26.0 * idle_scale * camera_zoom, base)
		_draw_tower_signature(tower_id, p, camera_zoom)
		var target: Variant = t.get("last_target", null)
		if target != null:
			draw_line(p, _world_to_draw(Vector2(target)), Color(1.0, 0.45, 0.38, 0.6), 3.0)

func _draw_tower_signature(tower_id: String, p: Vector2, scale_factor: float) -> void:
	if tower_id.contains("hydrophobic"):
		draw_arc(p, 15.0 * scale_factor, 0.0, TAU, 24, Color(1.0, 0.88, 0.25, 0.65), 2.0)
	elif tower_id.contains("alpha_helix"):
		for i: int in range(3):
			var r: float = 8.0 + i * 4.0
			draw_arc(p + Vector2(0, i * 3), r * scale_factor, sim_time + i, sim_time + i + PI * 1.25, 18, Color(0.78, 0.52, 1.0, 0.6), 2.0)
	elif tower_id.contains("beta_sheet"):
		draw_rect(Rect2(p - Vector2(11, 8) * scale_factor, Vector2(22, 16) * scale_factor), Color(0.6, 0.9, 1.0, 0.3), true)
	else:
		draw_circle(p, 8.0 * scale_factor, Color(0.85, 1.0, 0.9, 0.35))

func _draw_enemies() -> void:
	for enemy_data: Dictionary in enemies:
		var p: Vector2 = _world_to_draw(Vector2(enemy_data.get("pos", Vector2.ZERO)))
		draw_polygon([p + Vector2(0, -12), p + Vector2(12, 10), p + Vector2(-12, 10)], [Color("f8fafc")])
		var hp_ratio: float = clampf(float(enemy_data.get("hp", 0.0)) / maxf(float(enemy_data.get("max_hp", 1.0)), 0.001), 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(-16, -22), Vector2(32.0 * hp_ratio, 4)), Color(1.0 - hp_ratio, hp_ratio, 0.2, 1.0), true)

func _draw_effects() -> void:
	for entry: Dictionary in floating_texts:
		var alpha: float = 1.0 - float(entry.get("t", 0.0)) / 0.75
		var p: Vector2 = _world_to_draw(Vector2(entry.get("pos", Vector2.ZERO)))
		draw_string(ThemeDB.fallback_font, p, "-%d" % int(entry.get("amount", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.35, 0.35, alpha))
	for fx: Dictionary in death_vfx:
		var t: float = float(fx.get("t", 0.0))
		var radius: float = lerpf(10.0, 42.0, t / 0.45)
		var alpha_fx: float = 1.0 - t / 0.45
		draw_circle(_world_to_draw(Vector2(fx.get("pos", Vector2.ZERO))), radius * camera_zoom, Color(0.5, 0.9, 1.0, alpha_fx * 0.4))
