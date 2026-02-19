shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float ring_radius : hint_range(0.05, 0.50) = 0.34;
uniform float ring_thickness : hint_range(0.005, 0.20) = 0.05;
uniform vec4 cool_color : source_color = vec4(0.22, 0.74, 0.97, 1.0);
uniform vec4 stressed_color : source_color = vec4(0.96, 0.62, 0.04, 1.0);
uniform vec4 critical_color : source_color = vec4(0.94, 0.27, 0.27, 1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.30;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;

float map_heat_opacity(float ratio) {
	if (ratio <= 0.5) {
		return base_opacity;
	}
	float t = clamp((ratio - 0.5) / 0.5, 0.0, 1.0);
	return mix(base_opacity, 1.0, t);
}

vec4 map_heat_color(float ratio) {
	if (ratio <= 0.5) {
		float t0 = clamp(ratio / 0.5, 0.0, 1.0);
		return mix(cool_color, stressed_color, t0);
	}
	float t1 = clamp((ratio - 0.5) / 0.5, 0.0, 1.0);
	return mix(stressed_color, critical_color, t1);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);
	float arc_angle = mod(angle + 1.57079632679 + 6.28318530718, 6.28318530718);
	float sweep = clamp(fill_ratio, 0.0, 1.0) * 6.28318530718;

	float outer = ring_radius + ring_thickness;
	float inner = ring_radius - ring_thickness;
	float ring_mask = smoothstep(outer + 0.01, outer - 0.01, dist) * smoothstep(inner - 0.01, inner + 0.01, dist);
	float fill_mask = step(arc_angle, sweep);
	float opacity = map_heat_opacity(fill_ratio);
	vec4 color = map_heat_color(fill_ratio);

	float glow_band = smoothstep(outer + 0.06, outer - 0.01, dist);
	float glow = pow(glow_band, 2.0) * fill_mask * glow_strength * (0.2 + 0.8 * fill_ratio);

	float alpha = ring_mask * fill_mask * opacity;
	COLOR = vec4(color.rgb + glow * color.rgb, alpha + glow * 0.35 * opacity);
}
