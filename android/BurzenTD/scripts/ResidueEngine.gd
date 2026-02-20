# GODOT 4.6.1 STRICT TYPING – CLEAN FIRST LAUNCH
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

static var _last_eigenstate: Dictionary = {}
static var _last_version_id: int = -1

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


static func apply_eigenstate_vector(eigenstate: Variant) -> Dictionary:
	if eigenstate is PackedFloat32Array:
		return _apply_legacy_eigenstate_vector(eigenstate)
	if not (eigenstate is Dictionary):
		return {"accepted": false, "reason": "invalid_payload"}

	var next_state: Dictionary = (eigenstate as Dictionary).duplicate(true)
	var version_id: int = int(next_state.get("version_id", -1))
	if version_id <= _last_version_id:
		return {"accepted": false, "reason": "out_of_order", "version_id": version_id, "last_version_id": _last_version_id}

	if bool(next_state.get("checksum_valid", true)) == false:
		return {"accepted": false, "reason": "checksum_failed", "version_id": version_id, "request_resend": true}

	var diff: Dictionary = _build_diff(_last_eigenstate, next_state)
	var render_update: Dictionary = {
		"accepted": true,
		"version_id": version_id,
		"spawn_towers": _spawn_despawn_towers(diff),
		"tower_updates": _update_positions(next_state),
		"energy_overlay": _update_energy_levels(next_state),
		"heat_overlay": _update_heat_overlay(next_state),
		"mobs": _update_mob_states(next_state),
		"wave_ui": _update_wave_ui(next_state),
		"diff": diff,
	}

	_last_version_id = version_id
	_last_eigenstate = next_state
	return render_update


static func _apply_legacy_eigenstate_vector(eigenstate: PackedFloat32Array) -> Dictionary:
	if eigenstate.size() < 6:
		return {"residue_class": &"special", "residue_slots": [EMPTY_SLOT, EMPTY_SLOT, EMPTY_SLOT, EMPTY_SLOT]}
	var index: int = int(clampf(eigenstate[1], 0.0, 0.999) * float(RESIDUE_CLASSES.size()))
	var residue_class: StringName = RESIDUE_CLASSES[index]
	var energy_hint: float = clampf(eigenstate[0], 0.0, 1.0)
	var heat_hint: float = clampf(1.0 - eigenstate[3], 0.0, 1.0)
	return {
		"residue_class": residue_class,
		"residue_slots": [residue_class, residue_class, EMPTY_SLOT, EMPTY_SLOT],
		"energy_hint": energy_hint,
		"heat_hint": heat_hint,
	}


static func _build_diff(previous_state: Dictionary, next_state: Dictionary) -> Dictionary:
	var previous_towers: Array = previous_state.get("towers", [])
	var next_towers: Array = next_state.get("towers", [])
	var previous_mobs: Array = previous_state.get("mobs", [])
	var next_mobs: Array = next_state.get("mobs", [])
	return {
		"spawn_tower_ids": _id_diff(previous_towers, next_towers),
		"despawn_tower_ids": _id_diff(next_towers, previous_towers),
		"spawn_mob_ids": _id_diff(previous_mobs, next_mobs),
		"despawn_mob_ids": _id_diff(next_mobs, previous_mobs),
	}

static func _id_diff(left: Array, right: Array) -> Array[String]:
	var right_ids: Dictionary = {}
	for entry: Variant in right:
		if entry is Dictionary:
			right_ids[str(entry.get("id", ""))] = true
	var ids: Array[String] = []
	for entry: Variant in left:
		if not (entry is Dictionary):
			continue
		var identifier: String = str(entry.get("id", ""))
		if identifier.is_empty():
			continue
		if not right_ids.has(identifier):
			ids.append(identifier)
	return ids

static func _spawn_despawn_towers(diff: Dictionary) -> Dictionary:
	return {
		"spawn": diff.get("spawn_tower_ids", []),
		"despawn": diff.get("despawn_tower_ids", []),
	}

static func _update_positions(next_state: Dictionary) -> Array:
	var updates: Array = []
	for tower: Variant in next_state.get("towers", []):
		if tower is Dictionary:
			updates.append({
				"id": str(tower.get("id", "")),
				"position": tower.get("position", Vector2.ZERO),
				"archetype": str(tower.get("archetype", "")),
			})
	return updates

static func _update_energy_levels(next_state: Dictionary) -> Dictionary:
	return {
		"energy_graph": next_state.get("energy_graph", []),
		"link_count": (next_state.get("energy_graph", []) as Array).size(),
	}

static func _update_heat_overlay(next_state: Dictionary) -> Dictionary:
	var heat_map: Array = next_state.get("heat_map", [])
	var heat_max: float = 0.0
	for point: Variant in heat_map:
		if point is Dictionary:
			heat_max = maxf(heat_max, float(point.get("value", 0.0)))
	return {
		"heat_map": heat_map,
		"heat_max": heat_max,
	}

static func _update_mob_states(next_state: Dictionary) -> Array:
	var result: Array = []
	for mob: Variant in next_state.get("mobs", []):
		if mob is Dictionary:
			result.append({
				"id": str(mob.get("id", "")),
				"position": mob.get("position", Vector2.ZERO),
				"hp": float(mob.get("hp", 0.0)),
			})
	return result

static func _update_wave_ui(next_state: Dictionary) -> Dictionary:
	return next_state.get("level_state", {"wave": 0, "time": 0.0, "integrity": 1.0})
