# GODOT 4.6.1 STRICT – NORMALIZED DECISION ENGINE v0.01.0
extends Control

const TOP_BAR_HEIGHT: float = 40.0
const ARENA_RATIO: float = 0.70
const COLLAPSED_HEIGHT: float = 88.0
const GRID_COLS: int = 12
const GRID_ROWS: int = 8
const PATH_WIDTH: float = 100.0
const EDGE_PADDING_RATIO: float = 0.10
const SNAP_FORGIVENESS: float = 32.0
const RECOMMENDED_SPOTS: int = 5

@onready var wave_info_label: Label = %WaveInfoLabel
@onready var heat_label: Label = %HeatLabel
@onready var leaks_label: Label = %LeaksLabel
@onready var bottom_panel: PanelContainer = %BottomPanel
@onready var panel_toggle_button: Button = %PanelToggleButton
@onready var placement_hint_label: Label = %PlacementHintLabel
@onready var cards_grid: GridContainer = %CardsGrid
@onready var tower_info_label: Label = %TowerInfoLabel
@onready var speed_button: Button = %SpeedButton
@onready var collapse_timer: Timer = %CollapseTimer

var heat: float = 100.0
var heat_tick: float = 0.8
var leaks: int = 0
var leak_limit: int = 10
var wave: int = 1
var wave_total: int = 4
var enemies_per_wave: int = 20
var enemies_defeated: int = 0
var is_paused: bool = false
var game_speed: int = 1
var panel_expanded: bool = true
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var tower_catalog: Array[Dictionary] = [
	{"id": "triangle", "label": "△ Triangle", "dps": 12.0, "rate": 1.5, "heat_cost": 12.0, "range": 132.0, "effect": "Pulse", "residue": "nonpolar", "recommendation": "Good for core bond"},
	{"id": "square", "label": "▢ Square", "dps": 10.0, "rate": 1.2, "heat_cost": 10.0, "range": 118.0, "effect": "Wall", "residue": "nonpolar", "recommendation": "β-sheet wall"},
	{"id": "rectangle", "label": "▭ Rectangle", "dps": 9.0, "rate": 1.0, "heat_cost": 9.0, "range": 140.0, "effect": "Lane", "residue": "nonpolar", "recommendation": "Long arc"},
	{"id": "fire", "label": "火 Fire", "dps": 11.0, "rate": 1.1, "heat_cost": 11.0, "range": 122.0, "effect": "Burn", "residue": "charged+", "recommendation": "Hot bend"},
	{"id": "water", "label": "水 Water", "dps": 8.0, "rate": 0.9, "heat_cost": 8.0, "range": 136.0, "effect": "Slow", "residue": "polar", "recommendation": "Cold seam"},
	{"id": "earth", "label": "土 Earth", "dps": 10.0, "rate": 1.4, "heat_cost": 10.0, "range": 108.0, "effect": "Break", "residue": "special", "recommendation": "Dense corner"},
	{"id": "air", "label": "风 Air", "dps": 9.0, "rate": 0.8, "heat_cost": 9.0, "range": 146.0, "effect": "Knock", "residue": "charged-", "recommendation": "Fast lane"},
	{"id": "keystone", "label": "Ж Keystone", "dps": 7.0, "rate": 1.8, "heat_cost": 7.0, "range": 150.0, "effect": "Buff", "residue": "special", "recommendation": "Anchor nexus"},
]

var path_points: PackedVector2Array = PackedVector2Array()
var valid_spots: Array[Vector2] = []
var recommended_spots: Array[Vector2] = []
var placed_towers: Array[Dictionary] = []

var selected_tower_id: String = ""
var dragging: bool = false
var drag_pointer: Vector2 = Vector2.ZERO

func _ready() -> void:
	rng.randomize()
	_assign_card_metadata()
	_generate_centered_map()
	_apply_bottom_layout()
	_update_labels()
	placement_hint_label.text = "Drag a tower card onto highlighted spots."
	collapse_timer.start()

func _process(delta: float) -> void:
	if is_paused:
		return
	heat += heat_tick * delta * float(game_speed)
	_update_labels()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_generate_centered_map()
		_apply_bottom_layout()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_user_action()
			if _try_begin_drag(event.position):
				return
			if _try_select_or_sell_tower(event.position):
				return
		else:
			if dragging:
				_try_place_dragged_tower(event.position)
				dragging = false
				queue_redraw()
	if event is InputEventMouseMotion:
		drag_pointer = event.position
		if dragging:
			queue_redraw()

func _assign_card_metadata() -> void:
	for idx: int in range(cards_grid.get_child_count()):
		var button: Button = cards_grid.get_child(idx) as Button
		if button == null or idx >= tower_catalog.size():
			continue
		var entry: Dictionary = tower_catalog[idx]
		button.set_meta("tower_id", entry["id"])
		button.text = str(entry["label"])

