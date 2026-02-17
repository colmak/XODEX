# GODOT 4.6.1 STRICT – DEMO CAMPAIGN v0.00.6
extends Node2D

class_name TowerBase

@export var tower_id: String = ""
@export var residue_class: String = "special"
@export var heat_gen_rate: float = 0.5
@export var heat_tolerance: float = 1.0
@export var preferred_bind: String = "special"
@export var special_ability: String = ""

func to_definition() -> Dictionary:
	return {
		"tower_id": tower_id,
		"residue_class": residue_class,
		"heat_gen_rate": heat_gen_rate,
		"heat_tolerance_value": heat_tolerance,
		"preferred_bind": preferred_bind,
		"special_ability": special_ability,
	}
