# GODOT 4.6.1 STRICT – LEVEL 3 FIX v0.01.0.1
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
var placement_valid: bool = false
var placement_heat_delta: int = 0
var sim_time: float = 0.0
var camera_center: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0
var recommended_spots: PackedVector2Array = PackedVector2Array()
var show_grid_highlights: bool = true
var high_contrast_mode: bool = false
var color_scheme: String = "Default Dark Lab"
var heat_gradient_style: String = "Standard"
var grid_opacity: float = 0.25

var cell_size: float = 64.0

@onready var river_ribbon: Line2D = $RiverRibbon

func set_layout(viewport_size: Vector2, left_ratio: float, right_ratio: float) -> void:
	var left_width: float = viewport_size.x * left_ratio
	var right_width: float = viewport_size.x * right_ratio
	arena_rect = Rect2(left_width, 0.0, viewport_size.x - left_width - right_width, viewport_size.y)
	grid_columns = 14 if viewport_size.x > 900.0 else GRID_COLUMNS_DEFAULT
	grid_rows = 9 if viewport_size.x > 900.0 else GRID_ROWS_DEFAULT
	_update_cell_size()
	queue_redraw()

func set_rect(next_rect: Rect2) -> void:
	arena_rect = next_rect
	grid_columns = GRID_COLUMNS_DEFAULT
	grid_rows = GRID_ROWS_DEFAULT
	_update_cell_size()
	queue_redraw()

func set_camera(next_center: Vector2, next_zoom: float) -> void:
	camera_center = next_center
	camera_zoom = next_zoom

func set_recommended_spots(next_spots: PackedVector2Array) -> void:
	recommended_spots = next_spots
	queue_redraw()

func apply_user_settings(settings: Dictionary) -> void:
	show_grid_highlights = bool(settings.get("show_grid_highlights", true))
	high_contrast_mode = bool(settings.get("high_contrast_mode", false))
	color_scheme = str(settings.get("color_scheme", "Default Dark Lab"))
	heat_gradient_style = str(settings.get("heat_gradient_style", "Standard"))
	grid_opacity = clampf(float(settings.get("grid_opacity", 0.25)), 0.1, 1.0)
	queue_redraw()

func update_state(next_path: PackedVector2Array, next_towers: Array[Dictionary], next_enemies: Array[Dictionary], next_bonds: Array[Dictionary], next_floating: Array[Dictionary], next_death: Array[Dictionary], next_ghost: Vector2, is_placing: bool, is_valid_placement: bool, heat_delta: int, next_time: float) -> void:
	path_points = next_path
	towers = next_towers
	enemies = next_enemies
	tower_bonds = next_bonds
	floating_texts = next_floating
	death_vfx = next_death
	ghost_position = next_ghost
	placement_active = is_placing
	placement_valid = is_valid_placement
	placement_heat_delta = heat_delta
	sim_time = next_time
	queue_redraw()

func get_arena_rect() -> Rect2:
	return arena_rect

func snap_to_grid(world_pos: Vector2) -> Vector2:
	var safe_cell_size: float = maxf(cell_size, 1.0)
	return (world_pos / safe_cell_size).floor() * safe_cell_size + Vector2(safe_cell_size * 0.5, safe_cell_size * 0.5)

func is_point_inside_arena(point: Vector2) -> bool:
	return arena_rect.has_point(point)

func _world_to_draw(point: Vector2) -> Vector2:
	return arena_rect.get_center() + (point - camera_center) * camera_zoom

func _draw() -> void:
	var bg_color: Color = Color("0a1a2a")
	var frame_color: Color = Color("040713")
	if color_scheme == "High Viz":
		bg_color = Color("ffffff")
		frame_color = Color("e6e6e6")
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), frame_color, true)
	draw_rect(arena_rect, bg_color, true)
	_draw_grid()
	_sync_river_line()
	_draw_river_glow()
	_draw_spawn_pores()
	_draw_bonds()
	_draw_towers()
	_draw_enemies()
	if placement_active:
		var g: Vector2 = _world_to_draw(ghost_position)
		var ghost_color: Color = Color("32cd32") if placement_valid else Color("ff4500")
		ghost_color.a = 0.33
		draw_circle(g, 26.0 * camera_zoom, ghost_color)
		var cue_color: Color = Color("00ffff")
		cue_color.a = 0.4
		draw_arc(g, 175.0 * camera_zoom, 0.0, TAU, 56, cue_color, 2.0)
		draw_arc(g, 32.0 * camera_zoom, 0.0, TAU, 40, ghost_color, 4.0)
		var popup_pos: Vector2 = g + Vector2(28.0, -30.0)
		draw_string(ThemeDB.fallback_font, popup_pos, "%+d°C" % placement_heat_delta, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ghost_color)
	_draw_effects()

