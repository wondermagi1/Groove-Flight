shader_type canvas_item;
render_mode unshaded, blend_add;
uniform int style=0;
uniform float intensity=.28;
varying vec4 tint;
varying vec4 detail;
void vertex(){tint=COLOR; detail=INSTANCE_CUSTOM;}
void fragment(){
 vec2 p=(UV-.5)*2.;
 float bloom=exp(-dot(p*vec2(1.65,2.),p*vec2(1.65,2.))*1.6);
 float plume=exp(-abs(p.y)*14./max(.15,1.-p.x))*smoothstep(-1.,-.5,p.x)*(1.-smoothstep(-.08,.28,p.x));
 float modulation=.85+.15*sin(detail.x*26.+p.x*18.+detail.y*6.);
 if(style==3 || style==10 || style==11) bloom+=plume*modulation*.45;
 else if(style==0 || style==1 || style==6) bloom+=plume*.2;
 else if(style==7) bloom*=.65;
 float fade=min(1.,detail.z*10.);
 COLOR=vec4(tint.rgb,bloom*intensity*tint.a*fade);
}
