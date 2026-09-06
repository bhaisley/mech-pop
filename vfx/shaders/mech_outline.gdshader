shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.009;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = vec3(0.004, 0.010, 0.025);
}
