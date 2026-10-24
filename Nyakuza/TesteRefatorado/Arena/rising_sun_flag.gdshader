shader_type spatial;
render_mode cull_disabled;
uniform vec4 sun_color: source_color = vec4(0.8,0.015,0.06,1.0);
uniform vec4 cloth_color: source_color = vec4(0.95,0.87,0.77,1.0);
void vertex(){VERTEX.y+=sin(UV.x*10.0+TIME*2.2)*0.1*UV.x;}
void fragment(){vec2 p=(UV-vec2(0.42,0.5))*vec2(1.55,1.0);float rays=step(0.0,sin(atan(p.y,p.x)*16.0));float sun=1.0-smoothstep(0.16,0.17,length(p));ALBEDO=mix(cloth_color.rgb,sun_color.rgb,max(rays,sun));ROUGHNESS=0.9;}
