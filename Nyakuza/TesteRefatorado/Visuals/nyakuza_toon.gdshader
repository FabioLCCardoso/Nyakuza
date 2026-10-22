shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
// Tres faixas, sombras coloridas e rim discreto. Opaco: sem ALPHA.
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 shadow_color : source_color = vec4(0.17, 0.12, 0.24, 1.0);
uniform vec4 mid_color : source_color = vec4(0.64, 0.58, 0.73, 1.0);
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.08;
uniform float light_threshold : hint_range(-1.0, 1.0) = 0.58;
uniform float edge_softness : hint_range(0.001, 0.3) = 0.045;
uniform float ambient_floor : hint_range(0.0, 0.5) = 0.14;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform vec4 rim_color : source_color = vec4(0.58, 0.76, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float rim_power : hint_range(1.0, 12.0) = 4.0;
uniform float hatch_strength : hint_range(0.0, 0.5) = 0.08;
uniform float hatch_scale : hint_range(4.0, 100.0) = 36.0;
varying float hatch;
void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb * base_color.rgb;
	float gray = dot(tex, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = max(mix(vec3(gray), tex, saturation), vec3(0.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = ALBEDO * shadow_color.rgb * ambient_floor;
	hatch = smoothstep(0.45, 0.65, sin((UV.x + UV.y) * hatch_scale * TAU));
}
void light() {
	float n = dot(normalize(NORMAL), normalize(LIGHT));
	float soft = max(edge_softness, 0.001);
	float mid = smoothstep(shadow_threshold - soft, shadow_threshold + soft, n);
	float bright = smoothstep(light_threshold - soft, light_threshold + soft, n);
	vec3 bands = mix(shadow_color.rgb, mid_color.rgb, mid);
	bands = mix(bands, vec3(1.0), bright);
	bands *= 1.0 - hatch_strength * hatch * (1.0 - mid);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	// Godot aplica ALBEDO ao resultado difuso; nao multiplicar a textura duas vezes.
	vec3 lighting = bands + rim_color.rgb * rim * rim_strength * mid;
	DIFFUSE_LIGHT += lighting * LIGHT_COLOR * ATTENUATION / PI;
}
