shader_type canvas_item;
render_mode unshaded;
uniform float travel=0.;
uniform vec2 world_position=vec2(0.);
uniform int planet_style=0;
uniform vec4 planet_color : source_color=vec4(.56,.58,.63,1.);
uniform vec4 sky_tint : source_color=vec4(.04,.05,.09,1.);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.58+noise(p*2.03+11.)*.28+noise(p*4.09+21.)*.14;}
mat2 turn(float a){return mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));}
vec3 surface(vec3 n){
 vec2 q=vec2(atan(n.x,n.z),asin(clamp(n.y,-1.,1.)));
 float t=travel*.02;
 float terrain=fbm(q*5.+float(planet_style)*7.);
 vec3 c=planet_color.rgb;
 if(planet_style==0){
  c=mix(vec3(.16,.18,.22),vec3(.57,.52,.43),terrain);
  vec2 cell=q*13.; vec2 id=floor(cell); vec2 loc=fract(cell)-.5;
  float crater=length(loc+(vec2(hash(id),hash(id+9.))-.5)*.75);
  float size=.075+hash(id+21.)*.19; float present=step(.37,hash(id+3.));
  c*=1.-.24*exp(-pow((crater-size)*20.,2.))*present;
  c*=1.-.22*(1.-smoothstep(.01,size,crater))*present;
  c+=vec3(.12,.11,.09)*exp(-pow((crater-size-.03)*33.,2.))*present;
 }else if(planet_style==1){
  float cloud=fbm(q*vec2(5.,13.)+vec2(t,0.));
  c=mix(vec3(.39,.18,.06),vec3(.95,.69,.29),cloud);
  c+=vec3(.21,.09,.015)*pow(.5+.5*sin(q.y*27.+cloud*9.),3.);
 }else if(planet_style==2){
  float land=fbm(q*3.4+vec2(2.1,-1.));
  c=mix(vec3(.025,.12,.33),vec3(.12,.33,.20),smoothstep(.48,.54,land));
  c=mix(c,vec3(.54,.51,.30),smoothstep(.60,.73,land)*.7);
  c=mix(c,vec3(.68,.79,.83),smoothstep(1.12,1.38,abs(q.y)));
  c=mix(c,vec3(.88,.93,1.),smoothstep(.58,.76,fbm(q*vec2(8.,15.)+vec2(t,0.)))*.75);
 }else if(planet_style==3){
  c=mix(vec3(.32,.10,.065),vec3(.76,.35,.16),terrain);
  float scar=abs(q.y+.15+sin(q.x*2.)*.12+noise(q*4.)*.10);
  c*=.56+.44*smoothstep(.008,.06,scar);
  c=mix(c,vec3(.74,.69,.60),smoothstep(1.27,1.5,abs(q.y)));
 }else if(planet_style==4 || planet_style==5){
  float warp=fbm(q*vec2(7.,5.)+vec2(t,0.));
  float bands=.5+.5*sin(q.y*(planet_style==4?38.:46.)+warp*4.);
  c=mix(planet_style==4?vec3(.39,.22,.15):vec3(.48,.39,.20),planet_style==4?vec3(.86,.71,.50):vec3(.93,.82,.55),bands);
  c*=.84+.2*noise(q*vec2(9.,65.));
  if(planet_style==4){
   vec2 spot=(q-vec2(-.25,.24))*vec2(2.5,6.8);
   float d=length(spot); float swirl=.5+.5*sin(d*22.+atan(spot.y,spot.x)*2.);
   c=mix(c,mix(vec3(.55,.16,.10),vec3(.91,.41,.22),swirl),1.-smoothstep(.70,1.05,d));
  }
 }else if(planet_style==6){
  float ribbon=.5+.5*sin(q.y*18.+terrain*2.);
  c=mix(vec3(.17,.53,.60),vec3(.61,.89,.88),ribbon*.25+terrain*.6);
 }else{
  c=mix(vec3(.025,.08,.27),vec3(.17,.38,.78),.5+.5*sin(q.y*27.+terrain*5.));
  float spot=length((q-vec2(.15,-.18))*vec2(3.,8.));
  c=mix(c,vec3(.018,.036,.13),1.-smoothstep(.6,1.,spot));
  c+=vec3(.11,.20,.33)*pow(fbm(q*12.+vec2(t,0.)),4.);
 }
 return c;
}
void fragment(){
 vec2 aspect=vec2(SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,1.);
 vec2 p=(UV-.5)*aspect;
 float fog=fbm(p*3.+world_position*.000025);
 vec3 col=vec3(.004,.008,.022)+sky_tint.rgb*(.028+.04*fog);
 vec2 center=vec2(.69,-.41); float radius=.77;
 if(planet_style==1){center=vec2(-.72,-.38);radius=.76;}
 if(planet_style==2){center=vec2(.62,-.25);radius=.65;}
 if(planet_style==3){center=vec2(-.65,.34);radius=.72;}
 if(planet_style==4){center=vec2(.74,-.34);radius=.97;}
 if(planet_style==5){center=vec2(.36,-.13);radius=.42;}
 if(planet_style==6){center=vec2(-.56,-.28);radius=.63;}
 if(planet_style==7){center=vec2(.64,.26);radius=.77;}
 vec2 planet=p-center-world_position*.0000015;
 float d=length(planet), body=1.-smoothstep(radius-.002,radius,d);
 if(planet_style==5 || planet_style==6){
  vec2 ring=turn(planet_style==5?-.36:1.05)*planet;
  float rd=length(vec2(ring.x,ring.y*(planet_style==5?3.1:4.8)))/radius;
  float mask=smoothstep(1.23,1.27,rd)*(1.-smoothstep(2.05,2.1,rd));
  float divisions=.55+.4*sin(rd*240.)*sin(rd*53.);
  float gap=1.-.85*exp(-pow((rd-1.68)*70.,2.));
  float front=step(0.,ring.y);
  col+=planet_color.rgb*mask*divisions*gap*(planet_style==5?.26:.10)*(1.-body*(1.-front));
 }
 if(d<radius){
  vec2 q=planet/radius;
  vec3 n=vec3(q,sqrt(max(0.,1.-dot(q,q))));
  vec3 material=surface(n);
  float light=max(.012,dot(n,normalize(vec3(-.65,-.5,.85))));
  col=mix(col,material*(.065+light*.53),body);
  col+=planet_color.rgb*pow(1.-n.z,4.)*.06*light;
 }
 col+=planet_color.rgb*exp(-abs(d-radius)*250.)*(planet_style==0?.07:.24);
 for(int layer=0;layer<3;layer++){
  float z=float(layer)+1.; vec2 cell=UV*vec2(125.,75.)/z+vec2(travel*.12/z,travel*.7/z)+world_position*.001/z;
  vec2 id=floor(cell); vec2 q=fract(cell)-.5;
  float star=pow(max(0.,1.-length(q)*16.),3.)*step(.945,hash(id+z*31.));
  col+=vec3(.40,.53,.69)*star*(.27+.14*z)*(1.-body*.92);
 }
 vec2 grid=(p+world_position*.00012)*12.;
 vec2 lines=abs(fract(grid)-.5)/max(fwidth(grid),vec2(.001));
 col+=vec3(.013,.04,.07)*(1.-min(min(lines.x,lines.y),1.))*(1.-body*.85);
 COLOR=vec4(col,1.);
}
