shader_type spatial;
render_mode cull_back;
uniform sampler2D pose_positions : filter_nearest, repeat_disable;
uniform sampler2D pose_normals : filter_nearest, repeat_disable;
uniform float lengths[6];
uniform int frames_per_clip = 8;
uniform float clock_time = 0.0;
varying float flags;

void vertex() {
	int clip = int(INSTANCE_CUSTOM.r + 0.5);
	float phase = fract((clock_time * INSTANCE_CUSTOM.g + INSTANCE_CUSTOM.b) / max(lengths[clip], 0.01));
	float frame = phase * float(frames_per_clip);
	int a = int(floor(frame));
	int b = (a + 1) % frames_per_clip;
	int index = int(UV2.x + 0.5);
	VERTEX = mix(texelFetch(pose_positions, ivec2(index, clip*frames_per_clip+a), 0).xyz, texelFetch(pose_positions, ivec2(index, clip*frames_per_clip+b), 0).xyz, fract(frame));
	NORMAL = normalize(mix(texelFetch(pose_normals, ivec2(index, clip*frames_per_clip+a), 0).xyz, texelFetch(pose_normals, ivec2(index, clip*frames_per_clip+b), 0).xyz, fract(frame)));
	flags = UV2.y;
	int tool = int(flags + 0.5) % 4;
	if ((tool == 1 && clip != 3 && clip != 4) || (tool == 2 && clip != 5)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	METALLIC = float(int(flags + 0.5) / 8) * 0.55;
	EMISSION = COLOR.rgb * float((int(flags + 0.5) / 4) % 2) * 1.5;
}
