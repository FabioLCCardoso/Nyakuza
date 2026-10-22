shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 cut_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.38;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float diagonal = sin((UV.x * 7.0 + UV.y * 4.0 - TIME * 1.8) * TAU);
	float other = sin((UV.x * 5.0 - UV.y * 6.0 + TIME * 2.1) * TAU);
	float cuts = max(smoothstep(0.975, 0.998, diagonal), smoothstep(0.98, 0.998, other));
	ALBEDO = mix(cut_color.rgb, vec3(0.9, 0.98, 1.0), cuts);
	ALPHA = opacity * clamp(0.04 + rim * 0.5 + cuts, 0.0, 1.0);
}
