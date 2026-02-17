# GODOT 4.6.1 STRICT – DEMO CAMPAIGN v0.00.6
extends Node2D

const MAX_TOWERS: int = 12
const ENEMY_SPAWN_INTERVAL: float = 0.8
const LONG_PRESS_SECONDS: float = 0.4
const TWO_FINGER_WINDOW: float = 0.18
const PATH_SAFE_DISTANCE: float = 72.0

const THERMAL_DEFAULT: Dictionary = {
	"capacity": 100.0,
	"heat_per_shot": 18.0,
	"dissipation_rate": 14.0,
	"recovery_ratio": 0.45,
}

@onready var status_label: Label = %StatusLabel
@onready var level_label: Label = %LevelLabel
@onready var wave_label: Label = %WaveLabel
@onready var lives_label: Label = %LivesLabel
@onready var score_label: Label = %ScoreLabel
@onready var action_button: Button = %ActionButton
@onready var menu_button: Button = %MenuButton

var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var tower_bonds: Array[Dictionary] = []
var spawn_timer: float = 0.0
var touch_down_time: Dictionary = {}
var active_touch_count: int = 0
var two_finger_timer: float = -1.0

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
var score: int = 0
var free_energy_threshold: float = 0.6
var minimum_bonds: int = 2
var level_id: String = ""
var unlocked_towers: Array[String] = []

var game_speed: float = 1.0
var hud_enabled: bool = true
var show_range_overlay: bool = true
var show_attack_visualization: bool = true
var debug_logs_enabled: bool = false
var tower_selection_ui: TowerSelectionUI

func _ready() -> void:
	set_process(true)
	tower_selection_ui = TowerSelectionUI.new()
	add_child(tower_selection_ui)
	tower_selection_ui.hide()
	_apply_runtime_settings()
	_load_level()
	_update_hud()

func _process(delta: float) -> void:
	var scaled_delta: float = delta * game_speed
	if two_finger_timer >= 0.0:
		two_finger_timer -= scaled_delta
		if two_finger_timer < 0.0:
			two_finger_timer = -1.0
	if game_state != "running":
		queue_redraw()
		return
	_handle_spawning(scaled_delta)
	_update_enemies(scaled_delta)
	_update_towers(scaled_delta)
	_refresh_tower_bonds()
	_check_win_condition()
	_update_hud()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)

func _load_level() -> void:
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
	_apply_runtime_settings()
	wave_index = 1
	enemies_spawned_in_wave = 0
	enemy_spawn_interval = float(config.get("spawn_interval", ENEMY_SPAWN_INTERVAL))
	spawn_timer = enemy_spawn_interval
	game_state = "running"
	lives = 3
	score = 0
	status_label.text = TutorialManager.current_step_text()
	action_button.visible = false
	_build_path_cache()
	level_label.text = "Level %d | %s" % [int(config.get("level_index", 1)), level_id]

func _build_path_cache() -> void:
	path_lengths.clear()
	total_path_length = 0.0
	for i: int in range(path_points.size() - 1):
		var segment_length: float = path_points[i].distance_to(path_points[i + 1])
		path_lengths.append(segment_length)
		total_path_length += segment_length

func _apply_runtime_settings() -> void:
	var settings: Dictionary = LevelManager.get_settings()
	var general: Dictionary = settings.get("general", {})
	var tower: Dictionary = settings.get("tower", {})
	var advanced: Dictionary = settings.get("advanced", {})
	game_speed = float(general.get("game_speed", 1.0))
	hud_enabled = bool(general.get("hud_enabled", true))
	show_range_overlay = bool(tower.get("range_overlay", true))
	show_attack_visualization = bool(tower.get("attack_visualization", true))
	debug_logs_enabled = bool(advanced.get("debug_logs", false))
	if has_node("HUD"):
		$HUD.visible = hud_enabled

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
	enemies.append({"progress": 0.0, "pos": path_points[0]})

