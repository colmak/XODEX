extends Node

var _pending_frames: Array[String] = []
var _campaign_root: Node = null

func _ready() -> void:
	set_process_unhandled_input(true)

func replay_from_xdx1(fragment: String) -> void:
	var parsed: Dictionary = CodexFrameDecoder.parse_campaign_url(fragment)
	if not bool(parsed.get("valid", false)):
		push_warning("Replay rejected: %s" % str(parsed.get("reason", "unknown")))
		return
	_campaign_root = _resolve_campaign_root()
	if _campaign_root == null:
		push_warning("Replay rejected: missing CampaignRoot")
		return
	_campaign_root.call("reset_state_machine")
	_pending_frames = parsed.get("sequence", [])
	_campaign_root.call("inject_deterministic_sequence", _pending_frames, int(parsed.get("seed", 0)))
	_pending_frames.clear()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("sim_step"):
		return
	if _campaign_root == null:
		_campaign_root = _resolve_campaign_root()
	if _campaign_root == null or _pending_frames.is_empty():
		return
	var next_frame: String = _pending_frames.pop_front()
	_campaign_root.call("process_codex_frame", next_frame)

func _resolve_campaign_root() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	if scene.has_method("reset_state_machine") and scene.has_method("inject_deterministic_sequence"):
		return scene
	return scene.find_child("CampaignRoot", true, false)