func _try_begin_drag(pointer: Vector2) -> bool:
	for card_node: Node in cards_grid.get_children():
		var button: Button = card_node as Button
		if button == null:
			continue
		if button.get_global_rect().has_point(pointer):
			selected_tower_id = str(button.get_meta("tower_id", ""))
			dragging = true
			drag_pointer = pointer
			placement_hint_label.text = "Dragging %s…" % _tower_entry(selected_tower_id).get("label", "Tower")
			_haptic(20)
			return true
	return false

func _try_select_or_sell_tower(pointer: Vector2) -> bool:
	for idx: int in range(placed_towers.size()):
		var tower_data: Dictionary = placed_towers[idx]
		if Vector2(tower_data["pos"]).distance_to(pointer) <= 22.0:
			var refund: float = float(tower_data["heat_cost"]) * 0.9
			heat += refund
			tower_info_label.text = "%s sold: +%.1f°C refund (90%%)." % [tower_data["label"], refund]
			placed_towers.remove_at(idx)
			_haptic(18)
			_update_labels()
			queue_redraw()
			return true
	return false

func _try_place_dragged_tower(pointer: Vector2) -> void:
	var arena: Rect2 = _arena_rect()
	if not arena.has_point(pointer):
		placement_hint_label.text = "Placement cancelled: outside arena."
		return
	var spot: Vector2 = _closest_spot(pointer)
	if spot == Vector2.INF:
		placement_hint_label.text = "Invalid spot. Follow highlighted grid cells."
		_haptic(8)
		return
	for tower_data: Dictionary in placed_towers:
		if Vector2(tower_data["pos"]).distance_to(spot) < 4.0:
			placement_hint_label.text = "Spot occupied."
			_haptic(8)
			return
	var entry: Dictionary = _tower_entry(selected_tower_id)
	if entry.is_empty():
		placement_hint_label.text = "No tower selected."
		return
	var cost: float = float(entry["heat_cost"])
	if heat < cost:
		placement_hint_label.text = "Not enough Heat for %s." % entry["label"]
		_haptic(8)
		return
	heat -= cost
	placed_towers.append({
		"id": selected_tower_id,
		"label": entry["label"],
		"pos": spot,
		"range": entry["range"],
		"dps": entry["dps"],
		"rate": entry["rate"],
		"heat_cost": cost,
		"effect": entry["effect"],
	})
	tower_info_label.text = "%s | DPS: %d | Rate: %.1fs | Heat: +%d°C | Effect: %s" % [
		entry["label"],
		int(entry["dps"]),
		float(entry["rate"]),
		int(entry["heat_cost"]),
		entry["effect"],
	]
	placement_hint_label.text = "Placed %s." % entry["label"]
	_haptic(28)
	_update_labels()
	queue_redraw()

func _arena_rect() -> Rect2:
	var arena_height: float = size.y * ARENA_RATIO - TOP_BAR_HEIGHT
	return Rect2(0.0, TOP_BAR_HEIGHT, size.x, maxf(100.0, arena_height))

func _generate_centered_map() -> void:
	var arena: Rect2 = _arena_rect()
	var pad_x: float = arena.size.x * EDGE_PADDING_RATIO
	var pad_y: float = arena.size.y * EDGE_PADDING_RATIO
	var left: float = arena.position.x + pad_x
	var right: float = arena.end.x - pad_x
	var top_y: float = arena.position.y + pad_y
	var bottom_y: float = arena.end.y - pad_y
	var center_x: float = arena.get_center().x

	path_points = PackedVector2Array()
	path_points.append(Vector2(center_x, top_y))
	for i: int in range(1, 5):
		var t: float = float(i) / 5.0
		var y: float = lerpf(top_y, bottom_y, t)
		var offset: float = rng.randf_range(-arena.size.x * 0.20, arena.size.x * 0.20)
		var x: float = clampf(center_x + offset, left + 48.0, right - 48.0)
		path_points.append(Vector2(x, y))
	path_points.append(Vector2(center_x, bottom_y))
	
	valid_spots.clear()
	recommended_spots.clear()
	var cell_w: float = (right - left) / float(GRID_COLS)
	var cell_h: float = (bottom_y - top_y) / float(GRID_ROWS)
	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLS):
			var p: Vector2 = Vector2(left + (float(col) + 0.5) * cell_w, top_y + (float(row) + 0.5) * cell_h)
			if _distance_to_path(p) >= (PATH_WIDTH * 0.5 + 18.0):
				valid_spots.append(p)
	valid_spots.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return _distance_to_path(a) < _distance_to_path(b)
	)
	for i: int in range(min(RECOMMENDED_SPOTS, valid_spots.size())):
		recommended_spots.append(valid_spots[i])
	queue_redraw()

