shader_type canvas_item;

uniform vec4 residue_color : source_color = vec4(0.56, 0.44, 0.36, 1.0);
uniform float life_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_speed : hint_range(0.1, 8.0) = 2.5;
uniform float noise_scale : hint_range(2.0, 64.0) = 18.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.55;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float radial = length(centered) * 2.0;
	float falloff = smoothstep(1.0, 0.1, radial);

	float n = hash21(floor(uv * noise_scale));
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed + n * 6.28318530718);
	float life = clamp(life_ratio, 0.0, 1.0);

	float alpha = falloff * pulse * life * intensity;
	vec3 rgb = residue_color.rgb * (0.55 + 0.45 * pulse);
	COLOR = vec4(rgb, alpha * residue_color.a);
}
