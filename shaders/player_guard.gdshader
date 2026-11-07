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
 float halo=exp(-r*r*5.)*.17;
 float shell=exp(-abs(r-(.47+.025*sin(elapsed*3.)))*37.)*.22;
 float dome=exp(-r*r*12.)*.23;
 float core=exp(-r*23.)*(.2+flash*1.1);
 float rays=pow(max(0.,cos(a*6.+elapsed*.26)),28.)*exp(-r*5.)*(.045+flash*.65)*detail_level;
 float rim=exp(-abs(r-(.13+min(elapsed,.5)*1.35))*55.)*exp(-elapsed*6.)*.5;
 float alpha=(halo+shell+dome+core+rays+rim)*strength*remaining_fade*breathe;
 vec3 blue=mix(vec3(.13,.52,1.),vec3(.72,.9,1.),clamp(core*1.4+rays,.0,1.));
 COLOR=vec4(blue,alpha*(1.-smoothstep(.83,1.,r)));
}
