extends Node

class_name FoldingBridge

signal fold_tick_ready(delta_payload: Dictionary)
signal graph_delta_ready(delta_payload: Dictionary)

var affinity_table: Dictionary = {}
var environment_state: Dictionary = {
	"thermal_state": 0.0,
	"ph": 7.0,
	"phosphorylation_flags": [],
}

func configure_affinity_table(table: Dictionary) -> void:
	affinity_table = table.duplicate(true)

func configure_environment(next_env: Dictionary) -> void:
	for key in next_env.keys():
		environment_state[key] = next_env[key]

func apply_wasmutable_patch(patch: Dictionary) -> void:
	# Hot-swappable rules for post-translational style tuning.
	if patch.has("affinity_table"):
		configure_affinity_table(patch["affinity_table"])
	if patch.has("environment"):
		configure_environment(patch["environment"])

func project_fold_tick(nodes: Array, bonds: Array, domains: Array, global_energy: float) -> Dictionary:
	# Godot side stays thin: receives Codex-computed deterministic deltas only.
	var payload: Dictionary = {
		"node_count": nodes.size(),
		"bond_count": bonds.size(),
		"domain_count": domains.size(),
		"global_energy": global_energy,
		"environment_state": environment_state.duplicate(true),
	}
	emit_signal("fold_tick_ready", payload)
	return payload


func project_graph_delta(towers: Array, bonds: Array, graph_stats: Dictionary) -> Dictionary:
	var payload: Dictionary = {
		"tower_count": towers.size(),
		"bond_count": bonds.size(),
		"graph_stats": graph_stats.duplicate(true),
	}
	emit_signal("graph_delta_ready", payload)
	return payload

func can_place_without_spoc_violation(candidate_energy_spike: float, steric_clash_score: float) -> bool:
	return candidate_energy_spike <= 8.0 and steric_clash_score <= 1.0
