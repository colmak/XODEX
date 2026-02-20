extends Node

class_name AudioController

const ARC_I_LEVEL_END: int = 3
const ARC_II_LEVEL_END: int = 7

const HEAT_CLEAN_MAX: float = 0.5
const HEAT_SAT_MAX: float = 0.75
const HEAT_RESONANCE_MAX: float = 0.9

const MIN_PITCH_SCALE: float = 0.75
const MAX_PITCH_SCALE: float = 1.25

const ARC_BPM: Dictionary = {
	1: Vector2(90.0, 100.0),
	2: Vector2(105.0, 125.0),
	3: Vector2(125.0, 135.0),
}

@export var base_layer_path: NodePath
@export var percussion_layer_path: NodePath
@export var harmonic_layer_path: NodePath
@export var tension_layer_path: NodePath
@export var heat_layer_path: NodePath

@export var wave_start_stinger_path: NodePath
@export var miniboss_stinger_path: NodePath
@export var final_wave_stinger_path: NodePath
@export var victory_stinger_path: NodePath
@export var defeat_stinger_path: NodePath

var _base_layer: AudioStreamPlayer = null
var _percussion_layer: AudioStreamPlayer = null
var _harmonic_layer: AudioStreamPlayer = null
var _tension_layer: AudioStreamPlayer = null
var _heat_layer: AudioStreamPlayer = null

var _wave_start_stinger: AudioStreamPlayer = null
var _miniboss_stinger: AudioStreamPlayer = null
var _final_wave_stinger: AudioStreamPlayer = null
var _victory_stinger: AudioStreamPlayer = null
var _defeat_stinger: AudioStreamPlayer = null

var _last_wave_number: int = -1
var _last_level: int = 1

func _ready() -> void:
	_base_layer = get_node_or_null(base_layer_path) as AudioStreamPlayer
	_percussion_layer = get_node_or_null(percussion_layer_path) as AudioStreamPlayer
	_harmonic_layer = get_node_or_null(harmonic_layer_path) as AudioStreamPlayer
	_tension_layer = get_node_or_null(tension_layer_path) as AudioStreamPlayer
	_heat_layer = get_node_or_null(heat_layer_path) as AudioStreamPlayer
	_wave_start_stinger = get_node_or_null(wave_start_stinger_path) as AudioStreamPlayer
	_miniboss_stinger = get_node_or_null(miniboss_stinger_path) as AudioStreamPlayer
	_final_wave_stinger = get_node_or_null(final_wave_stinger_path) as AudioStreamPlayer
	_victory_stinger = get_node_or_null(victory_stinger_path) as AudioStreamPlayer
	_defeat_stinger = get_node_or_null(defeat_stinger_path) as AudioStreamPlayer
	_ensure_loop(_base_layer)
	_ensure_loop(_percussion_layer)
	_ensure_loop(_harmonic_layer)
	_ensure_loop(_tension_layer)
	_ensure_loop(_heat_layer)
	_play_if_ready(_base_layer)
	_play_if_ready(_percussion_layer)
	_play_if_ready(_harmonic_layer)
	_play_if_ready(_tension_layer)
	_play_if_ready(_heat_layer)

func apply_eigenstate_projection(eigen: Dictionary) -> void:
	var level_state: Dictionary = eigen.get("level_state", {})
	var level_number: int = int(level_state.get("level", _last_level))
	var wave_number: int = int(level_state.get("wave", eigen.get("wave_number", 0)))
	var total_waves: int = int(level_state.get("total_waves", 0))
	var phase_state: String = str(eigen.get("level_phase_state", _phase_from_level(level_number)))

	var energy_total: float = _norm(float(eigen.get("energy_total", _energy_hint(eigen))))
	var heat_max: float = _norm(float(eigen.get("heat_max", _heat_hint(eigen))))
	var mob_density: float = _norm(float(eigen.get("mob_density", _mob_hint(eigen))))
	var entropy_index: float = _norm(float(eigen.get("tower_entropy_index", eigen.get("entropy_index", 0.0))))

	var arc: int = _arc_from_level(level_number)
	_apply_tempo(arc, wave_number)
	_apply_layers(energy_total, heat_max, mob_density, entropy_index, phase_state)
	_apply_heat_signature(heat_max)
	_trigger_wave_stingers(wave_number, total_waves)
	_last_wave_number = wave_number
	_last_level = level_number

func play_victory_stinger() -> void:
	_play_stinger(_victory_stinger)

func play_defeat_stinger() -> void:
	_play_stinger(_defeat_stinger)

func _apply_tempo(arc: int, wave_number: int) -> void:
	var bpm_range: Vector2 = ARC_BPM.get(arc, Vector2(100.0, 110.0))
	var wave_ratio: float = clampf(float(wave_number) / 10.0, 0.0, 1.0)
	var bpm: float = lerpf(bpm_range.x, bpm_range.y, wave_ratio)
	var pitch_scale: float = clampf(bpm / 120.0, MIN_PITCH_SCALE, MAX_PITCH_SCALE)
	_set_pitch_scale(_base_layer, pitch_scale)
	_set_pitch_scale(_percussion_layer, pitch_scale)
	_set_pitch_scale(_harmonic_layer, pitch_scale)
	_set_pitch_scale(_tension_layer, pitch_scale)
	_set_pitch_scale(_heat_layer, pitch_scale)