func _update_enemies(delta: float) -> void:
	var reached_end: int = 0
	for enemy: Dictionary in enemies:
		enemy["progress"] = float(enemy["progress"]) + enemy_speed * delta
		enemy["pos"] = _point_along_path(float(enemy["progress"]))
	for enemy_data: Dictionary in enemies:
		if float(enemy_data["progress"]) >= total_path_length:
			reached_end += 1
	enemies = enemies.filter(func(e: Dictionary) -> bool: return float(e["progress"]) < total_path_length)
	if reached_end > 0:
		lives -= reached_end
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
		if bool(thermal["overheated"]) and float(thermal["heat"]) <= float(thermal["capacity"]) * float(thermal["recovery_ratio"]):
			thermal["overheated"] = false
		if bool(thermal["overheated"]):
			continue
		var target: Variant = _tower_target(t)
		if target is Vector2:
			t["last_target"] = target
			thermal["heat"] = float(thermal["heat"]) + float(thermal["heat_per_shot"])
			score += 1
			if float(thermal["heat"]) >= float(thermal["capacity"]):
				thermal["overheated"] = true
		var normalized_density: float = clampf(float(enemies.size()) / 20.0, 0.0, 2.0)
		var heat_payload: Dictionary = HeatEngine.apply_tower_tick(t, delta, normalized_density, target is Vector2)
		for key: Variant in heat_payload.keys():
			t[str(key)] = heat_payload[key]

func _tower_target(tower: Dictionary) -> Variant:
	for e: Dictionary in enemies:
		if Vector2(e["pos"]).distance_to(Vector2(tower["pos"])) <= float(tower["radius"]):
			return e["pos"]
	return null

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		active_touch_count += 1
		touch_down_time[event.index] = Time.get_ticks_msec() / 1000.0
		if active_touch_count >= 2:
			two_finger_timer = TWO_FINGER_WINDOW
		return
	active_touch_count = max(0, active_touch_count - 1)
	var now: float = Time.get_ticks_msec() / 1000.0
	var start: float = float(touch_down_time.get(event.index, now))
	var hold_time: float = now - start
	touch_down_time.erase(event.index)
	if two_finger_timer >= 0.0:
		_restart_level()
		return
	if game_state != "running":
		return
	if hold_time >= LONG_PRESS_SECONDS:
		_highlight_tower(event.position)
	else:
		_place_tower(event.position)

func _place_tower(pos: Vector2) -> void:
	if towers.size() >= MAX_TOWERS:
		return
	for tower_data: Dictionary in towers:
		if Vector2(tower_data["pos"]).distance_to(pos) < 80.0:
			return
	if _distance_to_path(pos) < PATH_SAFE_DISTANCE:
		status_label.text = "Too close to river pathway."
		return
	var next_tower_def: Dictionary = _next_tower_definition()
	var thermal: Dictionary = THERMAL_DEFAULT.duplicate(true)
	towers.append({
		"id": towers.size() + 1,
		"pos": pos,
		"grid_x": int(round(pos.x / 80.0)),
		"grid_y": int(round(pos.y / 80.0)),
		"radius": 180.0,
		"thermal": thermal,
		"highlight": 0.0,
		"last_target": null,
		"heat_score": 0.0,
		"normalized_heat": 0.0,
		"thermal_state": 0.0,
		"misfold_probability": 0.0,
		"is_misfolded": false,
	}.merged(next_tower_def, true))
	TutorialManager.advance_step()
	var step_text: String = TutorialManager.current_step_text()
	if not step_text.is_empty():
		status_label.text = step_text

func _next_tower_definition() -> Dictionary:
	var catalog: Array[Dictionary] = tower_selection_ui.visible_catalog(0.0, unlocked_towers)
	if catalog.is_empty():
		catalog = tower_selection_ui.catalog
	if catalog.is_empty():
		return {"tower_id": "fallback", "residue_class": "special", "heat_gen_rate": 0.5, "heat_tolerance_value": 1.0}
	return catalog[towers.size() % catalog.size()]

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

