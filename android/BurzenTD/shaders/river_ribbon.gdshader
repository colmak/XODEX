shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(0.36, 0.92, 1.0, 0.8);
uniform vec4 edge_color : source_color = vec4(0.08, 0.28, 0.64, 0.65);
uniform float flow_speed = 0.65;
uniform float pulse_strength = 0.22;

void fragment() {
	float flow = sin((UV.x + TIME * flow_speed) * 20.0) * 0.5 + 0.5;
	float edge = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	vec4 c = mix(edge_color, core_color, edge);
	c.rgb += flow * pulse_strength * vec3(0.25, 0.55, 0.8);
	COLOR = c;
}
