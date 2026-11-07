shader_type canvas_item;
render_mode unshaded, blend_add;
varying vec4 tint;
varying vec4 detail;
void vertex(){tint=COLOR; detail=INSTANCE_CUSTOM;}
float hash(float n){return .5+.5*cos(n*2.399963+detail.w*6.283185);}
float noise(float x){float i=floor(x),f=fract(x); return mix(hash(i),hash(i+1.),f);}
void fragment(){
 vec2 p=(UV-.5)*2.; float t=detail.y;
 int mode=int(round(detail.x*5.));
 float fade=pow(max(0.,1.-t),1.3),core=0.,glow=0.;
 if(mode<=1){
  float y=p.y;
  if(mode==1) y-= (noise(UV.x*22.)-.5)*.65*sin(UV.x*3.14159265);
  float ends=smoothstep(0.,.018,UV.x)*(1.-smoothstep(.982,1.,UV.x));
  core=exp(-abs(y)*42.)*ends;
  float sheath=exp(-abs(y)*11.)*ends;
  float filament=exp(-abs(abs(y)-.22)*48.)*ends;
  if(mode==1) sheath+=exp(-abs(y+.20*sin(UV.x*23.))*28.)*.22*ends;
  else sheath*=.85+.15*sin(UV.x*70.-t*28.);
  glow=exp(-abs(y)*6.)*ends*.10+sheath*.22+filament*.06;
 }else{
  float r=length(p),a=atan(p.y,p.x);
  if(mode==2){
   core=exp(-r*(14.+t*16.));
   float rays=pow(max(0.,cos(a*6.+detail.w*6.)),22.);
   glow=exp(-r*8.)*.6+rays*exp(-r*5.)*.72;
  }else if(mode==3){
   float ring=exp(-abs(r-(.12+t*.7))*55.);
   float rays=pow(max(0.,cos(a*9.+detail.w*6.)),22.)*exp(-r*5.);
   core=exp(-r*16.)*max(0.,1.-t*5.);
   glow=ring*.48+rays*.48+exp(-r*7.)*max(0.,1.-t*4.);
  }else if(mode==4){
   float cone=exp(-abs(p.y)*(9.+p.x*3.))*exp(-abs(p.x)*4.);
   core=exp(-length(p*vec2(1.,2.))*15.);
   glow=cone*.8+exp(-length(p)*7.)*.3;
  }else{
   core=exp(-r*r*55.)*(1.-t)*.95;
   float spokes=pow(max(0.,cos(a*6.)),26.);
   glow=exp(-r*r*6.)*.32+spokes*exp(-r*6.)*(1.-t)*.45;
  }
 }
 float edge=1.-smoothstep(.86,1.,(mode<=1 ? abs(p.y) : max(abs(p.x),abs(p.y))));
 float strength=detail.z;
 vec3 col=mix(tint.rgb,vec3(1.),core*.82);
 COLOR=vec4(col,min(.95,core+glow)*fade*edge*strength*tint.a);
}
