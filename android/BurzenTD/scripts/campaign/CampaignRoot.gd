extends Node2D

class_name CampaignRoot

signal codex_command_ready(command_payload: Dictionary)

const CORE_TOWERS: Array[Dictionary] = [
	{"id": "kinetic", "name": "Kinetic"},
	{"id": "thermal", "name": "Thermal"},
	{"id": "energy", "name": "Energy"},
	{"id": "reaction", "name": "Reaction"},
	{"id": "pulse", "name": "Pulse"},
	{"id": "field", "name": "Field"},
	{"id": "conversion", "name": "Conversion"},
	{"id": "control", "name": "Control"},
]

@onready var tower_container: Node2D = %TowerContainer
@onready var mob_container: Node2D = %MobContainer
@onready var loadout_panel: LoadoutPanel = %LoadoutPanel
@onready var energy_heat_overlay: EnergyHeatOverlay = %EnergyHeatOverlay
@onready var wave_ui: WaveUI = %WaveUI
@onready var level_progress_bar: LevelProgressBar = %LevelProgressBar
@onready var debug_overlay: Label = %DebugOverlay

var _last_version_id: int = -1
var _checksum_valid: bool = true
var _tick_latency_ms: float = 0.0
var _last_payload_bytes: int = 0
var _debug_visible: bool = false

func _ready() -> void:
	loadout_panel.configure_towers(CORE_TOWERS)
	loadout_panel.loadout_locked.connect(_on_loadout_locked)
	debug_overlay.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		debug_overlay.visible = _debug_visible

func process_codex_frame(frame: String) -> void:
	var started_at: int = Time.get_ticks_msec()
	var parsed: Dictionary = _decode_xdx1_frame(frame)
	_checksum_valid = bool(parsed.get("checksum_valid", false))
	if not _checksum_valid:
		_refresh_debug({"version_id": _last_version_id, "energy_graph": [], "heat_map": []})
		emit_signal("codex_command_ready", {"command": "resend", "after_version": _last_version_id})
		return

	var eigen: Dictionary = parsed.get("payload", {})
	eigen["checksum_valid"] = _checksum_valid
	var update: Dictionary = ResidueEngine.apply_eigenstate_vector(eigen)
	if not bool(update.get("accepted", false)):
		return
	_last_version_id = int(update.get("version_id", _last_version_id))
	_apply_render_update(update)
	_tick_latency_ms = float(Time.get_ticks_msec() - started_at)
	_last_payload_bytes = frame.to_utf8_buffer().size()
	_refresh_debug(eigen)

func _apply_render_update(update: Dictionary) -> void:
	_update_towers(update.get("tower_updates", []), update.get("spawn_towers", {}))
	_update_mobs(update.get("mobs", []))
	var energy_overlay_payload: Dictionary = update.get("energy_overlay", {})
	energy_heat_overlay.update_energy_graph(energy_overlay_payload.get("energy_graph", []))
	var heat_overlay_payload: Dictionary = update.get("heat_overlay", {})
	energy_heat_overlay.update_heat_map(heat_overlay_payload.get("heat_map", []), float(heat_overlay_payload.get("heat_max", 0.0)))
	wave_ui.update_from_level_state(update.get("wave_ui", {}))
	var wave_state: Dictionary = update.get("wave_ui", {})
	level_progress_bar.update_progress(int(wave_state.get("level_number", 1)), int(wave_state.get("completed_levels", 0)))

func _update_towers(tower_updates: Array, spawn_despawn: Dictionary) -> void:
	for tower_id: Variant in spawn_despawn.get("despawn", []):
		var node: Node = tower_container.get_node_or_null(str(tower_id))
		if node != null:
			node.queue_free()
	for payload: Variant in tower_updates:
		if not (payload is Dictionary):
			continue
		var tower_payload: Dictionary = payload
		var tower_id: String = str(tower_payload.get("id", ""))
		if tower_id.is_empty():
			continue
		var tower_node: Node2D = tower_container.get_node_or_null(tower_id) as Node2D
		if tower_node == null:
			tower_node = Node2D.new()
			tower_node.name = tower_id
			tower_container.add_child(tower_node)
		tower_node.position = _to_vec2(tower_payload.get("position", Vector2.ZERO))

func _update_mobs(mob_updates: Array) -> void:
	for child: Node in mob_container.get_children():
		child.queue_free()
	for payload: Variant in mob_updates:
		if payload is Dictionary:
			var mob_node: Node2D = Node2D.new()
			mob_node.name = str((payload as Dictionary).get("id", "mob"))
			mob_node.position = _to_vec2((payload as Dictionary).get("position", Vector2.ZERO))
			mob_container.add_child(mob_node)

func _on_loadout_locked(selected_ids: Array[String]) -> void:
	emit_signal("codex_command_ready", {
		"command": "start_level",
		"mode": "campaign_v0_8",
		"loadout": selected_ids,
		"slots": 4,
	})

func _refresh_debug(eigen: Dictionary) -> void:
	if not _debug_visible:
		return
	var heat_max: float = 0.0
	for point: Variant in eigen.get("heat_map", []):
		if point is Dictionary:
			heat_max = maxf(heat_max, float(point.get("value", 0.0)))
	debug_overlay.text = "payload=%dB\nchecksum=%s\nversion=%d\nenergy_links=%d\nheat_max=%.2f\nlatency=%.1fms" % [
		_last_payload_bytes,
		"valid" if _checksum_valid else "invalid",
		_last_version_id,
		(eigen.get("energy_graph", []) as Array).size(),
		heat_max,
		_tick_latency_ms,
	]

func _decode_xdx1_frame(frame: String) -> Dictionary:
	var parts: PackedStringArray = frame.split(".")
	if parts.size() != 3 or parts[0] != "XDX1":
		return {"checksum_valid": false, "payload": {}}
	var payload_bytes: PackedByteArray = Marshalls.base64_to_raw(parts[1])
	var payload_json: String = payload_bytes.get_string_from_utf8()
	var payload_value: Variant = JSON.parse_string(payload_json)
	if not (payload_value is Dictionary):
		return {"checksum_valid": false, "payload": {}}
	var checksum_hex: String = parts[2].to_lower()
	var checksum_valid: bool = checksum_hex == _checksum8(parts[1])
	return {
		"checksum_valid": checksum_valid,
		"payload": payload_value,
	}

func _checksum8(payload: String) -> String:
	var value: int = 0
	for i: int in range(payload.length()):
		value = int((value + payload.unicode_at(i)) & 0xFFFFFFFF)
	return "%08x" % value

func _to_vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var point: Dictionary = value
		return Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))
	return Vector2.ZERO
