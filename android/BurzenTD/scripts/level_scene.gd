# GODOT 4.6.1 STRICT – DECISION ENGINE UI v0.01.0
extends Node2D

const MAX_TOWERS: int = 12
const ENEMY_SPAWN_INTERVAL: float = 0.8
const TWO_FINGER_WINDOW: float = 0.18
const PATH_SAFE_DISTANCE: float = 48.0
const BASE_DAMAGE: float = 47.0
const DAMAGE_TEXT_LIFETIME: float = 0.75
const LEFT_PANEL_RATIO: float = 0.0
const RIGHT_PANEL_RATIO: float = 0.0
const ARENA_PADDING_RATIO: float = 0.11

const THERMAL_DEFAULT: Dictionary = {
	"capacity": 100.0,
	"heat_per_shot": 18.0,
	"dissipation_rate": 14.0,
	"recovery_ratio": 0.45,
}

const ARENA_VIEWPORT_SCENE: PackedScene = preload("res://scenes/ArenaViewport.tscn")
const LEVEL_ROOT_SCENE: PackedScene = preload("res://ui/level_root.tscn")
const LEVEL_COMPLETE_SCENE: PackedScene = preload("res://ui/level_complete.tscn")

var arena_viewport: ArenaViewport
var arena_camera: ArenaCamera2D
var level_root: LevelRoot
var complete_screen: LevelCompleteScreen
var placement_controller: TowerPlacementController

var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var tower_bonds: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var death_vfx: Array[Dictionary] = []

var spawn_timer: float = 0.0
var active_touch_count: int = 0
var two_finger_timer: float = -1.0
var ghost_position: Vector2 = Vector2.ZERO
var sim_time: float = 0.0

var game_state: String = "prep"
var path_points: PackedVector2Array = PackedVector2Array()
var path_lengths: Array[float] = []
var total_path_length: float = 0.0

var wave_index: int = 1
var wave_count: int = 3
var enemies_per_wave: int = 6
var enemies_spawned_in_wave: int = 0
var enemy_speed: float = 120.0
var enemy_spawn_interval: float = ENEMY_SPAWN_INTERVAL
var lives: int = 3
var peak_heat: float = 0.0
var free_energy_threshold: float = 0.6
var minimum_bonds: int = 2
var level_id: String = ""
var unlocked_towers: Array[String] = []
var game_speed: float = 1.0
var placement_valid: bool = false
var recommended_spots: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SingletonGuard.assert_singleton_ready("TutorialManager", "LevelScene._ready")
	SingletonGuard.assert_singleton_ready("HeatEngine", "LevelScene._ready")
	SingletonGuard.assert_singleton_ready("DamageTracker", "LevelScene._ready")
	arena_viewport = ARENA_VIEWPORT_SCENE.instantiate() as ArenaViewport
	add_child(arena_viewport)
	arena_camera = ArenaCamera2D.new()
	add_child(arena_camera)
	level_root = LEVEL_ROOT_SCENE.instantiate() as LevelRoot
	add_child(level_root)
	level_root.pause_pressed.connect(_toggle_pause)
	level_root.speed_changed.connect(func(multiplier: float) -> void: game_speed = multiplier)
	level_root.retry_pressed.connect(func() -> void: LevelManager.retry_level())
	level_root.tower_selected.connect(func(selection: Dictionary) -> void: placement_controller.start(selection))
	level_root.tower_info_requested.connect(func(selection: Dictionary) -> void: level_root.set_status(str(selection.get("tooltip", "No tooltip."))))
	level_root.start_wave_pressed.connect(_start_first_wave)
	level_root.tower_upgrade_requested.connect(_upgrade_tower)
	level_root.settings_changed.connect(_on_settings_changed)
	placement_controller = TowerPlacementController.new()
	placement_controller.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(placement_controller)
	placement_controller.set_snap_callback(Callable(arena_viewport, "snap_to_grid"))
	placement_controller.placement_preview_changed.connect(_on_placement_preview_changed)
	placement_controller.placement_committed.connect(_on_placement_committed)
	complete_screen = LEVEL_COMPLETE_SCENE.instantiate() as LevelCompleteScreen
	complete_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(complete_screen)
	complete_screen.replay_pressed.connect(func() -> void: LevelManager.retry_level())
	complete_screen.next_pressed.connect(func() -> void: LevelManager.next_level())
	_apply_layout()
	_load_level()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_layout()

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	if arena_viewport != null:
		if level_root != null:
			arena_viewport.set_rect(level_root.get_arena_rect())
		else:
			arena_viewport.set_layout(view_size, LEFT_PANEL_RATIO, RIGHT_PANEL_RATIO)
	if arena_camera != null and arena_viewport != null:
		arena_camera.reset(arena_viewport.get_arena_rect().get_center())

