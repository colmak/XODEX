# GODOT 4.6.1 STRICT – THERMAL VISUAL MAPPING v0.00.4.x
extends RefCounted

class_name HeatVisuals

const STATE_NORMAL: StringName = &"normal"
const STATE_STRESSED: StringName = &"stressed"
const STATE_OVERHEATED: StringName = &"overheated"
const STATE_RECOVERING: StringName = &"recovering"

# Simulation-layer hook: These thresholds must match Python/Haskell mirrors.
const STRESS_THRESHOLD: float = 0.50
const CRITICAL_THRESHOLD: float = 0.85
const OVERHEAT_THRESHOLD: float = 1.0

static func classify_state(normalized_heat: float, overheated: bool) -> StringName:
	if overheated or normalized_heat >= OVERHEAT_THRESHOLD:
		return STATE_OVERHEATED
	if normalized_heat >= CRITICAL_THRESHOLD:
		return STATE_RECOVERING
	if normalized_heat >= STRESS_THRESHOLD:
		return STATE_STRESSED
	return STATE_NORMAL

static func radial_opacity(normalized_heat: float) -> float:
	# Simulation-layer hook: lower bound visibility starts at 0.30 for mobile readability.
	if normalized_heat <= STRESS_THRESHOLD:
		return 0.30
	var t: float = clampf((normalized_heat - STRESS_THRESHOLD) / (OVERHEAT_THRESHOLD - STRESS_THRESHOLD), 0.0, 1.0)
	return lerpf(0.30, 1.0, t)

static func gradient_color(normalized_heat: float, cool: Color, stressed: Color, critical: Color) -> Color:
	var clamped_heat: float = clampf(normalized_heat, 0.0, 1.0)
	if clamped_heat <= STRESS_THRESHOLD:
		var cool_t: float = clamped_heat / maxf(STRESS_THRESHOLD, 0.001)
		return cool.lerp(stressed, cool_t)
	var hot_t: float = (clamped_heat - STRESS_THRESHOLD) / maxf(1.0 - STRESS_THRESHOLD, 0.001)
	return stressed.lerp(critical, hot_t)
