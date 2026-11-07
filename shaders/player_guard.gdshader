shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float elapsed=0.;
uniform float strength=1.;
uniform float remaining_fade=1.;
uniform float detail_level=1.;
void fragment(){
 vec2 p=(UV-.5)*2.; float r=length(p),a=atan(p.y,p.x);
 float flash=exp(-elapsed*10.);
 float breathe=.92+.08*sin(elapsed*5.);
 float halo=exp(-r*r*4.5)*.34;
 float shell=exp(-abs(r-(.47+.025*sin(elapsed*3.)))*32.)*.045;
 float dome=exp(-r*r*12.)*.32;
 float core=exp(-r*r*70.)*(.55+flash*1.35);
 float rays=pow(max(0.,cos(a*6.+elapsed*.12)),32.)*exp(-r*5.)*(.12+flash*.55)*detail_level;
 rays+=(exp(-abs(p.x)*85.)+exp(-abs(p.y)*85.))*exp(-r*4.)*(.09+flash*.2)*detail_level;
 float rim=exp(-abs(r-(.13+min(elapsed,.5)*1.35))*55.)*exp(-elapsed*8.)*.12;
 float alpha=(halo+shell+dome+core+rays+rim)*strength*remaining_fade*breathe;
 vec3 blue=mix(vec3(.13,.45,1.),vec3(1.,1.,1.),clamp(core*1.8+rays,.0,1.));
 COLOR=vec4(blue,alpha*(1.-smoothstep(.83,1.,r)));
}
