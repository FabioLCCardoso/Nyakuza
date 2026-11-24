shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 aura_color : source_color = vec4(.03,.35,1.,1.);
uniform float phase = 0.0;
uniform float intensity = 1.0;
void vertex() {
	// Camera-facing quads preserve emitter scale, including particle scale.
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	facing[2].xyz *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
	float y = 1.0-UV.y;
	float wobble = sin(y*12.0-phase*8.0)*.09 + sin(y*23.0+phase*5.0)*.035;
	float width = mix(.35,.015,y);
	float body = 1.0-smoothstep(width*.25,width,abs(UV.x-.5+wobble*y));
	float ends = smoothstep(0.,.16,y)*(1.-smoothstep(.75,1.,y));
	float flicker = .8+.2*sin(phase*13.0+y*17.0);
	ALBEDO = mix(aura_color.rgb,vec3(.8,.95,1.),body*.12);
	EMISSION = ALBEDO * 1.6;
	ALPHA = body*ends*flicker*COLOR.a*.55*intensity;
}
