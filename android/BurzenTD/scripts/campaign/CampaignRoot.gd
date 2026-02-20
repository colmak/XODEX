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
@onready var debug_overlay: EigenstateDebugOverlay = %DebugOverlay
@onready var audio_controller: AudioController = %AudioController

var _last_version_id: int = -1
var _checksum_valid: bool = true
var _tick_latency_ms: float = 0.0
var _last_payload_bytes: int = 0
var _debug_visible: bool = false

func _ensure_debug_input_actions() -> void:
	if not InputMap.has_action("toggle_eigenstate_debug"):
		InputMap.add_action("toggle_eigenstate_debug")
		var f10_event: InputEventKey = InputEventKey.new()
		f10_event.keycode = KEY_F10
		InputMap.action_add_event("toggle_eigenstate_debug", f10_event)
		var shift_d_event: InputEventKey = InputEventKey.new()
		shift_d_event.keycode = KEY_D
		shift_d_event.shift_pressed = true
		InputMap.action_add_event("toggle_eigenstate_debug", shift_d_event)

func _ready() -> void:
	_ensure_debug_input_actions()
	loadout_panel.configure_towers(CORE_TOWERS)
	loadout_panel.loadout_locked.connect(_on_loadout_locked)
	debug_overlay.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_eigenstate_debug"):
		_debug_visible = not _debug_visible
		debug_overlay.visible = _debug_visible

func process_codex_frame(frame: String) -> void:
	var started_at: int = Time.get_ticks_usec()
	var parsed: Dictionary = _decode_xdx1_frame(frame)
	_checksum_valid = bool(parsed.get("checksum_valid", false))
	var checksum_hex: String = str(parsed.get("checksum", "00"))
	var checksum8: int = int("0x%s" % checksum_hex.substr(0, 2)) if checksum_hex.length() >= 2 else 0
	var payload_size: int = int(parsed.get("payload_size", 0))
	var decode_us: int = int(Time.get_ticks_usec() - started_at)
	if not _checksum_valid:
		debug_overlay.update_metadata({
			"version_id": _last_version_id,
			"checksum8": checksum8,
			"payload_size": payload_size,
			"decode_us": decode_us,
			"status": "CHECKSUM_FAIL",
		})
		_refresh_debug({"version_id": _last_version_id, "energy_graph": [], "heat_map": []})
		emit_signal("codex_command_ready", {"command": "resend", "after_version": _last_version_id})
		return

	var eigen: Dictionary = parsed.get("payload", {})
	eigen["checksum_valid"] = _checksum_valid
	var update: Dictionary = ResidueEngine.apply_eigenstate_vector(eigen)
	if not bool(update.get("accepted", false)):
		debug_overlay.update_metadata({
			"version_id": int(update.get("version_id", -1)),
			"checksum8": checksum8,
			"payload_size": payload_size,
			"decode_us": decode_us,
			"status": str(update.get("reason", "REJECTED")).to_upper(),
		})
		return
	_last_version_id = int(update.get("version_id", _last_version_id))
	_apply_render_update(update)
	_tick_latency_ms = float(Time.get_ticks_usec() - started_at) / 1000.0
	_last_payload_bytes = frame.to_utf8_buffer().size()
	_on_eigenstate_applied({
		"version_id": _last_version_id,
		"checksum8": checksum8,
		"payload_size": payload_size,
		"decode_us": decode_us,
		"status": "VALID",
	})
	_refresh_debug(eigen)
	if audio_controller != null:
		audio_controller.apply_eigenstate_projection(eigen)

func _on_eigenstate_applied(update: Dictionary) -> void:
	if debug_overlay != null:
		debug_overlay.update_metadata(update)

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

func _refresh_debug(_eigen: Dictionary) -> void:
	if not _debug_visible:
		return

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
		"checksum": checksum_hex,
		"payload_size": payload_bytes.size(),
		"payload": payload_value,
	}

func reset_state_machine() -> void:
	_last_version_id = -1
	_checksum_valid = true
	_tick_latency_ms = 0.0
	_last_payload_bytes = 0

func inject_deterministic_sequence(sequence: Array, deterministic_seed: int) -> void:
	seed(deterministic_seed)
	for frame: Variant in sequence:
		if frame is String:
			process_codex_frame(frame)

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
