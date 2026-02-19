shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(0.32, 0.41, 0.45, 0.52);
uniform vec4 edge_color : source_color = vec4(0.18, 0.24, 0.29, 0.44);
uniform float flow_speed = 0.45;
uniform float pulse_strength = 0.05;

void fragment() {
	float flow = sin((UV.x + TIME * flow_speed) * 20.0) * 0.5 + 0.5;
	float edge = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	vec4 c = mix(edge_color, core_color, edge);
	c.rgb += flow * pulse_strength * vec3(0.20, 0.22, 0.24);
	COLOR = c;
}
