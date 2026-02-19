# GODOT 4.6.1 STRICT – DEMO CAMPAIGN v0.00.7
extends Node2D

class_name TowerBase

@export var tower_id: String = ""
@export var residue_class: String = "special"
@export var heat_gen_rate: float = 0.5
@export var heat_tolerance: float = 1.0
@export var preferred_bind: String = "special"
@export var special_ability: String = ""
@export var render_radius: float = 20.0
@export var outline_width: float = 3.0
@export var tower_color: Color = Color("#67e8f9")

var _attack_indicator_timer: float = 0.0
var _attack_target_global: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _attack_indicator_timer <= 0.0:
		return
	_attack_indicator_timer = maxf(0.0, _attack_indicator_timer - delta)
	queue_redraw()

func _draw() -> void:
	# Mobile-first readable fallback render so towers remain visible even without sprite assets.
	draw_circle(Vector2.ZERO, render_radius, tower_color)
	draw_arc(Vector2.ZERO, render_radius + 3.5, 0.0, TAU, 48, Color(0.96, 0.99, 1.0, 0.85), outline_width, true)
	if _attack_indicator_timer > 0.0:
		var target_local: Vector2 = to_local(_attack_target_global)
		draw_line(Vector2.ZERO, target_local, Color(1.0, 0.45, 0.35, 0.9), 3.0)

func apply_runtime_definition(definition: Dictionary) -> void:
	# Simulation-layer hook: mirrors may pass deterministic tower metadata through this adapter.
	tower_id = str(definition.get("tower_id", tower_id))
	residue_class = str(definition.get("residue_class", residue_class))
	heat_gen_rate = float(definition.get("heat_gen_rate", heat_gen_rate))
	heat_tolerance = float(definition.get("heat_tolerance_value", heat_tolerance))
	preferred_bind = str(definition.get("preferred_bind", preferred_bind))
	special_ability = str(definition.get("special_ability", special_ability))
	_render_from_residue_class()
	queue_redraw()

func trigger_attack_indicator(target_global_pos: Vector2) -> void:
	_attack_target_global = target_global_pos
	_attack_indicator_timer = 0.12
	queue_redraw()

func _render_from_residue_class() -> void:
	match residue_class:
		"nonpolar":
			tower_color = Color("#e879f9")
		"polar_uncharged":
			tower_color = Color("#38bdf8")
		"positively_charged":
			tower_color = Color("#f97316")
		"negatively_charged":
			tower_color = Color("#22d3ee")
		"keystone":
			tower_color = Color("#818cf8")
		_:
			tower_color = Color("#facc15")

func to_definition() -> Dictionary:
	return {
		"tower_id": tower_id,
		"residue_class": residue_class,
		"heat_gen_rate": heat_gen_rate,
		"heat_tolerance_value": heat_tolerance,
		"preferred_bind": preferred_bind,
		"special_ability": special_ability,
	}
