shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform int style = 0;
varying vec4 tint;
varying vec4 detail;
void vertex(){ tint=COLOR; detail=INSTANCE_CUSTOM; }
float capsule(vec2 p,vec2 a,vec2 b,float r){
 vec2 v=p-a,w=b-a; return length(v-w*clamp(dot(v,w)/dot(w,w),0.,1.))-r;
}
float hexagon(vec2 p,float r){return max(abs(p.y),abs(p.x)*.8660254+abs(p.y)*.5)-r;}
void fragment(){
 vec2 p=(UV-.5)*2.; float age=detail.x,seed=detail.y,variant=detail.w;
 float d=1.,core=0.,trim=0.,surface=0.;
 if(style==0 || style==2 || style==5){
  d=capsule(p,vec2(-.52,0),vec2(.52,0),.28);
  core=exp(-abs(p.y)*12.)*smoothstep(-.85,-.25,p.x);
  trim=exp(-abs(abs(p.y)-.2)*40.)*.45;
  if(style==0 && variant>.75){d=abs(p.y)*.8+abs(p.x)*.22-.23; core=exp(-abs(p.y)*28.);}
  else if(style==0 && variant>.25){d=min(capsule(p,vec2(-.5,.18),vec2(.5,.18),.13),capsule(p,vec2(-.5,-.18),vec2(.5,-.18),.13));}
  if(style==2 && variant>.25) trim+=exp(-abs(p.x+.35)*35.)*.7;
 }else if(style==1){
  float spine=.085*(p.x*p.x-.36);
  float span=.62*pow(max(0.,1.-p.x*p.x),.72)*(.93+.07*p.x);
  d=max(abs(p.x)-.98,abs(p.y-spine)-span);
  float section=(p.y-spine)/max(.09,span);
  float lit_face=exp(-abs(section+.24)*3.6);
  core=exp(-abs(section)*5.8)*smoothstep(-.85,.24,p.x);
  trim=lit_face*(.45+.25*smoothstep(-.25,.80,p.x));
 }else if(style==3){
  float hull=max(abs(p.y)-.27,max(-.66-p.x,p.x+abs(p.y)*.8-.76));
  float fins=max(abs(p.x+.46)-.16,abs(p.y)-.62);
  d=min(hull,fins); surface=1.;
  core=exp(-length((p-vec2(.45,0))*vec2(2.,1.))*7.);
  float panel=exp(-abs(p.x+.24+p.y*.32)*35.)+exp(-abs(p.x-.34)*42.);
  float nozzle=exp(-abs(p.x+.60)*43.)*exp(-abs(p.y)*5.);
  trim=panel*.46*step(abs(p.y),.27)+step(.42,abs(p.y))*.32+nozzle*.86;
  if(variant>.25) trim+=pow(max(0.,cos(p.x*23.)),12.)*.4*step(abs(p.y),.25);
 }else if(style==4){
  float r=length(p);
  float a=atan(p.y,p.x);
  d=r-(.62+.023*cos(a*4.+seed*4.));
  float shell=.46+.039*sin(a*3.-age*8.+seed*6.);
  core=exp(-length(p-vec2(.13,-.12))*4.8);
  trim=exp(-abs(r-shell)*29.)*.62+exp(-abs(r-.59)*38.)*.27;
 }else if(style==6){
  d=abs(p.y)*.8+abs(p.x)*.24-.22;
  core=exp(-abs(p.y)*25.); trim=exp(-abs(abs(p.y)-.13)*50.)*.45;
 }else if(style==7){
  d=max(length(p)-.81,-(length(p-vec2(.38,-.12))-.69));
  if(variant>.75) d=min(d,max(abs(p.x)*.7+abs(p.y)*.5-.20,-p.x));
  surface=1.;
  float r=length(p);
  float a=atan(p.y,p.x);
  float inlays=pow(max(0.,cos(a*9.+seed*6.)),8.);
  core=exp(-abs(r-.72)*30.)*(.48+.52*inlays);
  trim=exp(-abs(r-.57)*42.)*.72+inlays*exp(-abs(r-.67)*30.)*.35;
 }else if(style==8 || style==9){
  float h=hexagon(p,.68); d=h;
  if(variant>.25) d=max(d,-(length(p)-.22)); surface=1.;
  float r=length(p); core=exp(-r*11.);
  trim=exp(-abs(h+.09)*60.)*.9+exp(-abs(r-.34)*55.)*.65;
  float spokes=pow(max(0.,cos(atan(p.y,p.x)*6.+seed*6.)),12.);
  trim+=spokes*step(.4,r)*.55;
 }else if(style==10){
  float wobble=.07*sin(p.x*17.-age*28.+seed*9.);
  d=length(vec2((p.x+.08)*.9,(p.y+wobble)*(1.6+.9*p.x)))-.72;
  core=exp(-length(vec2(p.x-.23,p.y*2.))*5.);
  trim=pow(max(0.,sin(p.x*28.+p.y*13.-age*18.)),12.)*.35;
 }else{
  float fuselage=max(abs(p.x)-.7,abs(p.y)-.15);
  float wings=max(abs(p.y)-.69,max(p.x*.8+abs(p.y)*.8-.37,-p.x-.6));
  d=min(fuselage,wings); surface=1.;
  core=exp(-length((p-vec2(.34,0))*vec2(2.,1.))*10.);
  trim=exp(-abs(abs(p.y)-.4)*35.)*step(p.x,.0)*.7;
 }
 float aa=max(fwidth(d),.012); float mask=1.-smoothstep(-aa,aa,d);
 float bevel=smoothstep(-.15,-.04,d)*(1.-smoothstep(.0,aa,d));
 float specular=pow(max(0.,dot(normalize(p+vec2(.001)),normalize(vec2(-.56,.83)))),10.)*smoothstep(-.08,.18,d);
 vec3 energy=mix(tint.rgb*.55,vec3(1.,.97,.9),clamp(core*.73+trim*.52,0.,.88));
 vec3 metal=mix(vec3(.055,.082,.13),vec3(.67,.78,.88),clamp(.54-p.y*.64,0.,1.));
 metal=mix(metal,tint.rgb,clamp(trim+core,.0,.85));
 metal+=vec3(.55,.72,.82)*specular*.42;
 vec3 color=mix(energy,metal,surface);
 color+=tint.rgb*bevel*.27+vec3(core*.25);
 float fade=min(1.,detail.z*12.);
 COLOR=vec4(color,mask*tint.a*fade);
}
