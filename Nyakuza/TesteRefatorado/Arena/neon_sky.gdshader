shader_type sky;
void sky(){
 float h=clamp(EYEDIR.y,0.0,1.0);
 COLOR=mix(vec3(0.16,0.025,0.23),vec3(0.015,0.008,0.06),pow(h,0.6));
 vec3 sun_dir=normalize(vec3(0.05,0.55,-1.0));
 float disk=smoothstep(0.975,0.978,dot(EYEDIR,sun_dir));
 float stripes=step(0.25,fract(EYEDIR.y*65.0));
 COLOR=mix(COLOR,mix(vec3(1.0,0.06,0.3),vec3(1.0,0.5,0.2),h),disk*stripes);
}
