extends Node2D

class_name CampaignRoot

signal codex_command_ready(command_payload: Dictionary)

const MAX_PAYLOAD_SIZE_WARNING: int = 4096

var residue_engine: ResidueEngine = ResidueEngine.new()
var last_version_id: int = -1
var dev_overlay_visible: bool = false
var latest_debug_metrics: Dictionary = {
	"payload_size": 0,
	"checksum_valid": false,
	"version": -1,
	"energy_nodes": 0,
	"heat_max": 0.0,
	"tick_latency_ms": 0.0,
}

@onready var map_container: Node2D = %MapContainer
@onready var tower_container: Node2D = %TowerContainer
@onready var mob_container: Node2D = %MobContainer
@onready var energy_heat_overlay: EnergyHeatOverlay = %EnergyHeatOverlay
@onready var loadout_panel: CampaignLoadoutPanel = %LoadoutPanel
@onready var wave_ui: CampaignWaveUI = %WaveUI
@onready var level_progress_bar: ProgressBar = %LevelProgressBar
@onready var debug_overlay: Label = %DebugOverlay

func _ready() -> void:
	loadout_panel.loadout_locked.connect(_on_loadout_locked)
	level_progress_bar.max_value = 10
	level_progress_bar.value = 1
	debug_overlay.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next") and Input.is_key_pressed(KEY_F3):
		_toggle_debug_overlay()
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
			_toggle_debug_overlay()

func ingest_codex_frame(frame: String, tick_latency_ms: float = 0.0) -> void:
	var decode_result: Dictionary = CodexFrameDecoder.decode_frame(frame)
	if not bool(decode_result.get("ok", false)):
		_update_debug_metrics(false, tick_latency_ms, {}, 0)
		return
	var eigen_payload: Dictionary = decode_result.get("payload", {})
	var version_id: int = int(eigen_payload.get("version_id", -1))
	if version_id <= last_version_id:
		return
	last_version_id = version_id
	var payload_size: int = int(decode_result.get("payload_size", 0))
	if payload_size > MAX_PAYLOAD_SIZE_WARNING:
		push_warning("CODEX payload exceeds safe size: %d" % payload_size)
	residue_engine.apply_eigenstate_vector(eigen_payload, {
		"tower_container": tower_container,
		"mob_container": mob_container,
		"energy_overlay": energy_heat_overlay,
		"wave_ui": wave_ui,
		"progress_bar": level_progress_bar,
	})
	_update_debug_metrics(true, tick_latency_ms, eigen_payload, payload_size)

func _on_loadout_locked(selected_towers: Array[String]) -> void:
	emit_signal("codex_command_ready", {
		"command": "start_level",
		"selected_tower_ids": selected_towers,
	})

func _toggle_debug_overlay() -> void:
	dev_overlay_visible = not dev_overlay_visible
	debug_overlay.visible = dev_overlay_visible
	if dev_overlay_visible:
		debug_overlay.text = _format_debug_metrics()

func _update_debug_metrics(checksum_valid: bool, tick_latency_ms: float, eigen_payload: Dictionary, payload_size: int) -> void:
	latest_debug_metrics = {
		"payload_size": payload_size,
		"checksum_valid": checksum_valid,
		"version": int(eigen_payload.get("version_id", -1)),
		"energy_nodes": int(eigen_payload.get("energy_graph", []).size()),
		"heat_max": _heat_max(eigen_payload.get("heat_map", [])),
		"tick_latency_ms": tick_latency_ms,
	}
	if dev_overlay_visible:
		debug_overlay.text = _format_debug_metrics()

func _heat_max(heat_map: Array) -> float:
	var value: float = 0.0
	for item: Variant in heat_map:
		if item is Dictionary:
			value = maxf(value, float(item.get("value", 0.0)))
	return value

func _format_debug_metrics() -> String:
	return "Payload: %d B\nChecksum: %s\nVersion: %d\nEnergy nodes: %d\nHeat max: %.2f\nTick latency: %.2f ms" % [
		int(latest_debug_metrics.get("payload_size", 0)),
		"OK" if bool(latest_debug_metrics.get("checksum_valid", false)) else "FAIL",
		int(latest_debug_metrics.get("version", -1)),
		int(latest_debug_metrics.get("energy_nodes", 0)),
		float(latest_debug_metrics.get("heat_max", 0.0)),
		float(latest_debug_metrics.get("tick_latency_ms", 0.0)),
	]
