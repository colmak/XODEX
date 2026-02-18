# GODOT 4.6.1 STRICT – SYNTAX HOTFIX + VERTICAL LAYOUT LOCK v0.00.9.1
extends Node2D

class_name ArenaViewport

const GRID_COLS: int = 10
const GRID_ROWS: int = 10
const CELL_BASE: float = 64.0

var arena_frame: Rect2 = Rect2(0.0, 0.0, 720.0, 820.0)
var arena_rect: Rect2 = Rect2(40.0, 80.0, 640.0, 640.0)
var cell_size: float = CELL_BASE

var path_points: PackedVector2Array = PackedVector2Array()
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var tower_bonds: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var death_vfx: Array[Dictionary] = []
var ghost_position: Vector2 = Vector2.ZERO
var placement_active: bool = false
var sim_time: float = 0.0

@onready var river_ribbon: Line2D = $RiverRibbon

func set_arena_frame(next_frame: Rect2) -> void:
	arena_frame = next_frame
	var max_square: float = minf(arena_frame.size.x - 16.0, arena_frame.size.y - 16.0)
	cell_size = floor(max_square / float(max(GRID_COLS, GRID_ROWS)))
	var board_size: Vector2 = Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)
	arena_rect = Rect2(arena_frame.get_center() - board_size * 0.5, board_size)
	queue_redraw()

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

func snap_to_grid(point: Vector2) -> Vector2:
	var gx: int = clampi(int(floor((point.x - arena_rect.position.x) / cell_size)), 0, GRID_COLS - 1)
	var gy: int = clampi(int(floor((point.y - arena_rect.position.y) / cell_size)), 0, GRID_ROWS - 1)
	return arena_rect.position + Vector2((float(gx) + 0.5) * cell_size, (float(gy) + 0.5) * cell_size)

func is_point_inside_arena(point: Vector2) -> bool:
	return arena_rect.has_point(point)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("030712"), true)
	draw_rect(arena_rect, Color(0.04, 0.12, 0.16, 0.95), true)
	_draw_grid()
	_sync_river_line()
	_draw_spawn_pores()
	_draw_bonds()
	_draw_towers()
	_draw_enemies()
	if placement_active:
		draw_circle(ghost_position, cell_size * 0.34, Color(0.3, 0.95, 0.82, 0.35))
	_draw_effects()

func _draw_grid() -> void:
	for x: int in range(GRID_COLS + 1):
		var px: float = arena_rect.position.x + float(x) * cell_size
		draw_line(Vector2(px, arena_rect.position.y), Vector2(px, arena_rect.end.y), Color(0.17, 0.43, 0.62, 0.45), 1.0)
	for y: int in range(GRID_ROWS + 1):
		var py: float = arena_rect.position.y + float(y) * cell_size
		draw_line(Vector2(arena_rect.position.x, py), Vector2(arena_rect.end.x, py), Color(0.17, 0.43, 0.62, 0.45), 1.0)

func _sync_river_line() -> void:
	if path_points.size() < 2:
		river_ribbon.points = PackedVector2Array()
		return
	river_ribbon.points = path_points
	river_ribbon.width = cell_size * 0.45

func _draw_spawn_pores() -> void:
	if path_points.is_empty():
		return
	var spawn: Vector2 = path_points[0]
	for i: int in range(3):
		var radius: float = cell_size * (0.18 + i * 0.14 + 0.04 * sin(sim_time * 3.0 + float(i)))
		draw_circle(spawn, radius, Color(0.84, 0.36 + 0.12 * i, 0.95, 0.22))

func _draw_bonds() -> void:
	for bond: Dictionary in tower_bonds:
		var p_from: Vector2 = Vector2(bond.get("from", Vector2.ZERO))
		var p_to: Vector2 = Vector2(bond.get("to", Vector2.ZERO))
		var intensity: float = clampf(absf(float(bond.get("strength", 0.0))), 0.2, 1.0)
		draw_line(p_from, p_to, Color(0.45, 1.0, 0.95, 0.2 + intensity * 0.5), 2.0 + intensity * 2.0)

func _draw_towers() -> void:
	for t: Dictionary in towers:
		var p: Vector2 = Vector2(t.get("pos", Vector2.ZERO))
		var tower_id: String = str(t.get("tower_id", "tower"))
		var thermal: Dictionary = Dictionary(t.get("thermal", {}))
		var heat_ratio: float = clampf(float(thermal.get("heat", 0.0)) / maxf(float(thermal.get("capacity", 100.0)), 1.0), 0.0, 1.0)
		_draw_tower_shape(tower_id, p, cell_size * 0.36, heat_ratio)
		var nameplate: String = "%s | %s | %s" % [str(t.get("display_name", "Tower")), str(t.get("display_name_zh", "")), str(t.get("display_name_ru", ""))]
		draw_string(ThemeDB.fallback_font, p + Vector2(-cell_size * 0.45, -cell_size * 0.42), nameplate, HORIZONTAL_ALIGNMENT_LEFT, cell_size * 0.9, 13, Color(0.92, 0.97, 1.0, 0.95))

func _draw_tower_shape(tower_id: String, p: Vector2, radius: float, heat_ratio: float) -> void:
	var c: Color = Color(0.2 + heat_ratio * 0.6, 0.7 - heat_ratio * 0.3, 0.95 - heat_ratio * 0.5, 1.0)
	if tower_id == "hydrophobic_anchor":
		draw_circle(p, radius, c)
	elif tower_id == "polar_hydrator":
		draw_rect(Rect2(p - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), c, true)
	elif tower_id == "cationic_defender":
		draw_polygon([p + Vector2(0, -radius), p + Vector2(radius, radius), p + Vector2(-radius, radius)], [c])
	elif tower_id == "anionic_repulsor":
		draw_polygon([p + Vector2(0, radius), p + Vector2(radius, -radius), p + Vector2(-radius, -radius)], [c])
	elif tower_id == "proline_hinge":
		draw_polygon([p + Vector2(0, -radius), p + Vector2(radius, 0), p + Vector2(0, radius), p + Vector2(-radius, 0)], [c])
	elif tower_id == "alpha_helix_pulsar":
		draw_ellipse(p, Vector2(radius * 1.2, radius * 0.72), c)
	elif tower_id == "beta_sheet_fortifier":
		draw_rect(Rect2(p - Vector2(radius * 1.15, radius * 0.7), Vector2(radius * 2.3, radius * 1.4)), c, true)
	else:
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(5):
			var ang: float = -PI * 0.5 + float(i) * TAU / 5.0
			pts.append(p + Vector2(cos(ang), sin(ang)) * radius)
		draw_colored_polygon(pts, c)

func _draw_enemies() -> void:
	for enemy_data: Dictionary in enemies:
		var p: Vector2 = Vector2(enemy_data.get("pos", Vector2.ZERO))
		draw_polygon([p + Vector2(0, -10), p + Vector2(10, 8), p + Vector2(-10, 8)], [Color("f8fafc")])

func _draw_effects() -> void:
	for entry: Dictionary in floating_texts:
		var alpha: float = 1.0 - float(entry.get("t", 0.0)) / 0.75
		draw_string(ThemeDB.fallback_font, Vector2(entry.get("pos", Vector2.ZERO)), "-%d" % int(entry.get("amount", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.35, 0.35, alpha))
	for fx: Dictionary in death_vfx:
		var t: float = float(fx.get("t", 0.0))
		var radius: float = lerpf(10.0, 36.0, t / 0.45)
		draw_circle(Vector2(fx.get("pos", Vector2.ZERO)), radius, Color(0.5, 0.9, 1.0, (1.0 - t / 0.45) * 0.4))
