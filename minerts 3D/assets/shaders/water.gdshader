shader_type spatial;
render_mode blend_mix, cull_disabled;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform float surface_alpha = 1.0;
varying vec3 world_position;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.48, 0.49, 0.88);
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(VERTEX.x * 0.65 + TIME * 0.8) * cos(VERTEX.z * 0.43 + TIME * 0.6) * 0.035;
}
void fragment() {
	float ripple = sin(UV.x * 340.0 + TIME * 1.3) * sin(UV.y * 270.0 - TIME * 0.7);
	float sight = texture(visibility_map, world_position.xz / 512.0).r;
	ALBEDO = mix(vec3(0.012, 0.019, 0.03), shallow_color.rgb + ripple * 0.025, sight);
	ROUGHNESS = 0.26;
	METALLIC = 0.15;
	ALPHA = shallow_color.a * surface_alpha;
}
