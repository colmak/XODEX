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
