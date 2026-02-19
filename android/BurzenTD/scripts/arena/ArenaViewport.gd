# GODOT 4.6.1 STRICT – LEVEL 3 FIX v0.01.0.1
extends Node2D

class_name ArenaViewport

const GRID_COLUMNS_DEFAULT: int = 12
const GRID_ROWS_DEFAULT: int = 8
const MUTED_SAT_LIMIT: float = 0.28
const MUTED_VALUE_LIMIT: float = 0.62

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
var draw_delta: float = 0.0
var _last_sim_time: float = 0.0
var camera_center: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0
var recommended_spots: PackedVector2Array = PackedVector2Array()
var show_grid_highlights: bool = true
var high_contrast_mode: bool = false
var color_scheme: String = "Default Dark Lab"
var heat_gradient_style: String = "Standard"
var grid_opacity: float = 0.25

var cell_size: float = 64.0
var _heat_bar_display: Dictionary = {}

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
	draw_delta = maxf(0.0, next_time - _last_sim_time)
	_last_sim_time = next_time
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
	var bg_color: Color = Color("111317")
	var frame_color: Color = Color("08090b")
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
		var ghost_color: Color = Color("7f8f76") if placement_valid else Color("8f6a61")
		ghost_color.a = 0.33
		draw_circle(g, 26.0 * camera_zoom, ghost_color)
		var cue_color: Color = Color("5f696b")
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
		draw_line(Vector2(px, arena_rect.position.y), Vector2(px, arena_rect.end.y), Color(0.24, 0.30, 0.34, grid_opacity), 1.0)
	for y: int in range(grid_rows + 1):
		var py: float = arena_rect.position.y + y * cell_h
		draw_line(Vector2(arena_rect.position.x, py), Vector2(arena_rect.end.x, py), Color(0.24, 0.30, 0.34, grid_opacity), 1.0)
	if show_grid_highlights:
		for point: Vector2 in recommended_spots:
			var draw_point: Vector2 = _world_to_draw(point)
			var pulse: float = 0.5 + 0.5 * sin(sim_time * 2.2 + point.x * 0.01)
			var fill_color: Color = Color("6e6548")
			fill_color.a = 0.2 + pulse * 0.1
			draw_rect(Rect2(draw_point - Vector2(cell_w * 0.45, cell_h * 0.45), Vector2(cell_w * 0.9, cell_h * 0.9)), fill_color, true)
			var spot_color: Color = Color("6f7d68")
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
	var glow_color: Color = Color("5f6c72")
	glow_color.a = 0.42
	draw_polyline(transformed, glow_color, 10.0 * camera_zoom, true)

func _draw_spawn_pores() -> void:
	if path_points.is_empty():
		return
	var spawn: Vector2 = _world_to_draw(path_points[0])
	for i: int in range(3):
		var radius: float = 17.0 + i * 9.0 + 4.0 * sin(sim_time * 3.2 + float(i))
		draw_circle(spawn, radius * camera_zoom, Color(0.44 + 0.04 * i, 0.36 + 0.03 * i, 0.34 + 0.02 * i, 0.14))

func _draw_bonds() -> void:
	for bond: Dictionary in tower_bonds:
		var p_from: Vector2 = _world_to_draw(Vector2(bond.get("from", Vector2.ZERO)))
		var p_to: Vector2 = _world_to_draw(Vector2(bond.get("to", Vector2.ZERO)))
		var intensity: float = clampf(absf(float(bond.get("strength", 0.0))), 0.2, 1.0)
		draw_line(p_from, p_to, Color(0.50, 0.58, 0.56, 0.20 + intensity * 0.25), 2.0 + 1.2 * intensity)

func _draw_towers() -> void:
	var active_ids: Dictionary = {}
	for t: Dictionary in towers:
		var p: Vector2 = _world_to_draw(Vector2(t.get("pos", Vector2.ZERO)))
		var thermal: Dictionary = Dictionary(t.get("thermal", {}))
		var heat_ratio: float = clampf(float(thermal.get("heat", 0.0)) / maxf(float(thermal.get("capacity", 100.0)), 0.001), 0.0, 1.0)
		var tower_id: int = int(t.get("id", 0))
		active_ids[tower_id] = true
		var current_fill: float = float(_heat_bar_display.get(tower_id, heat_ratio))
		var smoothing_speed: float = maxf(4.0 * draw_delta, 0.06)
		current_fill = move_toward(current_fill, heat_ratio, smoothing_speed)
		_heat_bar_display[tower_id] = current_fill
		var low_color: Color = Color("6f6650")
		var mid_color: Color = Color("7a624f")
		var high_color: Color = Color("8a5752")
		if heat_gradient_style == "Colorblind":
			high_color = Color("6a5e78")
		var base: Color = low_color.lerp(mid_color, clampf(heat_ratio * 1.2, 0.0, 1.0))
		if heat_ratio > 0.5:
			base = mid_color.lerp(high_color, clampf((heat_ratio - 0.5) * 2.0, 0.0, 1.0))
		draw_circle(p, 26.0 * camera_zoom, base)
		draw_circle(p, 29.0 * camera_zoom, Color(0.78, 0.80, 0.78, 0.28))
		draw_arc(p, 29.0 * camera_zoom, 0.0, TAU, 36, Color(0.86, 0.88, 0.86, 0.32), 2.0, true)
		_draw_radial_heat_bar(p, current_fill, t)
		var target: Variant = t.get("last_target", null)
		if target != null:
			draw_line(p, _world_to_draw(Vector2(target)), Color(0.48, 0.56, 0.58, 0.45), 2.0)
	for key: Variant in _heat_bar_display.keys():
		if not active_ids.has(int(key)):
			_heat_bar_display.erase(key)