func _process(delta: float) -> void:
	if not is_inside_tree() or (get_tree().paused and game_state != "prep"):
		return
	sim_time += delta
	var scaled_delta: float = delta * game_speed
	if two_finger_timer >= 0.0:
		two_finger_timer -= scaled_delta
		if two_finger_timer < 0.0:
			two_finger_timer = -1.0
	if game_state == "running":
		_handle_spawning(scaled_delta)
		_update_enemies(scaled_delta)
		_update_towers(scaled_delta)
		_refresh_tower_bonds()
		_check_win_condition()
	elif game_state == "prep":
		_refresh_tower_bonds()
	_update_effects(scaled_delta)
	arena_camera.update_follow(delta, towers, arena_viewport.get_arena_rect())
	arena_viewport.set_camera(arena_camera.center, arena_camera.zoom_factor)
	var placing: bool = placement_controller != null and placement_controller.is_active()
	var selected: Dictionary = placement_controller.get_selected_tower() if placing else {}
	var heat_delta: int = int(selected.get("build_cost", 0))
	arena_viewport.update_state(path_points, towers, enemies, tower_bonds, floating_texts, death_vfx, ghost_position, placing, placement_valid, heat_delta, sim_time)
	_update_side_panels()

func _input(event: InputEvent) -> void:
	if not is_inside_tree() or (get_tree().paused and game_state != "prep"):
		return
	arena_camera.consume_input(event)
	placement_controller.handle_input(event)
	if event is InputEventScreenTouch:
		_handle_touch(event)
	if event is InputEventMouseButton:
		_handle_mouse_tap(event)

func _load_level() -> void:
	DamageTracker.reset()
	peak_heat = 0.0
	var config: Dictionary = LevelManager.get_level_config()
	path_points = config.get("path_points", PackedVector2Array([Vector2(40, 40), Vector2(40, 560)]))
	wave_count = int(config.get("wave_count", 3))
	enemies_per_wave = int(config.get("enemies_per_wave", 6))
	enemy_speed = float(config.get("enemy_speed", 120.0))
	free_energy_threshold = float(config.get("free_energy_threshold", 0.6))
	minimum_bonds = int(config.get("minimum_bonds", 2))
	level_id = str(config.get("level_id", "procedural"))
	unlocked_towers.clear()
	for t: Variant in config.get("unlocked_towers", []):
		unlocked_towers.append(str(t))
	var tutorial_steps: Array[String] = []
	for step: Variant in config.get("tutorial_steps", []):
		tutorial_steps.append(str(step))
	TutorialManager.begin_level(level_id, tutorial_steps)
	if level_root != null:
		level_root.configure_towers(0.0, unlocked_towers)
		var highlight_collapse: bool = level_id == "level_01_first_fold" and not TutorialManager.is_completed(level_id)
		level_root.tower_selection_panel.call("set_collapse_highlight", highlight_collapse)
	wave_index = 1
	enemies_spawned_in_wave = 0
	enemy_spawn_interval = float(config.get("spawn_interval", ENEMY_SPAWN_INTERVAL))
	spawn_timer = 1.5
	game_state = "prep"
	lives = 3
	towers.clear()
	enemies.clear()
	floating_texts.clear()
	death_vfx.clear()
	level_root.set_status(TutorialManager.current_step_text())
	complete_screen.visible = false
	_normalize_path_into_arena()
	_build_path_cache()
	recommended_spots = _compute_recommended_spots()
	arena_viewport.set_recommended_spots(recommended_spots)
	var tutorial_overlay: bool = level_id.ends_with("first_fold") or level_id.contains("01")
	get_tree().paused = tutorial_overlay
	level_root.configure_pre_wave_overlay(tutorial_overlay, true)
	if not tutorial_overlay:
		level_root.set_status("Level hot-start: overlay hidden for advanced stage.")
		_start_first_wave()
	_on_settings_changed(level_root.get_user_settings())

func _start_first_wave() -> void:
	if game_state != "prep":
		return
	game_state = "running"
	spawn_timer = 1.5
	get_tree().paused = false
	level_root.set_pre_wave_visible(false)
	level_root.set_status(TutorialManager.current_step_text())

