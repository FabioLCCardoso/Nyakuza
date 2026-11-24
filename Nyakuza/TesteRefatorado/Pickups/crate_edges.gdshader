shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;

// Object-space edges stay continuous at BoxMesh UV seams.
uniform vec3 half_extent = vec3(0.58);
varying vec3 box_position;
void vertex() {
	box_position = VERTEX;
}
void fragment() {
	vec3 p = abs(box_position) / half_extent;
	float edge = max(min(p.x, p.y), max(min(p.x, p.z), min(p.y, p.z)));
	ALPHA = smoothstep(0.89, 0.99, edge) * (0.74 + 0.18 * sin(TIME * 3.0));
	ALBEDO = vec3(1.1, 2.2, 0.7);
}