func _closest_spot(pointer: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for spot: Vector2 in valid_spots:
		var d: float = spot.distance_to(pointer)
		if d < best_d:
			best_d = d
			best = spot
	if best_d > SNAP_FORGIVENESS:
		return Vector2.INF
	return best

func _distance_to_path(point: Vector2) -> float:
	var closest: float = INF
	for i: int in range(path_points.size() - 1):
		var projected: Vector2 = Geometry2D.get_closest_point_to_segment(point, path_points[i], path_points[i + 1])
		closest = minf(closest, point.distance_to(projected))
	return closest

func _update_labels() -> void:
	wave_info_label.text = "Wave %d/%d | Enemies: %d/%d | Next: ▲ ●" % [wave, wave_total, enemies_defeated, enemies_per_wave]
	heat_label.text = "Heat: %.1f°C (+%.1f/tick)" % [heat, heat_tick]
	leaks_label.text = "Leaks: %d/%d" % [leaks, leak_limit]

func _tower_entry(tower_id: String) -> Dictionary:
	for entry: Dictionary in tower_catalog:
		if str(entry["id"]) == tower_id:
			return entry
	return {}

func _apply_bottom_layout() -> void:
	var target_height: float = size.y * (1.0 - ARENA_RATIO)
	if not panel_expanded:
		target_height = COLLAPSED_HEIGHT
	bottom_panel.offset_top = -target_height

func _on_user_action() -> void:
	if panel_expanded:
		collapse_timer.start()

func _on_panel_toggle_pressed() -> void:
	panel_expanded = not panel_expanded
	panel_toggle_button.text = "▼ Towers" if panel_expanded else "▲ Towers"
	_apply_bottom_layout()

func _on_pause_pressed() -> void:
	is_paused = not is_paused

func _on_speed_pressed() -> void:
	game_speed = 2 if game_speed == 1 else 1
	speed_button.text = "%dx" % game_speed

func _on_retry_pressed() -> void:
	placed_towers.clear()
	heat = 100.0
	leaks = 0
	enemies_defeated = 0
	wave = 1
	_generate_centered_map()
	tower_info_label.text = "Map regenerated. Recommendations refreshed."
	placement_hint_label.text = "3–5 recommended spots highlighted for pre-wave."
	_haptic(16)
	_update_labels()

func _on_collapse_timer_timeout() -> void:
	if panel_expanded:
		panel_expanded = false
		panel_toggle_button.text = "▲ Towers"
		_apply_bottom_layout()

func _haptic(duration_ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)

func _draw() -> void:
	var arena: Rect2 = _arena_rect()
	draw_rect(arena, Color("0a1a2a"), true)

	var pad_x: float = arena.size.x * EDGE_PADDING_RATIO
	var pad_y: float = arena.size.y * EDGE_PADDING_RATIO
	var grid_rect: Rect2 = Rect2(arena.position.x + pad_x, arena.position.y + pad_y, arena.size.x - pad_x * 2.0, arena.size.y - pad_y * 2.0)
	for col: int in range(GRID_COLS + 1):
		var x: float = grid_rect.position.x + grid_rect.size.x * float(col) / float(GRID_COLS)
		draw_line(Vector2(x, grid_rect.position.y), Vector2(x, grid_rect.end.y), Color(0.0, 0.9, 1.0, 0.15), 1.0)
	for row: int in range(GRID_ROWS + 1):
		var y: float = grid_rect.position.y + grid_rect.size.y * float(row) / float(GRID_ROWS)
		draw_line(Vector2(grid_rect.position.x, y), Vector2(grid_rect.end.x, y), Color(0.0, 0.9, 1.0, 0.15), 1.0)

	if path_points.size() > 1:
		draw_polyline(path_points, Color(0.0, 0.95, 1.0, 0.82), PATH_WIDTH, true)
		draw_polyline(path_points, Color(0.6, 1.0, 1.0, 0.95), 8.0, true)

	for spot: Vector2 in valid_spots:
		draw_circle(spot, 4.0, Color(0.6, 1.0, 1.0, 0.22))
	for spot: Vector2 in recommended_spots:
		draw_circle(spot, 11.0, Color(0.2, 1.0, 0.4, 0.4))
		draw_circle(spot, 5.0, Color(0.4, 1.0, 0.6, 0.9))

	for tower_data: Dictionary in placed_towers:
		var pos: Vector2 = tower_data["pos"]
		draw_circle(pos, 16.0, Color(0.95, 0.95, 1.0, 0.95))
		draw_arc(pos, float(tower_data["range"]), 0.0, TAU, 52, Color(0.5, 1.0, 0.5, 0.23), 2.0)

	if dragging:
		var ghost_spot: Vector2 = _closest_spot(drag_pointer)
		var entry: Dictionary = _tower_entry(selected_tower_id)
		if not entry.is_empty() and ghost_spot != Vector2.INF:
			var color: Color = Color(0.4, 1.0, 0.4, 0.65)
			draw_circle(ghost_spot, 18.0, color)
			draw_arc(ghost_spot, float(entry["range"]), 0.0, TAU, 52, Color(0.4, 1.0, 0.4, 0.28), 2.0)
		else:
			draw_circle(drag_pointer, 14.0, Color(1.0, 0.3, 0.3, 0.55))
