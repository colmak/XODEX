# GODOT 4.6.1 STRICT – MOBILE UI v0.00.7
extends Node2D

const MAX_TOWERS: int = 12
const ENEMY_SPAWN_INTERVAL: float = 0.8
const TWO_FINGER_WINDOW: float = 0.18
const PATH_SAFE_DISTANCE: float = 72.0
const BASE_DAMAGE: float = 47.0
const DAMAGE_TEXT_LIFETIME: float = 0.75

const THERMAL_DEFAULT: Dictionary = {
	"capacity": 100.0,
	"heat_per_shot": 18.0,
	"dissipation_rate": 14.0,
	"recovery_ratio": 0.45,
}

const LEVEL_HUD_SCENE: PackedScene = preload("res://ui/level_hud.tscn")
const LEVEL_COMPLETE_SCENE: PackedScene = preload("res://ui/level_complete.tscn")

var hud: LevelHUD
var complete_screen: LevelCompleteScreen
var placement_controller: TowerPlacementController

var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var tower_bonds: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var death_vfx: Array[Dictionary] = []

var spawn_timer: float = 0.0
var touch_down_time: Dictionary = {}
var active_touch_count: int = 0
var two_finger_timer: float = -1.0
var ghost_position: Vector2 = Vector2.ZERO

var game_state: String = "running"
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

func _ready() -> void:
	set_process(true)
	SingletonGuard.assert_singleton_ready("TutorialManager", "LevelScene._ready")
	SingletonGuard.assert_singleton_ready("HeatEngine", "LevelScene._ready")
	SingletonGuard.assert_singleton_ready("DamageTracker", "LevelScene._ready")
	placement_controller = TowerPlacementController.new()
	add_child(placement_controller)
	placement_controller.placement_preview_changed.connect(func(pos: Vector2) -> void: ghost_position = pos)
	placement_controller.placement_committed.connect(_on_placement_committed)
	hud = LEVEL_HUD_SCENE.instantiate() as LevelHUD
	add_child(hud)
	hud.pause_pressed.connect(_toggle_pause)
	hud.speed_changed.connect(func(multiplier: float) -> void: game_speed = multiplier)
	hud.tower_selected.connect(func(selection: Dictionary) -> void: placement_controller.start(selection))
	hud.tower_info_requested.connect(func(selection: Dictionary) -> void: hud.show_tooltip(str(selection.get("tooltip", "No tooltip."))))
	complete_screen = LEVEL_COMPLETE_SCENE.instantiate() as LevelCompleteScreen
	add_child(complete_screen)
	complete_screen.replay_pressed.connect(func() -> void: LevelManager.retry_level())
	complete_screen.next_pressed.connect(func() -> void: LevelManager.next_level())
	_load_level()

func _process(delta: float) -> void:
	var scaled_delta: float = delta * game_speed
	if two_finger_timer >= 0.0:
		two_finger_timer -= scaled_delta
		if two_finger_timer < 0.0:
			two_finger_timer = -1.0
	if game_state == "paused":
		queue_redraw()
		return
	if game_state == "running":
		_handle_spawning(scaled_delta)
		_update_enemies(scaled_delta)
		_update_towers(scaled_delta)
		_refresh_tower_bonds()
		_check_win_condition()
	_update_effects(scaled_delta)
	_update_hud()
	queue_redraw()

func _input(event: InputEvent) -> void:
	placement_controller.handle_input(event)
	if event is InputEventScreenTouch:
		_handle_touch(event)

func _load_level() -> void:
	DamageTracker.reset()
	peak_heat = 0.0
	var config: Dictionary = LevelManager.get_level_config()
	path_points = config.get("path_points", PackedVector2Array([Vector2(40, 640), Vector2(680, 640)]))
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
	hud.configure_towers(0.0, unlocked_towers)
	wave_index = 1
	enemies_spawned_in_wave = 0
	enemy_spawn_interval = float(config.get("spawn_interval", ENEMY_SPAWN_INTERVAL))
	spawn_timer = enemy_spawn_interval
	game_state = "running"
	lives = 3
	towers.clear()
	enemies.clear()
	floating_texts.clear()
	death_vfx.clear()
	hud.set_status(TutorialManager.current_step_text())
	complete_screen.visible = false
	_build_path_cache()

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
	enemies.append({"id": str(Time.get_ticks_usec()), "progress": 0.0, "pos": path_points[0], "hp": 240.0, "max_hp": 240.0, "death_t": 0.0})

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
		Input.vibrate_handheld(40)
		if lives <= 0:
			_set_loss_state()

func _point_along_path(progress: float) -> Vector2:
	if path_points.size() < 2:
		return Vector2(40, 640)
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
			_spawn_damage_text(Vector2(target["pos"]), int(round(dealt)), str(t.get("tower_id", "tower")))
			if float(target["hp"]) <= 0.0:
				_spawn_death_vfx(Vector2(target["pos"]))
			thermal["heat"] = float(thermal["heat"]) + float(thermal["heat_per_shot"])
			if float(thermal["heat"]) >= float(thermal["capacity"]):
				thermal["overheated"] = true
				Input.vibrate_handheld(20)

func _tower_target(tower: Dictionary) -> Variant:
	for e: Dictionary in enemies:
		if Vector2(e["pos"]).distance_to(Vector2(tower["pos"])) <= float(tower["radius"]):
			return e
	return null

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		active_touch_count += 1
		touch_down_time[event.index] = Time.get_ticks_msec() / 1000.0
		if active_touch_count >= 2:
			two_finger_timer = TWO_FINGER_WINDOW
		return
	active_touch_count = max(0, active_touch_count - 1)
	touch_down_time.erase(event.index)
	if two_finger_timer >= 0.0:
		_restart_level()