func _draw_grid() -> void:
	_update_cell_size()
	var cell_w: float = cell_size
	var cell_h: float = arena_rect.size.y / float(grid_rows)
	for x: int in range(grid_columns + 1):
		var px: float = arena_rect.position.x + x * cell_w
		draw_line(Vector2(px, arena_rect.position.y), Vector2(px, arena_rect.end.y), Color(0.0, 1.0, 1.0, grid_opacity), 1.0)
	for y: int in range(grid_rows + 1):
		var py: float = arena_rect.position.y + y * cell_h
		draw_line(Vector2(arena_rect.position.x, py), Vector2(arena_rect.end.x, py), Color(0.0, 1.0, 1.0, grid_opacity), 1.0)
	if show_grid_highlights:
		for point: Vector2 in recommended_spots:
			var draw_point: Vector2 = _world_to_draw(point)
			var pulse: float = 0.5 + 0.5 * sin(sim_time * 2.2 + point.x * 0.01)
			var fill_color: Color = Color("ffd700")
			fill_color.a = 0.2 + pulse * 0.1
			draw_rect(Rect2(draw_point - Vector2(cell_w * 0.45, cell_h * 0.45), Vector2(cell_w * 0.9, cell_h * 0.9)), fill_color, true)
			var spot_color: Color = Color("32cd32")
			spot_color.a = 0.35 + pulse * 0.45
			draw_rect(Rect2(draw_point - Vector2(cell_w * 0.48, cell_h * 0.48), Vector2(cell_w * 0.96, cell_h * 0.96)), spot_color, false, 2.0)
			draw_string(ThemeDB.fallback_font, draw_point + Vector2(-68.0, -8.0), "Good spot: β-sheet barrier", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e0e0e0"))

func _update_cell_size() -> void:
	cell_size = arena_rect.size.x / maxf(float(grid_columns), 1.0)

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
	river_ribbon.width = 120.0 * camera_zoom

func _draw_river_glow() -> void:
	if path_points.size() < 2:
		return
	var transformed: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in path_points:
		transformed.append(_world_to_draw(point))
	var glow_color: Color = Color("00bfff")
	glow_color.a = 0.78
	draw_polyline(transformed, glow_color, 14.0 * camera_zoom, true)

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

func _draw_towers() -> void:
	for t: Dictionary in towers:
		var p: Vector2 = _world_to_draw(Vector2(t.get("pos", Vector2.ZERO)))
		var thermal: Dictionary = Dictionary(t.get("thermal", {}))
		var heat_ratio: float = clampf(float(thermal.get("heat", 0.0)) / maxf(float(thermal.get("capacity", 100.0)), 0.001), 0.0, 1.0)
		var low_color: Color = Color("ffd700")
		var mid_color: Color = Color("ff8c00")
		var high_color: Color = Color("ff4500")
		if heat_gradient_style == "Colorblind":
			high_color = Color("4b0082")
		var base: Color = low_color.lerp(mid_color, clampf(heat_ratio * 1.2, 0.0, 1.0))
		if heat_ratio > 0.5:
			base = mid_color.lerp(high_color, clampf((heat_ratio - 0.5) * 2.0, 0.0, 1.0))
		draw_circle(p, 26.0 * camera_zoom, base)
		var target: Variant = t.get("last_target", null)
		if target != null:
			draw_line(p, _world_to_draw(Vector2(target)), Color(0.3, 0.9, 1.0, 0.65), 3.0)

func _draw_enemies() -> void:
	for enemy_data: Dictionary in enemies:
		var p: Vector2 = _world_to_draw(Vector2(enemy_data.get("pos", Vector2.ZERO)))
		draw_polygon([p + Vector2(0, -14), p + Vector2(13, 11), p + Vector2(-13, 11)], [Color(1.0, 0.28, 0.22, 1.0)])

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
