shader_type spatial;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 cell=abs(fract(world_pos.xz/3.0)-0.5);
 float grid=smoothstep(0.485,0.498,max(cell.x,cell.y));
 ALBEDO=vec3(0.025,0.023,0.05); ROUGHNESS=0.34; METALLIC=0.15;
 EMISSION=vec3(0.12,0.035,0.3)*grid*0.35;
}
