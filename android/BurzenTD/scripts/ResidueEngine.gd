# GODOT 4.6.1 STRICT TYPING – CAMPAIGN MEMBRANE v0.8
extends RefCounted

class_name ResidueEngine

const MAX_RESIDUE_SLOTS: int = 4
const EMPTY_SLOT: StringName = &"empty"

const RESIDUE_CLASSES: Array[StringName] = [
	&"nonpolar",
	&"polar_uncharged",
	&"positively_charged",
	&"negatively_charged",
	&"special",
]

const DEFAULT_RESIDUE_BY_TOWER: Dictionary = {
	"triangle": &"nonpolar",
	"square": &"nonpolar",
	"rectangle": &"nonpolar",
	"fire": &"positively_charged",
	"water": &"polar_uncharged",
	"earth": &"special",
	"air": &"negatively_charged",
	"zhe": &"special",
}

var previous_eigenstate: Dictionary = {}

static func normalize_tower_definition(definition: Dictionary) -> Dictionary:
	var normalized: Dictionary = definition.duplicate(true)
	var residue_class: StringName = classify_tower_id(str(definition.get("id", "")))
	if definition.has("residue_class"):
		residue_class = _sanitize_residue_class(StringName(definition["residue_class"]))
	normalized["residue_class"] = residue_class
	normalized["residue_slots"] = normalize_residue_slots(definition, residue_class)
	return normalized

static func normalize_residue_slots(definition: Dictionary, fallback_residue: StringName = &"special") -> Array[StringName]:
	var normalized_slots: Array[StringName] = []
	var residue_inputs: Array = []
	if definition.has("residue_slots"):
		residue_inputs = definition["residue_slots"]
	elif definition.has("base_residues"):
		residue_inputs = definition["base_residues"]

	for input_value: Variant in residue_inputs:
		if normalized_slots.size() >= MAX_RESIDUE_SLOTS:
			break
		if input_value is Dictionary:
			var residue_id: StringName = StringName(input_value.get("id", fallback_residue))
			normalized_slots.append(_sanitize_residue_class(residue_id))
		else:
			normalized_slots.append(_sanitize_residue_class(StringName(input_value)))

	if normalized_slots.is_empty():
		normalized_slots.append(_sanitize_residue_class(fallback_residue))

	while normalized_slots.size() < MAX_RESIDUE_SLOTS:
		normalized_slots.append(EMPTY_SLOT)

	return normalized_slots

static func classify_tower_id(tower_id: String) -> StringName:
	return StringName(DEFAULT_RESIDUE_BY_TOWER.get(tower_id, &"special"))

static func is_valid_residue_class(residue_class: StringName) -> bool:
	return RESIDUE_CLASSES.has(residue_class)

static func _sanitize_residue_class(residue_class: StringName) -> StringName:
	if is_valid_residue_class(residue_class):
		return residue_class
	return &"special"

func apply_eigenstate_vector(eigen: Dictionary, membrane_nodes: Dictionary = {}) -> Dictionary:
	var delta: Dictionary = _compute_diff(previous_eigenstate, eigen)
	_update_towers(eigen.get("towers", []), membrane_nodes.get("tower_container", null))
	_update_mobs(eigen.get("mobs", []), membrane_nodes.get("mob_container", null))
	_update_energy_overlay(eigen.get("energy_graph", []), membrane_nodes.get("energy_overlay", null))
	_update_heat_overlay(eigen.get("heat_map", []), membrane_nodes.get("energy_overlay", null))
	_update_wave_ui(eigen.get("level_state", {}), membrane_nodes.get("wave_ui", null), membrane_nodes.get("progress_bar", null))
	previous_eigenstate = eigen.duplicate(true)
	return delta

func _compute_diff(previous: Dictionary, current: Dictionary) -> Dictionary:
	var previous_towers: Dictionary = _index_by_id(previous.get("towers", []))
	var next_towers: Dictionary = _index_by_id(current.get("towers", []))
	var spawned: Array[int] = []
	var despawned: Array[int] = []
	var updated: Array[int] = []
	for tower_id: Variant in next_towers.keys():
		if not previous_towers.has(tower_id):
			spawned.append(int(tower_id))
		elif previous_towers[tower_id] != next_towers[tower_id]:
			updated.append(int(tower_id))
	for tower_id: Variant in previous_towers.keys():
		if not next_towers.has(tower_id):
			despawned.append(int(tower_id))
	return {"spawned": spawned, "despawned": despawned, "updated": updated}

func _index_by_id(items: Array) -> Dictionary:
	var index: Dictionary = {}
	for item: Variant in items:
		if item is Dictionary:
			index[int(item.get("id", -1))] = item
	return index

func _update_towers(towers: Array, tower_container: Node) -> void:
	if tower_container == null:
		return
	var by_name: Dictionary = {}
	for child: Node in tower_container.get_children():
		by_name[child.name] = child
	for tower_data: Variant in towers:
		if not (tower_data is Dictionary):
			continue
		var tower_id: int = int(tower_data.get("id", -1))
		var node_name: String = "Tower_%d" % tower_id
		var node: Node2D = by_name.get(node_name, null)
		if node == null:
			node = Node2D.new()
			node.name = node_name
			tower_container.add_child(node)
		node.position = tower_data.get("pos", Vector2.ZERO)
		var energy: float = clampf(float(tower_data.get("energy", 0.0)), 0.0, 1.0)
		node.modulate = Color(0.3 + (0.7 * energy), 0.4 + (0.4 * energy), 1.0, 1.0)
	for child: Node in tower_container.get_children():
		if not _has_id(towers, child.name.trim_prefix("Tower_").to_int()):
			child.queue_free()

func _update_mobs(mobs: Array, mob_container: Node) -> void:
	if mob_container == null:
		return
	while mob_container.get_child_count() > mobs.size():
		mob_container.get_child(0).queue_free()
	for i: int in range(mobs.size()):
		var node: Node2D = mob_container.get_child(i) if i < mob_container.get_child_count() else Node2D.new()
		if node.get_parent() == null:
			node.name = "Mob_%d" % i
			mob_container.add_child(node)
		var mob: Dictionary = mobs[i]
		node.position = mob.get("pos", Vector2.ZERO)

func _update_energy_overlay(energy_graph: Array, overlay: Node) -> void:
	if overlay != null and overlay.has_method("update_energy_overlay"):
		overlay.call("update_energy_overlay", energy_graph)

func _update_heat_overlay(heat_map: Array, overlay: Node) -> void:
	if overlay != null and overlay.has_method("update_heat_overlay"):
		overlay.call("update_heat_overlay", heat_map)

func _update_wave_ui(level_state: Dictionary, wave_ui: Node, progress_bar: Node) -> void:
	if wave_ui != null and wave_ui.has_method("update_from_state"):
		wave_ui.call("update_from_state", level_state)
	if progress_bar is ProgressBar:
		var level_number: int = int(level_state.get("level", 1))
		(progress_bar as ProgressBar).value = clampi(level_number, 1, 10)

func _has_id(items: Array, tower_id: int) -> bool:
	for item: Variant in items:
		if item is Dictionary and int(item.get("id", -1)) == tower_id:
			return true
	return false
