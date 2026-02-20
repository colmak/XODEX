extends Control

class_name CampaignLoadoutPanel

signal loadout_locked(selected_tower_ids: Array[String])

const SLOT_LIMIT: int = 4
const CORE_TOWERS: Array[String] = [
	"kinetic",
	"thermal",
	"energy",
	"reaction",
	"pulse",
	"field",
	"conversion",
	"control",
]

var selected: Array[String] = []
var level_started: bool = false

@onready var tower_list: ItemList = %CoreTowerList
@onready var selection_label: Label = %SelectionLabel
@onready var lock_button: Button = %LockSelectionButton

func _ready() -> void:
	for tower_id: String in CORE_TOWERS:
		tower_list.add_item(tower_id.capitalize())
	tower_list.multi_selected.connect(_on_multi_selected)
	lock_button.pressed.connect(_on_lock_pressed)
	_update_ui()

func set_level_started(started: bool) -> void:
	level_started = started
	tower_list.select_mode = ItemList.SELECT_SINGLE if started else ItemList.SELECT_MULTI
	lock_button.disabled = started

func get_selected_loadout() -> Array[String]:
	return selected.duplicate()

func _on_multi_selected(index: int, selected_state: bool) -> void:
	if level_started:
		tower_list.deselect(index)
		return
	var tower_id: String = CORE_TOWERS[index]
	if selected_state:
		if selected.has(tower_id):
			return
		if selected.size() >= SLOT_LIMIT:
			tower_list.deselect(index)
			return
		selected.append(tower_id)
	else:
		selected.erase(tower_id)
	_update_ui()

func _on_lock_pressed() -> void:
	if selected.size() != SLOT_LIMIT:
		return
	set_level_started(true)
	emit_signal("loadout_locked", get_selected_loadout())
	_update_ui()

func _update_ui() -> void:
	selection_label.text = "Loadout %d/%d" % [selected.size(), SLOT_LIMIT]
	lock_button.text = "Locked" if level_started else "Lock 4-Slot Loadout"
	lock_button.disabled = level_started or selected.size() != SLOT_LIMIT
