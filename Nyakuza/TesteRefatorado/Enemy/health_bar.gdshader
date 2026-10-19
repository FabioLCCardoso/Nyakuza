shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float ratio = 1.0;
uniform vec4 fg_color : source_color = vec4(0.9, 0.12, 0.12, 1.0);
uniform vec4 bg_color : source_color = vec4(0.04, 0.04, 0.04, 0.85);
void vertex() {
	// billboard: sempre de frente para a camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 c = UV.x <= ratio ? fg_color : bg_color;
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
