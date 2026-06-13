shader_type spatial;
render_mode blend_add, unshaded, cull_back;

uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.1, 1.0);
uniform float rim_width : hint_range(0.0, 1.0) = 0.15;
uniform float rim_sharpness : hint_range(1.0, 30.0) = 15.0;

void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, normalize(VIEW_VEC)));
	rim = smoothstep(1.0 - rim_width, 1.0, rim);
	rim *= rim_sharpness * 0.1;
	rim = clamp(rim, 0.0, 1.0);
	ALBEDO = rim_color.rgb * rim;
	EMISSION = rim_color.rgb * rim * 2.0;
	ALPHA = rim;
}
