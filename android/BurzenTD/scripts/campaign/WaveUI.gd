extends Control

class_name CampaignWaveUI

@onready var wave_label: Label = %WaveLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var countdown_label: Label = %CountdownLabel

func update_from_state(level_state: Dictionary) -> void:
	var wave: int = int(level_state.get("wave", 1))
	var total_waves: int = int(level_state.get("total_waves", 10))
	var enemies_remaining: int = int(level_state.get("enemies_remaining", 0))
	var next_wave_eta: float = float(level_state.get("next_wave_eta", 0.0))
	wave_label.text = "Wave %d/%d" % [wave, total_waves]
	enemies_label.text = "Enemies: %d" % enemies_remaining
	countdown_label.text = "Next in %.1fs" % maxf(0.0, next_wave_eta)
