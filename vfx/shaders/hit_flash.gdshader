shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float amount = 0.0;
void fragment() {
	ALBEDO = vec3(0.7, 0.95, 1.0);
	ALPHA = amount;
}