func _on_placement_committed(selection: Dictionary, pos: Vector2) -> void:
	hud.hide_tooltip()
	_place_tower(pos, selection)

func _place_tower(pos: Vector2, definition: Dictionary) -> void:
	if towers.size() >= MAX_TOWERS:
		return
	for tower_data: Dictionary in towers:
		if Vector2(tower_data["pos"]).distance_to(pos) < 80.0:
			return
	if _distance_to_path(pos) < PATH_SAFE_DISTANCE:
		hud.set_status("Too close to river pathway.")
		return
	var thermal: Dictionary = THERMAL_DEFAULT.duplicate(true)
	towers.append({
		"id": towers.size() + 1,
		"pos": pos,
		"radius": 180.0,
		"thermal": thermal,
		"last_target": null,
	}.merged(definition, true))
	Input.vibrate_handheld(20)
	TutorialManager.advance_step()
	hud.set_status(TutorialManager.current_step_text())

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
	var free_energy: float = _average_free_energy()
	if free_energy > free_energy_threshold or tower_bonds.size() < minimum_bonds:
		_set_loss_state()
		hud.set_status("Fold unstable. Improve bond count or reduce heat.")
		return
	game_state = "won"
	TutorialManager.complete_level()
	Input.vibrate_handheld(80)
	_show_complete_screen(true)

func _set_loss_state() -> void:
	game_state = "lost"
	hud.set_status("Breach detected. Cooling down failed.")
	enemies.clear()
	_show_complete_screen(false)

func _restart_level() -> void:
	LevelManager.retry_level()

func _update_hud() -> void:
	if hud == null:
		return
	hud.set_header(min(wave_index, wave_count), wave_count, lives, _average_free_energy(), DamageTracker.get_total_damage())

func _update_effects(delta: float) -> void:
	for text: Dictionary in floating_texts:
		text["t"] = float(text["t"]) + delta
		text["pos"] = Vector2(text["pos"]) + Vector2(0.0, -35.0 * delta)
	floating_texts = floating_texts.filter(func(entry: Dictionary) -> bool: return float(entry["t"]) < DAMAGE_TEXT_LIFETIME)
	for fx: Dictionary in death_vfx:
		fx["t"] = float(fx["t"]) + delta
	death_vfx = death_vfx.filter(func(entry: Dictionary) -> bool: return float(entry["t"]) < 0.45)

func _spawn_damage_text(pos: Vector2, amount: int, tower_id: String) -> void:
	floating_texts.append({"pos": pos, "amount": amount, "tower_id": tower_id, "t": 0.0})

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
		"summary": "Your β-sheet wall blocked 68 % of the wave – great hydrophobic clustering!",
	})

func _toggle_pause() -> void:
	if game_state == "running":
		game_state = "paused"
		hud.set_status("Paused")
	elif game_state == "paused":
		game_state = "running"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("111827"), true)
	if path_points.size() >= 2:
		draw_polyline(path_points, Color("f59e0b"), 34.0, true)
		draw_polyline(path_points, Color("fde68a"), 8.0, true)
	for enemy_data: Dictionary in enemies:
		var p: Vector2 = enemy_data["pos"]
		draw_polygon([p + Vector2(0, -14), p + Vector2(13, 11), p + Vector2(-13, 11)], [Color("f8fafc")])
		var hp_ratio: float = clampf(float(enemy_data["hp"]) / float(enemy_data["max_hp"]), 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(-16, -24), Vector2(32 * hp_ratio, 4)), Color(1.0 - hp_ratio, hp_ratio, 0.2, 1.0), true)
	for bond: Dictionary in tower_bonds:
		var intensity: float = clampf(absf(float(bond["strength"])), 0.2, 1.0)
		draw_line(bond["from"], bond["to"], Color(0.6, 0.9, 1.0, 0.2 + intensity * 0.3), 3.0)
	for t: Dictionary in towers:
		var thermal: Dictionary = t["thermal"]
		var heat_ratio: float = clampf(float(thermal["heat"]) / float(thermal["capacity"]), 0.0, 1.0)
		var c: Color = Color(0.2 + heat_ratio * 0.8, 0.45 + (1.0 - heat_ratio) * 0.4, 1.0 - heat_ratio, 1.0)
		if bool(thermal["overheated"]):
			c = Color(1.0, 0.2, 0.1, 1.0)
		draw_circle(t["pos"], 28.0, c)
		if t["last_target"] != null:
			draw_line(t["pos"], t["last_target"], Color(1.0, 0.4, 0.3, 0.6), 3.0)
	if placement_controller != null and placement_controller.is_active():
		draw_circle(ghost_position, 24.0, Color(0.3, 1.0, 0.8, 0.35))
		draw_arc(ghost_position, 180.0, 0.0, TAU, 48, Color(0.3, 1.0, 0.8, 0.25), 2.0)
	for entry: Dictionary in floating_texts:
		var alpha: float = 1.0 - float(entry["t"]) / DAMAGE_TEXT_LIFETIME
		draw_string(ThemeDB.fallback_font, Vector2(entry["pos"]), "-%d" % int(entry["amount"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.35, 0.35, alpha))
	for fx: Dictionary in death_vfx:
		var t: float = float(fx["t"])
		var radius: float = lerpf(10.0, 42.0, t / 0.45)
		var alpha_fx: float = 1.0 - t / 0.45
		draw_circle(Vector2(fx["pos"]), radius, Color(0.5, 0.9, 1.0, alpha_fx * 0.4))
