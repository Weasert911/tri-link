shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform float outline_width : hint_range(0.0, 0.05) = 0.004;
uniform vec3 outline_color : source_color = vec3(0.008, 0.012, 0.035);

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color;
}
