shader_type spatial;
render_mode unshaded;

uniform vec4 base_color : source_color = vec4(1.0);
uniform bool luminous = false;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 key = normalize(vec3(-0.48, 0.82, 0.72));
	float lambert = dot(n, key);
	float band = lambert > 0.22 ? 1.0 : (lambert > -0.22 ? 0.62 : 0.30);
	vec3 shadow_tint = mix(vec3(0.72, 0.84, 1.0), vec3(1.0), band);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.5);
	vec3 color = base_color.rgb * band * shadow_tint;
	color += vec3(0.28, 0.40, 0.49) * rim * max(lambert, 0.0) * 0.35;
	ALBEDO = luminous ? base_color.rgb : color;
}