# SINGLE CLEAN IMPLEMENTATION – ALL DUPLICATES REMOVED (Codex #13)
func _normalize_path_into_arena() -> void:
	if path_points.size() < 2 or arena_viewport == null:
		return
	var source_bounds: Rect2 = Rect2(path_points[0], Vector2.ZERO)
	for point: Vector2 in path_points:
		source_bounds = source_bounds.expand(point)
	var viewport_rect: Rect2 = arena_viewport.get_arena_rect()
	var horizontal_padding: float = viewport_rect.size.x * ARENA_PADDING_RATIO
	var vertical_padding: float = viewport_rect.size.y * ARENA_PADDING_RATIO
	var target: Rect2 = Rect2(viewport_rect.position + Vector2(horizontal_padding, vertical_padding), viewport_rect.size - Vector2(horizontal_padding * 2.0, vertical_padding * 2.0))
	var safe_w: float = maxf(source_bounds.size.x, 1.0)
	var safe_h: float = maxf(source_bounds.size.y, 1.0)
	var scale_v: Vector2 = Vector2(target.size.x / safe_w, target.size.y / safe_h)
	for i: int in range(path_points.size()):
		var normalized: Vector2 = (path_points[i] - source_bounds.position)
		path_points[i] = target.position + Vector2(normalized.x * scale_v.x, normalized.y * scale_v.y)

func _build_path_cache() -> void:
	path_lengths.clear()
	total_path_length = 0.0
	for i: int in range(path_points.size() - 1):
		var segment_length: float = path_points[i].distance_to(path_points[i + 1])
		path_lengths.append(segment_length)
		total_path_length += segment_length

func _handle_spawning(delta: float) -> void:
	if wave_index > wave_count:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	if enemies_spawned_in_wave < enemies_per_wave:
		_spawn_enemy()
		enemies_spawned_in_wave += 1
		spawn_timer = enemy_spawn_interval
	elif enemies.is_empty():
		wave_index += 1
		enemies_spawned_in_wave = 0
		spawn_timer = 1.0

func _spawn_enemy() -> void:
	enemies.append({"id": str(Time.get_ticks_usec()), "progress": 0.0, "pos": path_points[0], "hp": 240.0, "max_hp": 240.0})

func _update_enemies(delta: float) -> void:
	var reached_end: int = 0
	for enemy: Dictionary in enemies:
		enemy["progress"] = float(enemy["progress"]) + enemy_speed * delta
		enemy["pos"] = _point_along_path(float(enemy["progress"]))
	for enemy_data: Dictionary in enemies:
		if float(enemy_data["progress"]) >= total_path_length:
			reached_end += 1
	enemies = enemies.filter(func(e: Dictionary) -> bool: return float(e["progress"]) < total_path_length and float(e["hp"]) > 0.0)
	if reached_end > 0:
		lives -= reached_end
		if lives <= 0:
			_set_loss_state()

func _point_along_path(progress: float) -> Vector2:
	if path_points.size() < 2:
		return arena_viewport.get_arena_rect().get_center()
	var clamped_progress: float = clampf(progress, 0.0, total_path_length)
	var cursor: float = 0.0
	for i: int in range(path_lengths.size()):
		var segment: float = path_lengths[i]
		if clamped_progress <= cursor + segment:
			var t: float = (clamped_progress - cursor) / maxf(segment, 0.001)
			return path_points[i].lerp(path_points[i + 1], t)
		cursor += segment
	return path_points[path_points.size() - 1]

func _update_towers(delta: float) -> void:
	for t: Dictionary in towers:
		t["last_target"] = null
		var thermal: Dictionary = t["thermal"]
		thermal["heat"] = maxf(0.0, float(thermal["heat"]) - float(thermal["dissipation_rate"]) * delta)
		peak_heat = maxf(peak_heat, float(thermal["heat"]))
		if bool(thermal["overheated"]) and float(thermal["heat"]) <= float(thermal["capacity"]) * float(thermal["recovery_ratio"]):
			thermal["overheated"] = false
		if bool(thermal["overheated"]):
			continue
		var target: Variant = _tower_target(t)
		if target is Dictionary:
			t["last_target"] = target["pos"]
			var dealt: float = BASE_DAMAGE * (1.0 + maxf(0.0, float(t.get("heat_tolerance_value", 0.8)) - 0.7))
			target["hp"] = float(target["hp"]) - dealt
			DamageTracker.record_damage(str(t.get("tower_id", "unknown")), dealt)
			_spawn_damage_text(Vector2(target["pos"]), int(round(dealt)))
			if float(target["hp"]) <= 0.0:
				_spawn_death_vfx(Vector2(target["pos"]))
			thermal["heat"] = float(thermal["heat"]) + float(thermal["heat_per_shot"])
			if float(thermal["heat"]) >= float(thermal["capacity"]):
				thermal["overheated"] = true

