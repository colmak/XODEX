# GODOT 4.6.1 STRICT – MOBILE UI v0.00.7
extends Node

var total_damage: float = 0.0
var per_tower_damage: Dictionary = {}

func reset() -> void:
	total_damage = 0.0
	per_tower_damage.clear()

func record_damage(tower_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	total_damage += amount
	per_tower_damage[tower_id] = float(per_tower_damage.get(tower_id, 0.0)) + amount

func get_total_damage() -> float:
	return total_damage

func get_per_tower_damage() -> Dictionary:
	return per_tower_damage.duplicate(true)
