shader_type spatial;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool terrain = false;
uniform float map_size = 512.0;
uniform float surface_alpha = 1.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float sight = texture(visibility_map, world_position.xz / map_size).r;
	if (!terrain && sight < 0.05) { discard; }
	vec3 color = terrain ? COLOR.rgb : base_color.rgb;
	float lighting = smoothstep(0.0, 1.0, sight);
	ALBEDO = mix(vec3(0.012, 0.019, 0.03), color, lighting);
	ROUGHNESS = 0.86;
	ALPHA = surface_alpha;
}