func _apply_layers(energy_total: float, heat_max: float, mob_density: float, entropy_index: float, phase_state: String) -> void:
	_set_volume_linear(_base_layer, 0.5 + (energy_total * 0.4))
	_set_volume_linear(_percussion_layer, 0.2 + (mob_density * 0.8))
	_set_volume_linear(_harmonic_layer, 0.25 + (energy_total * 0.65))
	_set_volume_linear(_tension_layer, 0.1 + (entropy_index * 0.8))
	_set_volume_linear(_heat_layer, 0.05 + (heat_max * 0.95))

	if phase_state == "stabilized" or phase_state == "resolution":
		_set_volume_linear(_tension_layer, _volume_to_linear(_tension_layer) * 0.5)
		_set_volume_linear(_harmonic_layer, minf(_volume_to_linear(_harmonic_layer) + 0.15, 1.0))

func _apply_heat_signature(heat_max: float) -> void:
	if heat_max < HEAT_CLEAN_MAX:
		_set_bus_effect_amount(0.0, 0.0, 0.0)
	elif heat_max < HEAT_SAT_MAX:
		_set_bus_effect_amount(remap(heat_max, HEAT_CLEAN_MAX, HEAT_SAT_MAX, 0.15, 0.35), 0.0, 0.0)
	elif heat_max < HEAT_RESONANCE_MAX:
		_set_bus_effect_amount(0.4, remap(heat_max, HEAT_SAT_MAX, HEAT_RESONANCE_MAX, 0.2, 0.75), 0.0)
	else:
		_set_bus_effect_amount(0.6, 0.85, remap(heat_max, HEAT_RESONANCE_MAX, 1.0, 0.3, 1.0))

func _trigger_wave_stingers(wave_number: int, total_waves: int) -> void:
	if _last_wave_number < 0:
		return
	if wave_number > _last_wave_number:
		_play_stinger(_wave_start_stinger)
		if total_waves > 0 and wave_number >= total_waves:
			_play_stinger(_final_wave_stinger)
		elif wave_number % 5 == 0:
			_play_stinger(_miniboss_stinger)

func _set_bus_effect_amount(saturation: float, resonance: float, noise: float) -> void:
	# Deterministic bus volume controls used as a CODEX-safe proxy for effect drive.
	if _heat_layer == null:
		return
	_set_volume_linear(_heat_layer, clampf(0.1 + saturation + (noise * 0.2), 0.0, 1.0))
	if _tension_layer != null:
		_set_volume_linear(_tension_layer, clampf(_volume_to_linear(_tension_layer) + (resonance * 0.15), 0.0, 1.0))

func _phase_from_level(level_number: int) -> String:
	if level_number <= ARC_I_LEVEL_END:
		return "emergence"
	if level_number <= ARC_II_LEVEL_END:
		return "entropy_growth"
	return "controlled_collapse"

func _arc_from_level(level_number: int) -> int:
	if level_number <= ARC_I_LEVEL_END:
		return 1
	if level_number <= ARC_II_LEVEL_END:
		return 2
	return 3

func _energy_hint(eigen: Dictionary) -> float:
	var energy_graph: Array = eigen.get("energy_graph", [])
	if energy_graph.is_empty():
		return 0.0
	var total: float = 0.0
	for point: Variant in energy_graph:
		if point is Dictionary:
			total += float((point as Dictionary).get("value", 0.0))
	return clampf(total / float(maxi(energy_graph.size(), 1)), 0.0, 1.0)

func _heat_hint(eigen: Dictionary) -> float:
	var heat_map: Array = eigen.get("heat_map", [])
	var peak: float = 0.0
	for point: Variant in heat_map:
		if point is Dictionary:
			peak = maxf(peak, float((point as Dictionary).get("value", 0.0)))
	return clampf(peak, 0.0, 1.0)

func _mob_hint(eigen: Dictionary) -> float:
	var mobs: Array = eigen.get("mobs", [])
	return clampf(float(mobs.size()) / 80.0, 0.0, 1.0)

func _set_volume_linear(player: AudioStreamPlayer, linear: float) -> void:
	if player == null:
		return
	var clamped: float = clampf(linear, 0.001, 1.0)
	player.volume_db = linear_to_db(clamped)

func _volume_to_linear(player: AudioStreamPlayer) -> float:
	if player == null:
		return 0.0
	return db_to_linear(player.volume_db)

func _set_pitch_scale(player: AudioStreamPlayer, value: float) -> void:
	if player == null:
		return
	player.pitch_scale = value

func _play_stinger(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.stream == null:
		return
	player.play()

func _play_if_ready(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.stream == null:
		return
	player.play()

func _ensure_loop(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = true
	elif player.stream is AudioStreamWAV:
		(player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func _norm(value: float) -> float:
	return clampf(value, 0.0, 1.0)
