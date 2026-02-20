extends Control

class_name WaveUI

@onready var wave_label: Label = %WaveLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var countdown_label: Label = %CountdownLabel

func update_from_level_state(level_state: Dictionary) -> void:
	var wave: int = int(level_state.get("wave", 0))
	var total_waves: int = int(level_state.get("total_waves", 10))
	var enemies_remaining: int = int(level_state.get("enemies_remaining", 0))
	var next_countdown: float = float(level_state.get("next_wave_countdown", 0.0))
	wave_label.text = "Wave %d/%d" % [wave, total_waves]
	enemies_label.text = "Enemies %d" % enemies_remaining
	countdown_label.text = "Next %.1fs" % maxf(next_countdown, 0.0)
