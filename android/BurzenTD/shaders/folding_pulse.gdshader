shader_type canvas_item;

uniform float fold_progress : hint_range(0.0, 1.0) = 0.0;
uniform float heat_level : hint_range(0.0, 1.0) = 0.0;
uniform vec4 native_tint : source_color = vec4(0.27, 0.85, 0.55, 1.0);
uniform vec4 misfold_tint : source_color = vec4(0.95, 0.35, 0.35, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = 0.5 + 0.5 * sin(TIME * 6.0 + UV.x * 12.0);
	float blend = clamp(fold_progress + heat_level * 0.5, 0.0, 1.0);
	vec4 fold_color = mix(native_tint, misfold_tint, heat_level);
	COLOR = mix(tex, fold_color, 0.3 * blend + 0.2 * pulse * fold_progress);
}
