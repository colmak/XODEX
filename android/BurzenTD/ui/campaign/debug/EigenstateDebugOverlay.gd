extends Control

class_name EigenstateDebugOverlay

const RING_BUFFER_SIZE: int = 3

@onready var version_label: Label = %VersionLabel
@onready var status_label: Label = %StatusLabel

var ring_buffer: Array[Dictionary] = []

func _ready() -> void:
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		queue_free()
		return
	visible = bool(ProjectSettings.get_setting("debug/enable_eigenstate_overlay", false))

func toggle_overlay() -> void:
	visible = not visible

func update_metadata(meta: Dictionary) -> void:
	if not is_inside_tree():
		return
	var version_id: int = int(meta.get("version_id", 0))
	var checksum8: int = int(meta.get("checksum8", 0))
	var status: String = str(meta.get("status", "UNKNOWN"))
	version_label.text = "vID: %016X  chk: %02X" % [version_id, checksum8]
	status_label.text = "%s  payload=%dB decode=%dus" % [status, int(meta.get("payload_size", 0)), int(meta.get("decode_us", 0))]
	status_label.modulate = Color.GREEN if status == "VALID" else Color.RED
	ring_buffer.push_back(meta.duplicate(true))
	if ring_buffer.size() > RING_BUFFER_SIZE:
		ring_buffer.pop_front()
	queue_redraw()

func _draw() -> void:
	if ring_buffer.is_empty():
		return
	var origin: Vector2 = Vector2(12.0, 60.0)
	var w: float = 24.0
	for i: int in range(ring_buffer.size()):
		var item: Dictionary = ring_buffer[i]
		var status: String = str(item.get("status", "UNKNOWN"))
		var col: Color = Color(0.9, 0.2, 0.2, 0.85)
		if status == "VALID":
			col = Color(0.2, 0.9, 0.2, 0.85)
		draw_rect(Rect2(origin + Vector2(i * (w + 8.0), 0.0), Vector2(w, 18.0)), col)