func _tower_target(tower: Dictionary) -> Variant:
	for e: Dictionary in enemies:
		if Vector2(e["pos"]).distance_to(Vector2(tower["pos"])) <= float(tower["radius"]):
			return e
	return null

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		active_touch_count += 1
		if active_touch_count >= 2:
			two_finger_timer = TWO_FINGER_WINDOW
		if not placement_controller.is_active():
			_try_select_tower(event.position)
		return
	active_touch_count = max(0, active_touch_count - 1)
	if two_finger_timer >= 0.0:
		_restart_level()

func _on_placement_committed(selection: Dictionary, pos: Vector2) -> void:
	var snapped_pos: Vector2 = arena_viewport.snap_to_grid(pos)
	if not _is_valid_placement(snapped_pos):
		level_root.set_status("Invalid placement (arena/path/occupied).")
		Input.vibrate_handheld(55)
		return
	_place_tower(snapped_pos, selection)
	Input.vibrate_handheld(25)

func _place_tower(pos: Vector2, definition: Dictionary) -> void:
	if towers.size() >= MAX_TOWERS:
		placement_valid = false
		return
	for tower_data: Dictionary in towers:
		if Vector2(tower_data["pos"]).distance_to(pos) < arena_viewport.cell_size * 0.75:
			placement_valid = false
			return
	if _distance_to_path(pos) < PATH_SAFE_DISTANCE:
		placement_valid = false
		level_root.set_status("Too close to river pathway.")
		return
	var thermal: Dictionary = THERMAL_DEFAULT.duplicate(true)
	var tower_payload: Dictionary = {
		"id": towers.size() + 1,
		"pos": pos,
		"radius": arena_viewport.cell_size * 2.8,
		"thermal": thermal,
		"last_target": null,
	}.merged(definition, true)
	towers.append(tower_payload)
	placement_valid = false
	TutorialManager.advance_step()
	level_root.set_status(TutorialManager.current_step_text())

func _is_valid_placement(pos: Vector2) -> bool:
	if not arena_viewport.is_point_inside_arena(pos):
		return false
	for tower_data: Dictionary in towers:
		if Vector2(tower_data["pos"]).distance_to(pos) < arena_viewport.cell_size * 0.75:
			return false
	return _distance_to_path(pos) >= PATH_SAFE_DISTANCE

func _on_placement_preview_changed(pos: Vector2) -> void:
	ghost_position = arena_viewport.snap_to_grid(pos)
	placement_valid = _is_valid_placement(ghost_position)
	var selected: Dictionary = placement_controller.get_selected_tower()
	var heat_delta: int = int(selected.get("build_cost", 0))
	var placement_state: String = "valid" if placement_valid else "invalid"
	level_root.set_status("Snap cell %s | Bonds preview active | Heat %+d°C" % [placement_state, heat_delta])


func _compute_recommended_spots() -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	var desired: int = randi_range(3, 5)
	if path_points.size() < 2:
		return spots
	var lane_offset: float = maxf(arena_viewport.cell_size * 1.8, PATH_SAFE_DISTANCE + 10.0)
	for i: int in range(path_points.size() - 1):
		if spots.size() >= desired:
			break
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var center: Vector2 = a.lerp(b, 0.5)
		var tangent: Vector2 = (b - a).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var candidate_a: Vector2 = arena_viewport.snap_to_grid(center + normal * lane_offset)
		var candidate_b: Vector2 = arena_viewport.snap_to_grid(center - normal * lane_offset)
		if _is_valid_placement(candidate_a):
			spots.append(candidate_a)
		if spots.size() >= desired:
			break
		if _is_valid_placement(candidate_b):
			spots.append(candidate_b)
	return spots

func _on_settings_changed(settings: Dictionary) -> void:
	arena_viewport.apply_user_settings(settings)

func _try_select_tower(point: Vector2) -> void:
	if not arena_viewport.is_point_inside_arena(point):
		return
	for index: int in range(towers.size()):
		var t: Dictionary = towers[index]
		if Vector2(t.get("pos", Vector2.ZERO)).distance_to(point) <= arena_viewport.cell_size * 0.75:
			level_root.show_tower_info(index, t)
			return