func _highlight_tower(pos: Vector2) -> void:
	for tower_data: Dictionary in towers:
		if Vector2(tower_data["pos"]).distance_to(pos) <= 42.0:
			tower_data["highlight"] = 1.0

func _average_free_energy() -> float:
	if towers.is_empty():
		return 1.0
	var sum: float = 0.0
	for t: Dictionary in towers:
		sum += clampf(float(t.get("normalized_heat", 0.0)), 0.0, 2.0)
	return sum / float(towers.size())

func _check_win_condition() -> void:
	if wave_index <= wave_count or not enemies.is_empty() or game_state != "running":
		return
	var free_energy: float = _average_free_energy()
	if free_energy > free_energy_threshold or tower_bonds.size() < minimum_bonds:
		_set_loss_state()
		status_label.text = "Fold unstable. Improve bond count or reduce heat."
		return
	game_state = "won"
	TutorialManager.complete_level()
	status_label.text = "Campaign node cleared. Fold stabilized."
	action_button.text = "Next Level"
	action_button.visible = true

func _set_loss_state() -> void:
	game_state = "lost"
	status_label.text = "Breach detected. Cooling down failed."
	action_button.text = "Retry"
	action_button.visible = true
	enemies.clear()

func _restart_level() -> void:
	towers.clear()
	enemies.clear()
	touch_down_time.clear()
	active_touch_count = 0
	two_finger_timer = -1.0
	LevelManager.retry_level()

func _on_action_button_pressed() -> void:
	if game_state == "won":
		LevelManager.next_level()
	elif game_state == "lost":
		LevelManager.retry_level()

func _on_menu_button_pressed() -> void:
	LevelManager.return_to_menu()

func _update_hud() -> void:
	if not hud_enabled:
		return
	wave_label.text = "Wave %d/%d | Speed %.2fx" % [min(wave_index, wave_count), wave_count, game_speed]
	lives_label.text = "Lives: %d" % max(lives, 0)
	score_label.text = "Heat Score: %d" % score

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(720, 1280)), Color("111827"), true)
	if path_points.size() >= 2:
		draw_polyline(path_points, Color("f59e0b"), 34.0, true)
		draw_polyline(path_points, Color("fde68a"), 8.0, true)
	for enemy_data: Dictionary in enemies:
		var p: Vector2 = enemy_data["pos"]
		draw_polygon([p + Vector2(0, -14), p + Vector2(13, 11), p + Vector2(-13, 11)], [Color("f8fafc")])
	for bond: Dictionary in tower_bonds:
		var intensity: float = clampf(absf(float(bond["strength"])), 0.2, 1.0)
		draw_line(bond["from"], bond["to"], Color(0.6, 0.9, 1.0, 0.2 + intensity * 0.3), 3.0)
	for t: Dictionary in towers:
		var thermal: Dictionary = t["thermal"]
		var heat_ratio: float = clampf(maxf(float(t.get("normalized_heat", 0.0)), float(thermal["heat"]) / float(thermal["capacity"])), 0.0, 1.0)
		var c: Color = Color(0.2 + heat_ratio * 0.8, 0.45 + (1.0 - heat_ratio) * 0.4, 1.0 - heat_ratio, 1.0)
		if bool(thermal["overheated"]):
			c = Color(1.0, 0.2, 0.1, 1.0)
		draw_circle(t["pos"], 28.0, c)
		if show_range_overlay:
			draw_arc(t["pos"], t["radius"], 0.0, TAU, 48, Color(0.5, 0.5, 0.6, 0.2), 2.0)
		if show_attack_visualization and t["last_target"] != null:
			draw_line(t["pos"], t["last_target"], Color(1.0, 0.4, 0.3, 0.6), 3.0)
		if float(t["highlight"]) > 0.0:
			draw_circle(t["pos"], 38.0, Color(1, 1, 1, 0.2))
			t["highlight"] = maxf(0.0, float(t["highlight"]) - 0.04)
