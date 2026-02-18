# GODOT 4.6.1 STRICT – DECISION ENGINE UI v0.01.0
extends Control

class_name LevelCompleteScreen

signal replay_pressed
signal next_pressed

@onready var title_label: Label = %TitleLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var replay_button: Button = %ReplayButton
@onready var next_button: Button = %NextButton

func _ready() -> void:
	visible = false
	replay_button.pressed.connect(func() -> void: emit_signal("replay_pressed"))
	next_button.pressed.connect(func() -> void: emit_signal("next_pressed"))

func show_results(results: Dictionary) -> void:
	visible = true
	var stars: int = int(results.get("stars", 0))
	title_label.text = "Level Complete %s" % "★".repeat(stars)
	stats_label.text = "[b]Damage[/b] %d\n[b]Peak Heat[/b] %d°C\n[b]Bonds[/b] %d\n[b]Efficiency[/b] %.2f\n%s" % [
		int(results.get("damage", 0.0)),
		int(results.get("peak_heat", 0.0)),
		int(results.get("bonds", 0)),
		float(results.get("efficiency", 0.0)),
		str(results.get("summary", "")),
	]
	if results.has("loadout"):
		stats_label.text += "\n\n[b]Meta[/b] %s" % str(results.get("loadout", ""))