func _handle_mouse_tap(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not placement_controller.is_active():
		_try_select_tower(event.position)

func _upgrade_tower(tower_index: int) -> void:
	if tower_index < 0 or tower_index >= towers.size():
		return
	var tower_data: Dictionary = towers[tower_index]
	tower_data["heat_tolerance_value"] = float(tower_data.get("heat_tolerance_value", 0.8)) + 0.1
	tower_data["heat_gen_rate"] = float(tower_data.get("heat_gen_rate", 0.4)) + 0.1
	tower_data["radius"] = float(tower_data.get("radius", arena_viewport.cell_size * 2.8)) * 1.05
	level_root.set_status("Bond formed: helix twist applied (+12 DPS equivalent).")

func _refresh_tower_bonds() -> void:
	var graph_input: Array[Dictionary] = []
	for t: Dictionary in towers:
		graph_input.append(t)
	var graph_payload: Dictionary = TowerGraph.new().sync_from_towers(graph_input)
	tower_bonds = graph_payload.get("bonds", [])

func _distance_to_path(pos: Vector2) -> float:
	var closest: float = INF
	for i: int in range(path_points.size() - 1):
		var projected: Vector2 = Geometry2D.get_closest_point_to_segment(pos, path_points[i], path_points[i + 1])
		closest = minf(closest, pos.distance_to(projected))
	return closest

func _average_free_energy() -> float:
	if towers.is_empty():
		return 1.0
	var sum: float = 0.0
	for t: Dictionary in towers:
		var thermal: Dictionary = t["thermal"]
		sum += clampf(float(thermal["heat"]) / float(thermal["capacity"]), 0.0, 2.0)
	return sum / float(towers.size())

func _check_win_condition() -> void:
	if wave_index <= wave_count or not enemies.is_empty() or game_state != "running":
		return
	if _average_free_energy() > free_energy_threshold or tower_bonds.size() < minimum_bonds:
		_set_loss_state()
		level_root.set_status("Fold unstable. Improve bond count or reduce heat.")
		return
	game_state = "won"
	TutorialManager.complete_level()
	_show_complete_screen(true)

func _set_loss_state() -> void:
	game_state = "lost"
	level_root.set_status("Breach detected. Cooling down failed.")
	enemies.clear()
	_show_complete_screen(false)

func _restart_level() -> void:
	LevelManager.retry_level()

func _update_side_panels() -> void:
	var heat_ratio: float = _average_free_energy()
	if level_root != null:
		var wave_enemy_total: int = max(enemies_per_wave, 1)
		level_root.set_metrics(min(wave_index, wave_count), wave_count, enemies.size(), wave_enemy_total, lives, heat_ratio)
		level_root.set_wave_preview("▲ ● ◆", "Hot wave incoming")
		level_root.configure_towers(heat_ratio, unlocked_towers)

func _update_effects(delta: float) -> void:
	for text: Dictionary in floating_texts:
		text["t"] = float(text["t"]) + delta
		text["pos"] = Vector2(text["pos"]) + Vector2(0.0, -35.0 * delta)
	floating_texts = floating_texts.filter(func(entry: Dictionary) -> bool: return float(entry["t"]) < DAMAGE_TEXT_LIFETIME)
	for fx: Dictionary in death_vfx:
		fx["t"] = float(fx["t"]) + delta
	death_vfx = death_vfx.filter(func(entry: Dictionary) -> bool: return float(entry["t"]) < 0.45)

func _spawn_damage_text(pos: Vector2, amount: int) -> void:
	floating_texts.append({"pos": pos, "amount": amount, "t": 0.0})

func _spawn_death_vfx(pos: Vector2) -> void:
	death_vfx.append({"pos": pos, "t": 0.0})

func _show_complete_screen(survived: bool) -> void:
	var damage: float = DamageTracker.get_total_damage()
	var max_heat: float = peak_heat
	var efficiency: float = damage / maxf(max_heat, 1.0)
	var stars: int = 0
	if survived:
		stars += 1
	if _average_free_energy() <= free_energy_threshold:
		stars += 1
	if max_heat <= 85.0:
		stars += 1
	complete_screen.show_results({
		"stars": stars,
		"damage": damage,
		"peak_heat": max_heat,
		"bonds": tower_bonds.size(),
		"efficiency": efficiency,
		"summary": "Microscope fold stabilized with high-quality residue clustering.",
		"loadout": "Loadout ready: choose 4–6 residues for next run.",
	})

func _toggle_pause() -> void:
	if not is_inside_tree():
		return
	if game_state == "running":
		game_state = "paused"
		level_root.set_status("Paused")
	elif game_state == "paused":
		game_state = "running"
