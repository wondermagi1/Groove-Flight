shader_type canvas_item;
render_mode unshaded;
// Original graphic orbital city: no photographic maps or relief textures.
uniform float travel=0.;
uniform float music_pulse=0.;
uniform vec2 world_position=vec2(0.);
uniform int planet_style=0;
uniform vec4 planet_color : source_color=vec4(.6,.3,.95,1.);
uniform vec4 sky_tint : source_color=vec4(.02,.01,.04,1.);
uniform int quality_level=2;
uniform float background_exposure=.9;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
mat2 turn(float a){return mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));}
float stroke(float d,float width,float aa){return 1.-smoothstep(width,width+aa,abs(d));}
void fragment(){
 vec2 aspect=vec2(SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,1.);
 vec2 p=(UV-.5)*aspect;
 vec3 violet=vec3(.43,.17,.72),pink=vec3(.78,.15,.49),ice=vec3(.18,.56,.78);
 vec3 accent=violet;
 if(planet_style==1)accent=mix(pink,vec3(.86,.38,.15),.38);
 if(planet_style==2)accent=mix(ice,violet,.25);
 if(planet_style==3)accent=mix(pink,vec3(.78,.16,.18),.5);
 if(planet_style==4)accent=mix(violet,pink,.45);
 if(planet_style==5)accent=vec3(.72,.43,.24);
 if(planet_style==6)accent=mix(ice,violet,.48);
 if(planet_style==7)accent=vec3(.22,.24,.77);
 vec3 col=vec3(.006,.004,.014);
 // Quiet circuit plane; narrow high-contrast game projectiles remain foreground.
 vec2 grid=(p+world_position*.000006)*12.;
 vec2 g=abs(fract(grid)-.5);vec2 ga=max(fwidth(grid),vec2(.0001));
 float lines=(1.-smoothstep(.006,.006+ga.x,g.x))+(1.-smoothstep(.006,.006+ga.y,g.y));
 float edge=smoothstep(.18,.80,length(p));
 col+=violet*lines*.024*edge;
 vec2 center=vec2(.59,-.31);float radius=.47;
 if(planet_style==1 || planet_style==3)center=vec2(-.62,-.32);
 if(planet_style==4)radius=.55;
 if(planet_style==5){radius=.32;center=vec2(.54,-.23);}
 if(planet_style==6){radius=.39;center=vec2(-.60,-.32);}
 vec2 q=p-center-world_position*.000001;
 float d=length(q),aa=max(fwidth(d),.0005);
 float body=1.-smoothstep(radius-aa,radius+aa,d);
 if(d<radius+aa){
  vec2 s=q/radius;vec3 n=vec3(s,sqrt(max(0.,1.-dot(s,s))));
  vec2 uv=vec2(atan(n.x,n.z)/TAU+.5+travel*.0001,asin(clamp(n.y,-1.,1.))/PI+.5);
  vec2 tiles=uv*vec2(48.,26.);vec2 cell=floor(tiles);vec2 local=fract(tiles);
  float value=hash(cell+float(planet_style)*17.);
  float light=max(dot(normalize(n),normalize(vec3(-.5,-.7,.6))),0.);
  float cel=floor(light*3.)/3.;
  vec3 plate=mix(vec3(.018,.016,.042),accent*.18,cel);
  plate*=.72+floor(value*3.)*.13;
  vec2 seam=min(local,1.-local);vec2 width=max(fwidth(tiles),vec2(.002));
  float road=1.-smoothstep(.018,.018+width.x,seam.x);
  road=max(road,1.-smoothstep(.018,.018+width.y,seam.y));
  plate=mix(plate,vec3(.004,.003,.012),road*.78);
  if(quality_level>0){
   float trace=stroke(local.y-.20,.012,width.y)*step(.67,value)*step(.12,local.x)*step(local.x,.80);
   trace+=stroke(local.x-.18,.012,width.x)*step(.81,value)*step(.20,local.y)*step(local.y,.60);
   plate+=mix(accent,ice,.35)*trace*.32;
   if(quality_level>1){
    float nodes=step(.89,value)*(1.-smoothstep(.04,.04+width.x,abs(local.x-.72)))*(1.-smoothstep(.035,.035+width.y,abs(local.y-.68)));
    plate+=pink*nodes*.45;
   }
  }
  float band=stroke(n.y+.15,.028,aa*4.);plate+=accent*band*.12;
  float rim=pow(1.-n.z,4.);plate+=mix(accent,ice,.25)*rim*.28;
  col=mix(col,plate,body);
 }
 // Printed orbital rings with deliberate gaps and a very restrained halo.
 vec2 orbit=turn(-.33)*q;float od=length(vec2(orbit.x,orbit.y*2.7));
 float ring_radius=radius*(1.32+float(planet_style==5)*.12);
 float ring=stroke(od-ring_radius,.0007,max(fwidth(od),.0006));
 float angle=atan(orbit.y*2.7,orbit.x);float gaps=step(.16,fract(angle*2.9+1.));
 col+=accent*ring*gaps*.18*(1.-body*.87);
 if(quality_level>0){
  float halo=exp(-abs(d-radius)*170.)*(1.-body);
  col+=accent*halo*.12;
  float rimline=stroke(d-radius*1.055,.0007,aa)*step(.24,fract(atan(q.y,q.x)*3.+.4));
  col+=mix(pink,ice,.25)*rimline*.16;
 }
 // Sparse data beacons, no whole-screen flash or animated scanline strobing.
 vec2 beacons=(p+world_position*.000004)*vec2(34.,27.);
 vec2 bid=floor(beacons),bp=fract(beacons)-.5;
 float dot_value=exp(-dot(bp,bp)*1700.)*step(.975,hash(bid));
 col+=mix(ice,pink,hash(bid+2.))*dot_value*(.17+music_pulse*.025)*(1.-body);
 float vignette=1.-smoothstep(.45,1.22,length(p))*.32;
 COLOR=vec4(max(col*vignette*background_exposure,vec3(0.)),1.);
}
