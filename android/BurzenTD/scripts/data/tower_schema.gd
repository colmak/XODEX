# GODOT 4.6.1 STRICT – TOWER SCHEMA V1 COMPAT
extends RefCounted

class_name TowerSchema

const DEFAULT_PATH: String = "res://data/towers/tower_definitions.json"

static func load_catalog(path: String = DEFAULT_PATH) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var root: Dictionary = Dictionary(parsed)
	var towers_variant: Variant = root.get("towers", [])
	if typeof(towers_variant) != TYPE_ARRAY:
		return []
	var tower_items: Array = towers_variant
	var loaded: Array[Dictionary] = []
	for item: Variant in tower_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		loaded.append(normalize_tower(Dictionary(item), root))
	return loaded

static func normalize_tower(tower: Dictionary, schema_root: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = tower.duplicate(true)
	var base_stats: Dictionary = Dictionary(normalized.get("base_stats", {}))
	var economy: Dictionary = Dictionary(base_stats.get("economy", {}))
	var heat: Dictionary = Dictionary(base_stats.get("heat", {}))
	var binding: Dictionary = Dictionary(base_stats.get("binding", {}))
	var combat: Dictionary = Dictionary(base_stats.get("combat", {}))
	if economy.is_empty() and normalized.has("build_cost"):
		economy["build_cost"] = int(normalized.get("build_cost", 0))
	if heat.is_empty() and normalized.has("heat_gen_rate"):
		heat["generation_rate"] = float(normalized.get("heat_gen_rate", 0.0))
		heat["tolerance_label"] = str(normalized.get("heat_tolerance", "medium"))
		heat["tolerance_value"] = float(normalized.get("heat_tolerance_value", 0.8))
	if binding.is_empty() and normalized.has("residue_class"):
		binding["residue_class"] = str(normalized.get("residue_class", "nonpolar"))
		binding["preferred_partner"] = str(normalized.get("preferred_bind", "any"))
		binding["affinity_modifiers"] = Dictionary(normalized.get("affinity_modifiers", {})).duplicate(true)
	if combat.is_empty():
		combat["folding_role"] = str(normalized.get("folding_role", "general"))
		combat["radius"] = float(normalized.get("radius", 180.0))
	if not economy.is_empty() or not heat.is_empty() or not binding.is_empty() or not combat.is_empty():
		base_stats["economy"] = economy
		base_stats["heat"] = heat
		base_stats["binding"] = binding
		base_stats["combat"] = combat
		normalized["base_stats"] = base_stats
	_apply_compatibility_aliases(normalized, schema_root)
	return normalized

static func _apply_compatibility_aliases(normalized: Dictionary, schema_root: Dictionary) -> void:
	var compatibility: Dictionary = Dictionary(schema_root.get("compatibility_layer", {}))
	var legacy_map: Dictionary = Dictionary(compatibility.get("legacy_key_map", {}))
	var mappings: Dictionary = {
		"heat_gen_rate": "base_stats.heat.generation_rate",
		"build_cost": "base_stats.economy.build_cost",
		"heat_tolerance": "base_stats.heat.tolerance_label",
		"heat_tolerance_value": "base_stats.heat.tolerance_value",
		"preferred_bind": "base_stats.binding.preferred_partner",
		"residue_class": "base_stats.binding.residue_class",
		"affinity_modifiers": "base_stats.binding.affinity_modifiers",
		"folding_role": "base_stats.combat.folding_role",
		"radius": "base_stats.combat.radius",
	}
	for key: String in legacy_map.keys():
		mappings[key] = str(legacy_map[key])
	for legacy_key: String in mappings.keys():
		if normalized.has(legacy_key):
			continue
		var value: Variant = _get_path(normalized, str(mappings[legacy_key]))
		if value != null:
			normalized[legacy_key] = value

static func _get_path(root: Dictionary, path: String) -> Variant:
	var cursor: Variant = root
	for segment: String in path.split("."):
		if typeof(cursor) != TYPE_DICTIONARY:
			return null
		var cursor_dict: Dictionary = Dictionary(cursor)
		if not cursor_dict.has(segment):
			return null
		cursor = cursor_dict[segment]
	return cursor
