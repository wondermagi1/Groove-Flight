shader_type canvas_item;
render_mode unshaded, blend_add;
uniform int style=0;
uniform float intensity=.28;
varying vec4 tint;
varying vec4 detail;
void vertex(){tint=COLOR; detail=INSTANCE_CUSTOM;}
void fragment(){
 vec2 p=(UV-.5)*2.;
 vec2 falloff=p*vec2(2.,2.5);
 float bloom=exp(-dot(falloff,falloff)*2.);
 float plume=exp(-abs(p.y)*14./max(.15,1.-p.x))*smoothstep(-1.,-.5,p.x)*(1.-smoothstep(-.08,.28,p.x));
 float modulation=.85+.15*sin(detail.x*26.+p.x*18.+detail.y*6.);
 vec3 hue=tint.rgb;
 if(style==3 || style==10 || style==11){
  bloom+=plume*modulation*1.45;
  hue=mix(hue,vec3(1.,.64,.32),clamp(plume,0.,.66));
 }else if(style==1){
  bloom+=plume*.58;
 }else if(style==4){
  float radius=length(p);
  bloom=.66*bloom+exp(-abs(radius-.44)*16.)*.16;
 }else if(style==7){
  bloom=.50*bloom+exp(-abs(length(p)-.49)*18.)*.12;
 }else if(style==0 || style==6) bloom+=plume*.9;
 float fade=min(1.,detail.z*10.);
 COLOR=vec4(hue,bloom*intensity*tint.a*fade);
}
