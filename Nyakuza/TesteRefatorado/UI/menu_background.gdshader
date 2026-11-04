shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec3 sky = mix(vec3(0.025, 0.018, 0.07), vec3(0.17, 0.035, 0.18), UV.y);
	float sun = 1.0 - smoothstep(0.155, 0.16, length((UV - vec2(0.73, 0.38)) * vec2(1.0, 0.7)));
	float stripes = step(0.24, fract(UV.y * 68.0));
	sky += sun * stripes * vec3(0.35, 0.065, 0.16);
	float column = floor(UV.x * 32.0);
	float height = 0.12 + fract(sin(column * 75.31) * 531.91) * 0.26;
	float city = step(1.0 - height, UV.y);
	sky = mix(sky, vec3(0.018, 0.014, 0.045), city);
	float windows = step(0.86, fract(UV.x * 96.0)) * step(0.76, fract(UV.y * 65.0)) * city;
	sky += windows * vec3(0.02, 0.15, 0.20);
	float horizon = smoothstep(0.57, 0.59, UV.y);
	float lanes = pow(max(0.0, cos((UV.x - 0.5) / max(1.05 - UV.y, 0.05) * 24.0)), 40.0);
	float rows = pow(max(0.0, cos(17.0 / max(1.05 - UV.y, 0.05))), 30.0);
	sky += max(lanes, rows) * horizon * vec3(0.08, 0.035, 0.15) * 0.45;
	COLOR = vec4(sky, 1.0);
}
