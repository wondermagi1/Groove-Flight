shader_type canvas_item;
render_mode unshaded;
// Planet-specific orbital surfaces on the original right-hand silhouette.
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
 vec3 accent=vec3(.18,.49,1.);
 if(planet_style==1)accent=vec3(.93,.66,.20);
 if(planet_style==2)accent=vec3(.12,.77,.57);
 if(planet_style==3)accent=vec3(1.,.20,.20);
 if(planet_style==4)accent=vec3(.97,.46,.21);
 if(planet_style==5)accent=vec3(.80,.64,.95);
 if(planet_style==6)accent=vec3(.20,.85,.88);
 if(planet_style==7)accent=vec3(.38,.29,1.);
 vec2 sky=turn(-.43+float(planet_style)*.07)*(p+vec2(.13,-.05))+world_position*.0000015;
 // One broad luminous cloud. Avoid crossing multi-frequency dark masks:
 // their valleys read as stacked shadows behind the game, rather than gas.
 float band=exp(-pow((sky.y+.04*sin(sky.x*2.4))*3.1,2.));
 float cloud=.5+.08*sin(sky.x*3.3+sky.y*.6)+.04*sin(sky.y*4.1);
 vec3 col=vec3(.026,.030,.065)+accent*.016+mix(vec3(.035,.048,.10),accent*.19,cloud+.23)*band*(.72+cloud*.40);
 if(quality_level>0){
  col+=mix(ice,accent,cloud)*band*.010;
 }
 // Analytic star discs remain crisp at720p/4K, with quiet parallax and no blink.
 vec2 stars=(p+world_position*.000002)*vec2(150.,114.);
 vec2 star_id=floor(stars),star_local=fract(stars)-.5;
 float star_seed=hash(star_id+1.7);
 float star=exp(-dot(star_local,star_local)*850.)*step(.88,star_seed);
 col+=mix(vec3(.42,.62,.93),vec3(1.,.85,.97),star_seed)*star*(.55+band*.50);
 col+=(hash(FRAGCOORD.xy)-.5)*.003; // static sublevel dither avoids dark-sky banding
 // Quiet circuit plane; narrow high-contrast game projectiles remain foreground.
 vec2 grid=(p+world_position*.000006)*12.;
 vec2 g=abs(fract(grid)-.5);vec2 ga=max(fwidth(grid),vec2(.0001));
 float lines=(1.-smoothstep(.006,.006+ga.x,g.x))+(1.-smoothstep(.006,.006+ga.y,g.y));
 float edge=smoothstep(.18,.80,length(p));
 col+=accent*lines*.016*edge;
 vec2 center=vec2(.59,-.31);float radius=.47;
 if(planet_style==1){radius=.44;center=vec2(.67,-.28);}
 if(planet_style==2){radius=.45;center=vec2(.65,-.33);}
 if(planet_style==3){radius=.49;center=vec2(.66,-.35);}
 if(planet_style==4){radius=.55;center=vec2(.72,-.40);}
 if(planet_style==5){radius=.34;center=vec2(.62,-.32);}
 if(planet_style==6){radius=.42;center=vec2(.66,-.34);}
 if(planet_style==7){radius=.51;center=vec2(.73,-.36);}
 vec2 q=p-center-world_position*.000001;
 float d=length(q),aa=max(fwidth(d),.0005);
 float body=1.-smoothstep(radius-aa,radius+aa,d);
 if(d<radius+aa){
  vec2 s=q/radius;vec3 n=vec3(s,sqrt(max(0.,1.-dot(s,s))));
  vec2 uv=vec2(atan(n.x,n.z)/TAU+.5+travel*.0001,asin(clamp(n.y,-1.,1.))/PI+.5);
  vec2 axes=vec2(48.-float(planet_style)*2.,26.+mod(float(planet_style),3.)*5.);
  vec2 tiles=uv*axes;vec2 cell=floor(tiles);vec2 local=fract(tiles);
  float value=hash(cell+float(planet_style)*17.);
  float light=max(dot(normalize(n),normalize(vec3(-.5,-.7,.6))),0.);
  vec3 plate=mix(vec3(.012,.014,.028),accent*.17,light*.80);
  plate*=.78+floor(value*3.)*.10;
  float terrain=.0;
  if(planet_style==0 || planet_style==3){
   vec2 crater_uv=uv*vec2(18.,13.);
   vec2 cell2=floor(crater_uv);
   vec2 crater=fract(crater_uv)-vec2(.24+.52*hash(cell2+3.),.24+.52*hash(cell2-5.));
   float rim=stroke(length(crater)-(.16+hash(cell2+7.)*.13),.02,.05);
   terrain=rim*.25*step(.27,hash(cell2));
   if(planet_style==3)terrain+=stroke(n.y+.19*sin(n.x*7.)+.12,.016,.05)*.38;
  }else if(planet_style==2){
   float coast=sin(n.x*8.+sin(n.y*9.)*1.2)+cos(n.y*10.+sin(n.x*11.)*.6);
   terrain=smoothstep(.05,.66,coast)*.26+stroke(coast-.34,.05,.14)*.22;
  }else{
   float drift=sin(n.x*5.+n.y*2.);
   terrain=(.5+.5*sin(n.y*(planet_style==1?29.:44.)+drift*1.9))*.28;
   if(planet_style==4 || planet_style==7){
    vec2 eye=(n.xy-vec2(-.20,.26))*vec2(3.8,8.8);
    terrain+=stroke(length(eye)-.77,.08,.23)*.53;
   }
   if(planet_style==6)terrain+=stroke(n.x*.30+n.y+.33,.015,.055)*.45;
  }
  plate+=accent*terrain*(.10+light*.18);
  vec2 seam=min(local,1.-local);vec2 width=max(fwidth(tiles),vec2(.002));
  float road=1.-smoothstep(.018,.018+width.x,seam.x);
  road=max(road,1.-smoothstep(.018,.018+width.y,seam.y));
  plate=mix(plate,vec3(.007,.009,.018),road*.60);
  if(quality_level>0){
   float trace=stroke(local.y-.20,.012,width.y)*step(.67,value)*step(.12,local.x)*step(local.x,.80);
   trace+=stroke(local.x-.18,.012,width.x)*step(.81,value)*step(.20,local.y)*step(local.y,.60);
   plate+=mix(accent,vec3(.67,.80,1.),.16)*trace*.35;
   if(quality_level>1){
    float nodes=step(.89,value)*(1.-smoothstep(.04,.04+width.x,abs(local.x-.72)))*(1.-smoothstep(.035,.035+width.y,abs(local.y-.68)));
    plate+=accent*nodes*.48;
   }
  }
  float band=stroke(n.y+.15,.028,aa*4.);plate+=accent*band*.12;
  float rim=pow(1.-n.z,4.);plate+=accent*rim*.31;
  col=mix(col,plate,body);
 }
 // Printed orbital rings with deliberate gaps and a very restrained halo.
 vec2 orbit=turn(planet_style==6?-.85:-.33)*q;float od=length(vec2(orbit.x,orbit.y*2.7));
 float ring_radius=radius*(1.32+float(planet_style==5)*.12);
 float ring=stroke(od-ring_radius,.0007,max(fwidth(od),.0006));
 float angle=atan(orbit.y*2.7,orbit.x);float gaps=step(.16,fract(angle*2.9+1.));
 col+=accent*ring*gaps*.18*(1.-body*.87);
 if(planet_style==5){
  float belts=smoothstep(radius*1.25,radius*1.32,od)*(1.-smoothstep(radius*1.89,radius*1.98,od));
  belts*=.45+.36*sin(od*172.)+.14*sin(od*431.);
  col+=mix(accent,vec3(.97,.79,.55),.43)*belts*.26*(1.-body*.91);
 }
 if(quality_level>0){
  float halo=exp(-abs(d-radius)*170.)*(1.-body);
  col+=accent*halo*.12;
  float rimline=stroke(d-radius*1.055,.0007,aa)*step(.24,fract(atan(q.y,q.x)*3.+.4));
  col+=accent*rimline*.16;
 }
 // Sparse data beacons, no whole-screen flash or animated scanline strobing.
 vec2 beacons=(p+world_position*.000004)*vec2(34.,27.);
 vec2 bid=floor(beacons),bp=fract(beacons)-.5;
 float dot_value=exp(-dot(bp,bp)*1700.)*step(.975,hash(bid));
 col+=mix(ice,pink,hash(bid+2.))*dot_value*(.17+music_pulse*.025)*(1.-body);
 float vignette=1.-smoothstep(.45,1.22,length(p))*.14;
 COLOR=vec4(max(col*vignette*background_exposure,vec3(0.)),1.);
}