func _draw_radial_heat_bar(center: Vector2, heat_ratio: float, tower_data: Dictionary) -> void:
	var visuals: Dictionary = Dictionary(tower_data.get("visuals", {}))
	var thermal_visuals: Dictionary = Dictionary(visuals.get("thermal", {}))
	var radial_bar: Dictionary = Dictionary(thermal_visuals.get("radial_bar", {}))
	if not bool(radial_bar.get("enabled", true)):
		return
	var cool_color: Color = _muted_color(Color(str(radial_bar.get("cool_color", "#56666F"))))
	var stressed_color: Color = _muted_color(Color(str(radial_bar.get("stressed_color", "#7A6B59"))))
	var critical_color: Color = _muted_color(Color(str(radial_bar.get("critical_color", "#935B56"))))
	var ring_thickness: float = maxf(2.0, float(radial_bar.get("ring_thickness", 4.0)) * camera_zoom)
	var ring_radius: float = maxf(24.0, float(radial_bar.get("ring_radius", 33.0)) * camera_zoom)
	var base_opacity: float = clampf(float(radial_bar.get("opacity_min", 0.3)), 0.0, 1.0)
	var opacity: float = maxf(base_opacity, HeatVisuals.radial_opacity(heat_ratio))
	var bar_color: Color = HeatVisuals.gradient_color(heat_ratio, cool_color, stressed_color, critical_color)
	bar_color.a = opacity
	var start_angle: float = -PI * 0.5
	var sweep: float = TAU * clampf(heat_ratio, 0.0, 1.0)
	var glow_width: float = ring_thickness * (1.0 + 0.5 * heat_ratio)
	draw_arc(center, ring_radius, 0.0, TAU, 48, Color(0.55, 0.57, 0.58, 0.10), maxf(1.0, ring_thickness * 0.6), true)
	if sweep > 0.001:
		draw_arc(center, ring_radius, start_angle, start_angle + sweep, 64, bar_color, ring_thickness, true)
		var glow_color: Color = bar_color
		glow_color.a *= 0.16 + 0.18 * heat_ratio
		draw_arc(center, ring_radius + ring_thickness * 0.40, start_angle, start_angle + sweep, 64, glow_color, glow_width * 0.8, true)

func _muted_color(input_color: Color) -> Color:
	var muted_s: float = minf(input_color.s, MUTED_SAT_LIMIT)
	var muted_v: float = minf(input_color.v, MUTED_VALUE_LIMIT)
	return Color.from_hsv(input_color.h, muted_s, muted_v, input_color.a)

func _draw_enemies() -> void:
	for enemy_data: Dictionary in enemies:
		var p: Vector2 = _world_to_draw(Vector2(enemy_data.get("pos", Vector2.ZERO)))
		draw_polygon([p + Vector2(0, -14), p + Vector2(13, 11), p + Vector2(-13, 11)], [Color(0.74, 0.42, 0.38, 1.0)])

func _draw_effects() -> void:
	for entry: Dictionary in floating_texts:
		var alpha: float = 1.0 - float(entry.get("t", 0.0)) / 0.75
		var p: Vector2 = _world_to_draw(Vector2(entry.get("pos", Vector2.ZERO)))
		draw_string(ThemeDB.fallback_font, p, "-%d" % int(entry.get("amount", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.82, 0.55, 0.52, alpha))
	for fx: Dictionary in death_vfx:
		var t: float = float(fx.get("t", 0.0))
		var radius: float = lerpf(10.0, 42.0, t / 0.45)
		var alpha_fx: float = 1.0 - t / 0.45
		draw_circle(_world_to_draw(Vector2(fx.get("pos", Vector2.ZERO))), radius * camera_zoom, Color(0.46, 0.52, 0.56, alpha_fx * 0.28))
