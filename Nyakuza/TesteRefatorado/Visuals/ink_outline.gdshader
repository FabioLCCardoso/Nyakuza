shader_type spatial;
render_mode unshaded, cull_front, world_vertex_coords, shadows_disabled;
uniform vec4 ink_color : source_color = vec4(0.018, 0.012, 0.035, 1.0);
uniform float width : hint_range(0.0, 0.06) = 0.012;
void vertex() {
	VERTEX += normalize(NORMAL) * width;
}
void fragment() {
	ALBEDO = ink_color.rgb;
}
