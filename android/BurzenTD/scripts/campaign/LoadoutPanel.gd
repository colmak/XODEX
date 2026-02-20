extends Control

class_name LoadoutPanel

signal loadout_locked(selected_ids: Array[String])

const MAX_SELECTION: int = 4

@onready var selection_label: Label = %SelectionLabel
@onready var lock_button: Button = %LockButton
@onready var replay_button: Button = %ReplayButton
@onready var list_container: VBoxContainer = %TowerList

var _selected_ids: Array[String] = []
var _locked: bool = false

func _ready() -> void:
	lock_button.pressed.connect(_lock_selection)
	replay_button.pressed.connect(_open_replay_prompt)
	_update_header()

func configure_towers(tower_defs: Array[Dictionary]) -> void:
	for child: Node in list_container.get_children():
		child.queue_free()
	for tower_def: Dictionary in tower_defs:
		var button: CheckButton = CheckButton.new()
		button.text = "%s (%s)" % [str(tower_def.get("name", "Tower")), str(tower_def.get("id", "unknown"))]
		button.disabled = _locked
		button.toggled.connect(func(pressed: bool) -> void:
			_on_tower_toggled(str(tower_def.get("id", "")), pressed)
		)
		list_container.add_child(button)
	_update_header()

func get_selected_ids() -> Array[String]:
	return _selected_ids.duplicate()

func set_read_only(read_only: bool) -> void:
	_locked = read_only
	for child: Node in list_container.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = read_only
	lock_button.disabled = read_only
	_update_header()

func _on_tower_toggled(tower_id: String, pressed: bool) -> void:
	if _locked or tower_id.is_empty():
		return
	if pressed:
		if _selected_ids.has(tower_id):
			return
		if _selected_ids.size() >= MAX_SELECTION:
			_revert_toggle(tower_id, false)
			return
		_selected_ids.append(tower_id)
	else:
		_selected_ids.erase(tower_id)
	_update_header()

func _revert_toggle(tower_id: String, expected_state: bool) -> void:
	for child: Node in list_container.get_children():
		if child is CheckButton:
			var toggle: CheckButton = child as CheckButton
			if toggle.text.ends_with("(%s)" % tower_id):
				toggle.button_pressed = expected_state
				break

func _lock_selection() -> void:
	if _selected_ids.size() != MAX_SELECTION:
		return
	set_read_only(true)
	emit_signal("loadout_locked", _selected_ids.duplicate())

func _update_header() -> void:
	selection_label.text = "Loadout %d/%d" % [_selected_ids.size(), MAX_SELECTION]
	if _locked:
		lock_button.text = "Locked"
	elif _selected_ids.size() == MAX_SELECTION:
		lock_button.text = "Start Level"
	else:
		lock_button.text = "Pick %d More" % (MAX_SELECTION - _selected_ids.size())

func _open_replay_prompt() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "CODEX Replay"
	dialog.dialog_text = "Paste XDX1 URL or fragment:"
	var line: LineEdit = LineEdit.new()
	line.placeholder_text = "#XDX1.<payload>.<checksum8>"
	dialog.add_child(line)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if has_node("/root/CodexReplayService"):
			get_node("/root/CodexReplayService").call("replay_from_xdx1", line.text)
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(540, 180))
