shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
void fragment() {
 float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
 float bands = 0.6 + 0.4 * sin(UV.y * 45.0 - phase * 8.0 + sin(UV.x * 30.0 + phase));
 ALBEDO = vec3(0.03, 0.35, 1.0);
 EMISSION = vec3(0.02, 0.18, 0.8);
 ALPHA = (0.07 + edge * 0.48) * bands;
}
